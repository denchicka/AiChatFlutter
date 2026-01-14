import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import 'app_settings.dart';

class NotifyService {
  NotifyService._();
  static final NotifyService instance = NotifyService._();

  Future<void> notifyOnAnswer({
    required AppSettings s,
    required String userText,
    required String assistantText,
  }) async {
    if (!s.notifyOnAnswer) return;

    final title = 'AIChat: получен ответ';
    final plainQ = _mdToPlain(userText);
    final plainA = _mdToPlain(assistantText);

    final tgFull = '✅ Ответ готов.\n\n'
        'Вопрос: $plainQ\n\n'
        'Ответ:\n$plainA';

    final emailSubject = title;
    final emailBody = 'Ответ готов.\n\n'
        'Вопрос:\n$plainQ\n\n'
        'Ответ:\n$plainA\n';
    // Каждый канал отдельно, ошибки не блокируют другой канал
    final errors = <String>[];

    if (s.notifyTelegramEnabled) {
      try {
        for (final part in _chunkText(tgFull, max: 3500)) {
          await sendTelegram(s: s, text: part);
        }
      } catch (e) {
        errors.add('Telegram: $e');
      }
    }

    if (s.notifyEmailEnabled) {
      try {
        await sendEmail(s: s, subject: emailSubject, body: emailBody);
        // Логируем успешную отправку для отладки
        debugPrint('NotifyService: Email успешно отправлен на ${s.emailTo}');
      } catch (e) {
        // Логируем ошибку для отладки
        debugPrint('NotifyService: Email отправка не удалась: $e');
        errors.add('Email: $e');
      }
    }

    // Если хотите пробрасывать наверх — бросайте исключение только если ВСЁ упало.
    if (errors.length ==
            ((s.notifyTelegramEnabled ? 1 : 0) +
                (s.notifyEmailEnabled ? 1 : 0)) &&
        errors.isNotEmpty) {
      throw Exception(errors.join(' | '));
    }
  }

  List<String> _chunkText(String text, {int max = 3500}) {
    final t = text.trim();
    if (t.isEmpty) return const [];
    final parts = <String>[];
    var i = 0;
    while (i < t.length) {
      final end = (i + max < t.length) ? i + max : t.length;
      parts.add(t.substring(i, end));
      i = end;
    }
    return parts;
  }

  String _humanTelegramError(String description) {
    final d = description.toLowerCase();

    if (d.contains('unauthorized') || d.contains('invalid token')) {
      return 'Неверный Bot Token. Проверьте токен от @BotFather.';
    }

    // Ключевой кейс: пользователь не писал боту
    if (d.contains("bot can't initiate conversation") ||
        d.contains('bot was blocked by the user') ||
        d.contains('forbidden')) {
      return 'Бот не может написать первым. Откройте диалог с ботом и отправьте /start, '
          'затем повторите тест. Для групп — добавьте бота в группу.';
    }

    if (d.contains('chat not found')) {
      return 'Chat ID не найден. Проверьте Chat ID. '
          'Если это личный чат — сначала напишите боту /start. '
          'Если это группа — добавьте бота в группу и используйте Chat ID группы.';
    }

    if (d.contains('too many requests')) {
      return 'Слишком много запросов. Подождите и повторите.';
    }

    return description; // fallback
  }

  Future<void> sendTelegram({
    required AppSettings s,
    required String text,
  }) async {
    if (!s.notifyTelegramEnabled) return;

    if (s.telegramBotToken.trim().isEmpty || s.telegramChatId.trim().isEmpty) {
      throw Exception('Telegram: заполните Bot Token и Chat ID');
    }

    final uri = Uri.parse(
        'https://api.telegram.org/bot${s.telegramBotToken}/sendMessage');

    http.Response resp;
    try {
      resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'chat_id': s.telegramChatId,
              'text': text,
              'disable_web_page_preview': true,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception(
          'Telegram: таймаут. Проверьте интернет/прокси/VPN и повторите.');
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) return;

    // пробуем распарсить telegram error
    String desc = resp.body;
    try {
      final j = jsonDecode(resp.body);
      if (j is Map && j['description'] != null) {
        desc = j['description'].toString();
      }
    } catch (_) {}

    final d = desc.toLowerCase();

    if (resp.statusCode == 403 ||
        d.contains('bot was blocked') ||
        d.contains('forbidden') ||
        d.contains('bot can\'t initiate') ||
        d.contains('chat not found')) {
      throw Exception(
        'Telegram: бот не может написать в этот чат.\n'
        'Откройте бота и нажмите Start (/start), затем проверьте Chat ID.',
      );
    }

    throw Exception(_humanTelegramError(desc));
  }

  Future<void> sendEmail({
    required AppSettings s,
    required String subject,
    required String body,
  }) async {
    if (!s.notifyEmailEnabled) return;

    final host = s.smtpHost.trim();
    if (host.isEmpty) {
      throw Exception('SMTP host не заполнен');
    }
    if (s.smtpUsername.trim().isEmpty) {
      throw Exception('SMTP username не заполнен');
    }
    if (s.smtpPassword.trim().isEmpty) {
      throw Exception('SMTP password не заполнен');
    }
    if (s.emailTo.trim().isEmpty) {
      throw Exception('Email получателя (Кому) не заполнен');
    }

    final port = s.smtpPort;
    if (port <= 0 || port > 65535) throw Exception('SMTP port некорректный');

    // Практика:
    // - 587: STARTTLS
    // - 465: SSL on connect
    final bool ssl = port == 465;

    final smtpServer = SmtpServer(
      host,
      port: port,
      username: s.smtpUsername.trim(),
      password: s.smtpPassword,
      ssl: ssl,
      // Если TLS включен — не разрешаем "упасть" в небезопасное соединение.
      // Если TLS выключен — разрешаем отправку даже если STARTTLS не поднялся.
      allowInsecure: !s.smtpUseTls,
    );

    final message = Message()
      ..from = Address(s.smtpUsername.trim(), 'AIChatFlutter')
      ..recipients.add(s.emailTo.trim())
      ..subject = subject
      ..text = body;

    try {
      // Добавляем таймаут для предотвращения зависания при проблемах с SMTP сервером
      await send(message, smtpServer).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
            'SMTP: таймаут подключения. Проверьте интернет/прокси/VPN, настройки SMTP и повторите.',
            const Duration(seconds: 30),
          );
        },
      );
    } on TimeoutException catch (e) {
      // Преобразуем TimeoutException в понятное сообщение об ошибке
      final message = e.message?.isNotEmpty == true
          ? e.message!
          : 'SMTP: таймаут подключения. Проверьте интернет/прокси/VPN, настройки SMTP и повторите.';
      throw Exception(message);
    } on MailerException catch (e) {
      final details = e.problems.map((p) => '${p.code}: ${p.msg}').join('; ');
      throw Exception('SMTP ошибка: $details');
    } catch (e) {
      // Обрабатываем любые другие исключения (например, SocketException, ConnectionException)
      final errorMsg = e.toString();
      if (errorMsg.contains('timeout') || errorMsg.contains('Timeout')) {
        throw Exception('SMTP: таймаут подключения. Проверьте интернет/прокси/VPN, настройки SMTP и повторите.');
      }
      if (errorMsg.contains('connection') || errorMsg.contains('Connection')) {
        throw Exception('SMTP: ошибка подключения. Проверьте настройки SMTP (host, port, TLS) и интернет-соединение.');
      }
      // Для остальных ошибок пробрасываем как есть
      throw Exception('SMTP ошибка: $errorMsg');
    }
  }

  String _mdToPlain(String input) {
    var s = input;

    s = s.replaceAllMapped(RegExp(r'```[\s\S]*?```'), (m) {
      final block = m.group(0)!;
      return block
          .replaceFirst(RegExp(r'^```[^\n]*\n'), '')
          .replaceFirst(RegExp(r'\n```$'), '');
    });

    s = s.replaceAll('`', '');

    s = s.replaceAllMapped(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), (m) {
      final text = m.group(1) ?? '';
      final url = m.group(2) ?? '';
      return url.isEmpty ? text : '$text ($url)';
    });

    s = s.replaceAllMapped(
        RegExp(r'(\*\*|__)(.*?)\1', dotAll: true), (m) => m.group(2) ?? '');
    s = s.replaceAllMapped(
        RegExp(r'(\*|_)(.*?)\1', dotAll: true), (m) => m.group(2) ?? '');

    s = s.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '');
    s = s.replaceAll(RegExp(r'^\s{0,3}>\s?', multiLine: true), '');

    s = s.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '• ');
    s = s.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '• ');

    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return s.trim();
  }
}

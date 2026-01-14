import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../settings/settings_provider.dart';
import '../../settings/notify_service.dart';
import '../../settings/update_service.dart';

enum CheckState { idle, running, ok, error }

class SettingsController extends ChangeNotifier {
  String version = '—';

  // Text controllers
  final TextEditingController tgTokenC = TextEditingController();
  final TextEditingController tgChatIdC = TextEditingController();

  final TextEditingController emailToC = TextEditingController();
  final TextEditingController smtpHostC = TextEditingController();
  final TextEditingController smtpPortC = TextEditingController();
  final TextEditingController smtpUserC = TextEditingController();
  final TextEditingController smtpPassC = TextEditingController();

  final TextEditingController ghOwnerC = TextEditingController();
  final TextEditingController ghRepoC = TextEditingController();

  bool revealTgToken = false;
  bool revealSmtpPass = false;

  CheckState tgTestState = CheckState.idle;
  String? tgTestMsg;

  CheckState emailTestState = CheckState.idle;
  String? emailTestMsg;

  CheckState updState = CheckState.idle;
  String? updMsg;

  SettingsController() {
    unawaited(loadVersion());
  }

  @override
  void dispose() {
    tgTokenC.dispose();
    tgChatIdC.dispose();

    emailToC.dispose();
    smtpHostC.dispose();
    smtpPortC.dispose();
    smtpUserC.dispose();
    smtpPassC.dispose();

    ghOwnerC.dispose();
    ghRepoC.dispose();

    super.dispose();
  }

  Future<void> loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
      notifyListeners();
    } catch (_) {
      // keep '—'
    }
  }

  void toggleRevealTgToken() {
    revealTgToken = !revealTgToken;
    notifyListeners();
  }

  void toggleRevealSmtpPass() {
    revealSmtpPass = !revealSmtpPass;
    notifyListeners();
  }

  void syncFromSettings(SettingsProvider sp) {
    final s = sp.s;

    _setIfDiff(tgTokenC, s.telegramBotToken);
    _setIfDiff(tgChatIdC, s.telegramChatId);

    _setIfDiff(emailToC, s.emailTo);
    _setIfDiff(smtpHostC, s.smtpHost);
    _setIfDiff(smtpPortC, s.smtpPort.toString());
    _setIfDiff(smtpUserC, s.smtpUsername);
    _setIfDiff(smtpPassC, s.smtpPassword);

    _setIfDiff(ghOwnerC, s.githubOwner);
    _setIfDiff(ghRepoC, s.githubRepo);
  }

  // ---- Validation ----

  bool _looksLikeEmail(String v) {
    final t = v.trim();
    if (t.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
  }

  bool _looksLikeChatId(String v) {
    final t = v.trim();
    if (t.isEmpty) return false;
    return RegExp(r'^-?\d+$').hasMatch(t);
  }

  String? tgTokenErr(SettingsProvider sp) {
    final s = sp.s;
    return s.notifyTelegramEnabled && s.telegramBotToken.trim().isEmpty
        ? 'Введите Bot Token'
        : null;
  }

  String? tgChatErr(SettingsProvider sp) {
    final s = sp.s;
    return s.notifyTelegramEnabled && !_looksLikeChatId(s.telegramChatId)
        ? 'Chat ID должен быть числом (для групп часто отрицательный)'
        : null;
  }

  bool canTestTg(SettingsProvider sp) =>
      tgTokenErr(sp) == null && tgChatErr(sp) == null;

  String? emailToErr(SettingsProvider sp) {
    final s = sp.s;
    return s.notifyEmailEnabled && !_looksLikeEmail(s.emailTo)
        ? 'Введите корректный email получателя'
        : null;
  }

  String? smtpHostErr(SettingsProvider sp) {
    final s = sp.s;
    return s.notifyEmailEnabled && s.smtpHost.trim().isEmpty
        ? 'Введите SMTP host'
        : null;
  }

  String? smtpPortErr(SettingsProvider sp) {
    final s = sp.s;
    final port = int.tryParse(s.smtpPort.toString()) ?? 0;
    return s.notifyEmailEnabled && (port <= 0 || port > 65535)
        ? 'Порт должен быть 1–65535'
        : null;
  }

  String? smtpUserErr(SettingsProvider sp) {
    final s = sp.s;
    return s.notifyEmailEnabled && s.smtpUsername.trim().isEmpty
        ? 'Введите SMTP username (обычно ваш email)'
        : null;
  }

  String? smtpPassErr(SettingsProvider sp) {
    final s = sp.s;
    return s.notifyEmailEnabled && s.smtpPassword.trim().isEmpty
        ? 'Введите пароль приложения / SMTP пароль'
        : null;
  }

  bool canTestEmail(SettingsProvider sp) {
    return emailToErr(sp) == null &&
        smtpHostErr(sp) == null &&
        smtpPortErr(sp) == null &&
        smtpUserErr(sp) == null &&
        smtpPassErr(sp) == null;
  }

  String? ghErr(SettingsProvider sp) {
    final s = sp.s;
    return s.checkUpdatesOnStartup &&
            (s.githubOwner.trim().isEmpty || s.githubRepo.trim().isEmpty)
        ? 'Для автопроверки заполните owner/repo'
        : null;
  }

  // ---- Actions ----

  Future<void> testTelegram(SettingsProvider sp) async {
    tgTestState = CheckState.running;
    tgTestMsg = 'Проверка...';
    notifyListeners();

    try {
      await NotifyService.instance.sendTelegram(
        s: sp.s,
        text: 'Тестовое уведомление из приложения.',
      );

      tgTestState = CheckState.ok;
      tgTestMsg = 'ОК: сообщение отправлено';
      notifyListeners();

      sp.emitToast('Telegram: отправлено', type: ToastKind.success, seconds: 2);
    } catch (e) {
      tgTestState = CheckState.error;
      tgTestMsg = 'Ошибка: $e';
      notifyListeners();

      sp.emitToast('Telegram ошибка: $e', type: ToastKind.error, seconds: 4);
    }
  }

  Future<void> testEmail(SettingsProvider sp) async {
    emailTestState = CheckState.running;
    emailTestMsg = 'Проверка...';
    notifyListeners();

    try {
      await NotifyService.instance.sendEmail(
        s: sp.s,
        subject: 'Test notification',
        body: 'Test email from app.',
      );

      emailTestState = CheckState.ok;
      emailTestMsg = 'ОК: письмо отправлено';
      notifyListeners();

      sp.emitToast('Email: отправлено', type: ToastKind.success, seconds: 2);
    } catch (e) {
      emailTestState = CheckState.error;
      emailTestMsg = 'Ошибка: $e';
      notifyListeners();

      sp.emitToast('Email ошибка: $e', type: ToastKind.error, seconds: 4);
    }
  }

  Future<void> checkUpdates(SettingsProvider sp) async {
    updState = CheckState.running;
    updMsg = 'Проверка...';
    notifyListeners();

    try {
      final info = await UpdateService.instance.checkGithubLatest(
        owner: sp.s.githubOwner.trim(),
        repo: sp.s.githubRepo.trim(),
        currentVersion: version,
      );

      if (!info.hasUpdate) {
        updState = CheckState.ok;
        updMsg = 'ОК: обновлений нет (у вас ${info.current})';
        notifyListeners();

        sp.emitToast(
          'Обновлений нет. Текущая: ${info.current}',
          type: ToastKind.info,
          seconds: 3,
        );
        return;
      }

      updState = CheckState.ok;
      updMsg = 'Доступно: ${info.latest} (у вас ${info.current})';
      notifyListeners();

      sp.emitToast(
        'Доступно обновление: ${info.latest}',
        type: ToastKind.info,
        seconds: 4,
      );

      final uri = Uri.tryParse(info.htmlUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      updState = CheckState.error;
      updMsg = 'Ошибка: $e';
      notifyListeners();

      sp.emitToast(
        'Ошибка проверки обновлений: $e',
        type: ToastKind.error,
        seconds: 4,
      );
    }
  }

  // ---- Helpers ----

  void _setIfDiff(TextEditingController c, String v) {
    if (c.text == v) return;
    final sel = c.selection;
    final clamped = math.max(0, math.min(sel.baseOffset, v.length));
    c.value = TextEditingValue(
      text: v,
      selection: TextSelection.collapsed(offset: clamped),
    );
  }
}

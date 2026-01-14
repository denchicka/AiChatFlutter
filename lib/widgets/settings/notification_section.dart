import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../settings/settings_provider.dart';
import 'toggle_tile.dart';
import 'divider_soft.dart';
import 'hover_text_field.dart';
import 'info_callout.dart';
import 'link_text.dart';

class NotificationSection extends StatelessWidget {
  final SettingsProvider sp;

  // Telegram
  final TextEditingController tgTokenC;
  final TextEditingController tgChatIdC;
  final bool revealTgToken;
  final VoidCallback toggleRevealTgToken;
  final String? tgTokenErr;
  final String? tgChatErr;
  final bool canTestTg;
  final VoidCallback onTestTelegram;
  final Widget tgStatusLine;

  // Email
  final TextEditingController emailToC;
  final TextEditingController smtpHostC;
  final TextEditingController smtpPortC;
  final TextEditingController smtpUserC;
  final TextEditingController smtpPassC;
  final bool revealSmtpPass;
  final VoidCallback toggleRevealSmtpPass;
  final String? emailToErr;
  final String? smtpHostErr;
  final String? smtpPortErr;
  final String? smtpUserErr;
  final String? smtpPassErr;
  final bool canTestEmail;
  final VoidCallback onTestEmail;
  final Widget emailStatusLine;

  const NotificationSection({
    super.key,
    required this.sp,
    required this.tgTokenC,
    required this.tgChatIdC,
    required this.revealTgToken,
    required this.toggleRevealTgToken,
    required this.tgTokenErr,
    required this.tgChatErr,
    required this.canTestTg,
    required this.onTestTelegram,
    required this.tgStatusLine,
    required this.emailToC,
    required this.smtpHostC,
    required this.smtpPortC,
    required this.smtpUserC,
    required this.smtpPassC,
    required this.revealSmtpPass,
    required this.toggleRevealSmtpPass,
    required this.emailToErr,
    required this.smtpHostErr,
    required this.smtpPortErr,
    required this.smtpUserErr,
    required this.smtpPassErr,
    required this.canTestEmail,
    required this.onTestEmail,
    required this.emailStatusLine,
  });

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static const _kGmailAppPasswordUrl =
      'https://myaccount.google.com/apppasswords';
  static const _kYandexAppPasswordUrl =
      'https://id.yandex.ru/security/app-passwords';

  void _showAppPasswordSheet(BuildContext context) {
    InfoSheet.show(
      context,
      title: 'Пароль приложения',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InfoCallout(
            icon: Icons.info_outline_rounded,
            title: 'Зачем он нужен',
            body: Text(
              'Если включена двухфакторная аутентификация, обычный пароль часто не подходит. '
              'Нужно создать “пароль приложения” и вставить его сюда.',
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _openUrl(_kGmailAppPasswordUrl),
                  icon: const Icon(Icons.lock_outline_rounded, size: 18),
                  label: const Text('Пароль приложения Gmail'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _openUrl(_kYandexAppPasswordUrl),
                  icon: const Icon(Icons.lock_outline_rounded, size: 18),
                  label: const Text('Пароль приложения Yandex'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTelegramHowTo(BuildContext context) {
    InfoSheet.show(
      context,
      title: 'Telegram: настройка',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoCallout(
            icon: Icons.help_outline,
            title: 'Где взять Bot Token',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Создайте бота через '),
                SizedBox(height: 6),
                LinkText(text: '@BotFather', url: 'https://t.me/BotFather'),
                SizedBox(height: 6),
                Text('Команда: /newbot → получите Bot Token.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const InfoCallout(
            icon: Icons.info_outline,
            title: 'Важно',
            body: Text(
              'Бот не может написать первым.\n'
              'Откройте созданного бота и отправьте /start.\n'
              'Для групп — добавьте бота в группу.',
            ),
          ),
          const SizedBox(height: 12),
          const InfoCallout(
            icon: Icons.list_alt_outlined,
            title: 'Шаги',
            body: Text(
              '1) @BotFather → /newbot → Bot Token\n'
              '2) Откройте бота → /start\n'
              '3) Узнайте Chat ID (личный/группа)\n'
              '4) Вставьте Token и Chat ID\n'
              '5) Нажмите «Тест Telegram»',
            ),
          ),
        ],
      ),
    );
  }

  void _showEmailHowTo(BuildContext context) {
    InfoSheet.show(
      context,
      title: 'Email (SMTP): настройка',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          InfoCallout(
            icon: Icons.list_alt_outlined,
            title: 'Шаги',
            body: Text(
              '1) Выберите пресет Gmail/Yandex (host/port/TLS подставятся)\n'
              '2) Укажите «Кому (email)»\n'
              '3) Укажите SMTP username (обычно полный email)\n'
              '4) Укажите SMTP password (часто нужен пароль приложения)\n'
              '5) Нажмите «Тест Email»',
            ),
          ),
          SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = sp.s;

    return Column(
      children: [
        // ---------- TELEGRAM ----------
        ToggleTile(
          title: 'Telegram',
          subtitle: 'Оповещения через Bot API',
          value: s.notifyTelegramEnabled,
          onChanged: (v) => sp.update(s.copyWith(notifyTelegramEnabled: v)),
          infoPressed: () => _showTelegramHowTo(context),
        ),

        AnimatedCrossFade(
          crossFadeState: s.notifyTelegramEnabled
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                const InfoCallout(
                  icon: Icons.info_outline,
                  title: 'Важно',
                  body: Text(
                    'Если бот не может написать — откройте диалог с ботом и отправьте /start. '
                    'Для групп добавьте бота в группу.',
                  ),
                ),
                const SizedBox(height: 14),
                HoverTextField(
                  label: 'Bot Token',
                  hint: '123456789:AAAbbbCCCddd...',
                  controller: tgTokenC,
                  obscure: !revealTgToken,
                  errorText: tgTokenErr,
                  suffix: IconButton(
                    tooltip: revealTgToken ? 'Скрыть' : 'Показать',
                    onPressed: toggleRevealTgToken,
                    icon: Icon(
                      revealTgToken ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                  ),
                  onChanged: (v) => sp.update(s.copyWith(telegramBotToken: v)),
                ),
                const SizedBox(height: 14),
                HoverTextField(
                  label: 'Chat ID',
                  hint: '123456789 или -1001234567890',
                  controller: tgChatIdC,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[-0-9]')),
                  ],
                  errorText: tgChatErr,
                  onChanged: (v) => sp.update(s.copyWith(telegramChatId: v)),
                ),
                const SizedBox(height: 12),
                const InfoCallout(
                  icon: Icons.info_outline,
                  title: 'Про Chat ID',
                  body: Text(
                    'Chat ID — числовой. Для групп/каналов часто начинается с -100…\n'
                    'Если бот не пишет — откройте бота и отправьте /start.',
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _openUrl('https://t.me/BotFather'),
                        icon: const Icon(Icons.smart_toy_outlined, size: 18),
                        label: const Text('BotFather'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openUrl('https://t.me/userinfobot'),
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('Chat ID'),
                      ),
                      OutlinedButton.icon(
                        onPressed: canTestTg ? onTestTelegram : null,
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('Тест Telegram'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                tgStatusLine,
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),

        const SizedBox(height: 16),
        const DividerSoft(),

        // ---------- EMAIL ----------
        const SizedBox(height: 6),
        ToggleTile(
          title: 'Email',
          subtitle: 'SMTP (Gmail/Yandex)',
          value: s.notifyEmailEnabled,
          onChanged: (v) => sp.update(s.copyWith(notifyEmailEnabled: v)),
          infoPressed: () => _showEmailHowTo(context),
        ),

        AnimatedCrossFade(
          crossFadeState: s.notifyEmailEnabled
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                const InfoCallout(
                  icon: Icons.info_outline,
                  title: 'Про SMTP порт',
                  body: Text(
                    '587 обычно STARTTLS.\n'
                    '465 обычно SSL on connect.\n'
                    'Для Gmail часто нужен пароль приложения.',
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => sp.update(
                          s.copyWith(
                            smtpHost: 'smtp.gmail.com',
                            smtpPort: 587,
                            smtpUseTls: true,
                          ),
                        ),
                        icon: const Icon(Icons.mail_outline, size: 18),
                        label: const Text('Gmail preset'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => sp.update(
                          s.copyWith(
                            smtpHost: 'smtp.yandex.ru',
                            smtpPort: 587,
                            smtpUseTls: true,
                          ),
                        ),
                        icon: const Icon(Icons.alternate_email, size: 18),
                        label: const Text('Yandex preset'),
                      ),
                      OutlinedButton.icon(
                        onPressed: canTestEmail ? onTestEmail : null,
                        icon: const Icon(Icons.email, size: 18),
                        label: const Text('Тест Email'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                HoverTextField(
                  label: 'Кому (email)',
                  hint: 'receiver@example.com',
                  controller: emailToC,
                  keyboardType: TextInputType.emailAddress,
                  errorText: emailToErr,
                  onChanged: (v) => sp.update(s.copyWith(emailTo: v)),
                ),
                const SizedBox(height: 14),
                HoverTextField(
                  label: 'SMTP host',
                  hint: 'smtp.gmail.com / smtp.yandex.ru',
                  controller: smtpHostC,
                  errorText: smtpHostErr,
                  onChanged: (v) => sp.update(s.copyWith(smtpHost: v)),
                ),
                const SizedBox(height: 14),
                HoverTextField(
                  label: 'SMTP port',
                  hint: '587',
                  controller: smtpPortC,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  errorText: smtpPortErr,
                  onChanged: (v) =>
                      sp.update(s.copyWith(smtpPort: int.tryParse(v) ?? 587)),
                ),
                const SizedBox(height: 14),
                HoverTextField(
                  label: 'SMTP username',
                  hint: 'yourname@gmail.com',
                  controller: smtpUserC,
                  keyboardType: TextInputType.emailAddress,
                  errorText: smtpUserErr,
                  onChanged: (v) => sp.update(s.copyWith(smtpUsername: v)),
                ),
                const SizedBox(height: 14),
                HoverTextField(
                  label: 'SMTP password',
                  hint: 'App password / пароль приложения',
                  controller: smtpPassC,
                  obscure: !revealSmtpPass,
                  errorText: smtpPassErr,
                  suffix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Где получить пароль приложения',
                        onPressed: () => _showAppPasswordSheet(context),
                        icon: const Icon(Icons.help_outline_rounded, size: 18),
                      ),
                      IconButton(
                        tooltip: revealSmtpPass ? 'Скрыть' : 'Показать',
                        onPressed: toggleRevealSmtpPass,
                        icon: Icon(
                          revealSmtpPass
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  onChanged: (v) => sp.update(s.copyWith(smtpPassword: v)),
                ),
                const SizedBox(height: 14),
                emailStatusLine,
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

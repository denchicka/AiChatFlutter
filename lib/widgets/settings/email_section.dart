import 'package:flutter/material.dart';

import '../../settings/settings_provider.dart';
import 'hover_text_field.dart';
import 'info_callout.dart';

class EmailSection extends StatelessWidget {
  final SettingsProvider sp;

  final TextEditingController emailToC;
  final TextEditingController smtpHostC;
  final TextEditingController smtpPortC;
  final TextEditingController smtpUserC;
  final TextEditingController smtpPassC;

  final bool revealPass;
  final VoidCallback onToggleRevealPass;

  final String? emailToErr;
  final String? smtpHostErr;
  final String? smtpPortErr;
  final String? smtpUserErr;
  final String? smtpPassErr;

  final bool canTest;
  final VoidCallback onTest;

  final Widget statusLine;

  const EmailSection({
    super.key,
    required this.sp,
    required this.emailToC,
    required this.smtpHostC,
    required this.smtpPortC,
    required this.smtpUserC,
    required this.smtpPassC,
    required this.revealPass,
    required this.onToggleRevealPass,
    required this.emailToErr,
    required this.smtpHostErr,
    required this.smtpPortErr,
    required this.smtpUserErr,
    required this.smtpPassErr,
    required this.canTest,
    required this.onTest,
    required this.statusLine,
  });

  Future<void> _showPortInfo(BuildContext context) {
    return InfoSheet.show(
      context,
      title: 'Email: SMTP порт',
      child: const InfoCallout(
        icon: Icons.info_outline,
        title: 'Важно',
        body: Text(
          'Порт 587 обычно STARTTLS (TLS=true).\n'
          'Порт 465 обычно SSL on connect.\n'
          'Для Gmail/Yandex чаще всего подходит 587 + TLS.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = sp.s;
    if (!s.notifyEmailEnabled) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          // Кнопки пресетов + тест в одном ряду/Wrap (вписано по стилю)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.start,
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
              FilledButton.tonalIcon(
                onPressed: canTest ? onTest : null,
                icon: const Icon(Icons.email, size: 18),
                label: const Text('Тест'),
              ),
            ],
          ),

          const SizedBox(height: 12),
          HoverTextField(
            label: 'Кому (email)',
            hint: 'receiver@example.com',
            controller: emailToC,
            keyboardType: TextInputType.emailAddress,
            errorText: emailToErr,
            onChanged: (v) => sp.update(s.copyWith(emailTo: v)),
          ),
          const SizedBox(height: 10),
          HoverTextField(
            label: 'SMTP host',
            hint: 'smtp.gmail.com / smtp.yandex.ru',
            controller: smtpHostC,
            errorText: smtpHostErr,
            onChanged: (v) => sp.update(s.copyWith(smtpHost: v)),
          ),
          const SizedBox(height: 10),
          HoverTextField(
            label: 'SMTP port',
            hint: '587',
            controller: smtpPortC,
            keyboardType: TextInputType.number,
            errorText: smtpPortErr,
            suffix: IconButton(
              tooltip: 'Важно про порт',
              onPressed: () => _showPortInfo(context),
              icon: const Icon(Icons.help_outline, size: 18),
            ),
            onChanged: (v) =>
                sp.update(s.copyWith(smtpPort: int.tryParse(v) ?? 587)),
          ),

          const SizedBox(height: 10),
          // TLS — оставляем tile-подобно, но визуально компактнее
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TLS (STARTTLS)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Рекомендуется для порта 587',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.86,
                  child: Switch.adaptive(
                    value: s.smtpUseTls,
                    onChanged: (v) => sp.update(s.copyWith(smtpUseTls: v)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          HoverTextField(
            label: 'SMTP username',
            hint: 'yourname@gmail.com',
            controller: smtpUserC,
            keyboardType: TextInputType.emailAddress,
            errorText: smtpUserErr,
            onChanged: (v) => sp.update(s.copyWith(smtpUsername: v)),
          ),
          const SizedBox(height: 10),
          HoverTextField(
            label: 'SMTP password',
            hint: 'App password / пароль приложения',
            controller: smtpPassC,
            obscure: !revealPass,
            errorText: smtpPassErr,
            suffix: IconButton(
              tooltip: revealPass ? 'Скрыть' : 'Показать',
              onPressed: onToggleRevealPass,
              icon: Icon(
                revealPass ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
            ),
            onChanged: (v) => sp.update(s.copyWith(smtpPassword: v)),
          ),

          const SizedBox(height: 10),
          statusLine,
        ],
      ),
    );
  }
}

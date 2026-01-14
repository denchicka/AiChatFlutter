import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../settings/settings_provider.dart';
import 'hover_text_field.dart';
import 'info_callout.dart';
import 'link_text.dart';

class TelegramSection extends StatelessWidget {
  final SettingsProvider sp;

  final TextEditingController tokenC;
  final TextEditingController chatIdC;

  final bool revealToken;
  final VoidCallback onToggleRevealToken;

  final String? tokenErr;
  final String? chatIdErr;

  final bool canTest;
  final VoidCallback onTest;

  final Widget statusLine;

  const TelegramSection({
    super.key,
    required this.sp,
    required this.tokenC,
    required this.chatIdC,
    required this.revealToken,
    required this.onToggleRevealToken,
    required this.tokenErr,
    required this.chatIdErr,
    required this.canTest,
    required this.onTest,
    required this.statusLine,
  });

  Future<void> _showChatIdInfo(BuildContext context) {
    return InfoSheet.show(
      context,
      title: 'Telegram: Chat ID',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InfoCallout(
            icon: Icons.info_outline,
            title: 'Важно',
            body: Text(
              'Chat ID — числовой. Для групп/каналов часто начинается с -100…\n'
              'Также убедитесь, что вы отправили боту /start — иначе он не сможет написать вам первым.',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Ссылка: ', style: TextStyle(fontWeight: FontWeight.w800)),
              const LinkText(
                  text: '@userinfobot', url: 'https://t.me/userinfobot'),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showTokenInfo(BuildContext context) {
    return InfoSheet.show(
      context,
      title: 'Telegram: Bot Token',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InfoCallout(
            icon: Icons.warning_amber_outlined,
            title: 'Важно',
            body: Text(
              'Создайте бота в @BotFather и получите Bot Token.\n'
              'Затем откройте созданного бота и отправьте /start.',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Ссылка: ', style: TextStyle(fontWeight: FontWeight.w800)),
              const LinkText(text: '@BotFather', url: 'https://t.me/BotFather'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = sp.s;
    if (!s.notifyTelegramEnabled) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          HoverTextField(
            label: 'Bot Token',
            hint: '123456789:AAAbbbCCCddd...',
            controller: tokenC,
            obscure: !revealToken,
            errorText: tokenErr,
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Информация',
                  onPressed: () => _showTokenInfo(context),
                  icon: const Icon(Icons.info_outline, size: 18),
                ),
                IconButton(
                  tooltip: revealToken ? 'Скрыть' : 'Показать',
                  onPressed: onToggleRevealToken,
                  icon: Icon(
                    revealToken ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                ),
              ],
            ),
            onChanged: (v) => sp.update(s.copyWith(telegramBotToken: v)),
          ),
          const SizedBox(height: 10),
          HoverTextField(
            label: 'Chat ID',
            hint: '123456789 или -1001234567890',
            controller: chatIdC,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[-0-9]')),
            ],
            errorText: chatIdErr,
            suffix: IconButton(
              tooltip: 'Важно про Chat ID',
              onPressed: () => _showChatIdInfo(context),
              icon: const Icon(Icons.help_outline, size: 18),
            ),
            onChanged: (v) => sp.update(s.copyWith(telegramChatId: v)),
          ),
          const SizedBox(height: 10),

          // Кнопки — в одном стиле и рядом, как вы хотели
          Center(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showTokenInfo(context),
                  icon: const Icon(Icons.smart_toy_outlined, size: 18),
                  label: const Text('BotFather'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showChatIdInfo(context),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Chat ID'),
                ),
                OutlinedButton.icon(
                  onPressed: canTest ? onTest : null,
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Тест'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          DefaultTextStyle.merge(
            style: TextStyle(color: scheme.onSurfaceVariant),
            child: statusLine,
          ),
        ],
      ),
    );
  }
}

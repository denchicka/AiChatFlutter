import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/chat_provider.dart';
import '../../services/database_service.dart';
import '../../settings/settings_provider.dart';
import 'hover_tile.dart';
import 'info_callout.dart';

class DataSection extends StatelessWidget {
  final SettingsProvider sp;
  final void Function(String msg, {int seconds}) snack;

  const DataSection({
    super.key,
    required this.sp,
    required this.snack,
  });

  Future<void> _openExportsFolder(BuildContext context) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final uri = Uri.file(dir.path);

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        snack('Папка: ${dir.path}', seconds: 4);
      }
    } catch (e) {
      snack('Не удалось открыть папку: $e', seconds: 4);
    }
  }

  Future<void> _resetSettings(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Сбросить настройки?'),
        content: const Text('Настройки вернутся к значениям по умолчанию.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await sp.resetToDefaults(clearSecrets: true);
    snack('Настройки сброшены');
  }

  Future<void> _clearChat(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить историю?'),
        content: const Text(
          'История чата будет удалена без возможности восстановления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    try {
      // Пытаемся использовать ChatProvider, если он доступен
      try {
        final chatProvider = context.read<ChatProvider>();
        await chatProvider.clearHistory();
      } catch (_) {
        // Если ChatProvider недоступен, используем прямой вызов
        await DatabaseService().clearHistory();
      }
      
      if (context.mounted) {
        snack('История удалена');
      }
    } catch (e) {
      if (context.mounted) {
        snack('Ошибка при удалении истории: $e', seconds: 4);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Platform.isAndroid || Platform.isIOS;

    return Column(
      children: [
        const InfoCallout(
          icon: Icons.folder_outlined,
          title: 'Экспорт',
          body: Text(
            'Истории/логи сохраняются в Documents (или app documents). '
            'На Android/iOS открытие папки зависит от файлового менеджера.',
          ),
        ),
        const SizedBox(height: 10),
        if (!isMobile) ...[
          HoverTile(
            title: 'Открыть папку экспортов',
            subtitle: 'Откроется системный проводник',
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: () => _openExportsFolder(context),
          ),
          const SizedBox(height: 8),
        ],
        HoverTile(
          title: 'Удалить историю чата',
          subtitle: 'Действие необратимо',
          destructive: true,
          trailing: const Icon(Icons.delete_outline, size: 20),
          onTap: () => _clearChat(context),
        ),
        const SizedBox(height: 8),
        HoverTile(
          title: 'Сбросить настройки по умолчанию',
          subtitle: 'Сбросит UI и каналы уведомлений',
          destructive: true,
          trailing: const Icon(Icons.restore, size: 20),
          onTap: () => _resetSettings(context),
        ),
      ],
    );
  }
}

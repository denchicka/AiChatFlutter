import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/top_toast.dart';

/// PinEntryScreen - экран ввода PIN кода для разблокировки приложения
///
/// Функциональность:
/// - Ввод 4-значного PIN кода через Pinput виджет
/// - Проверка PIN через AuthProvider
/// - Отображение ошибки при неверном PIN
/// - Кнопка "Сбросить ключ" для удаления сохранённых данных
///
/// Безопасность:
/// - PIN проверяется через хеш (SHA-256 с солью)
/// - При неверном PIN показывается сообщение об ошибке
/// - При сбросе ключа удаляются все сохранённые данные авторизации
///
/// UI:
/// - Pinput: виджет для ввода PIN (4 цифры, автозаполнение)
/// - FilledButton: кнопка "Войти" (активна только если не идёт обработка)
/// - TextButton: кнопка "Сбросить ключ" (удаляет все данные)

class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({super.key});

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  final TextEditingController pinCodeTextController = TextEditingController();

  @override
  void dispose() {
    pinCodeTextController.dispose();
    super.dispose();
  }

  Future<void> _handleUnlock() async {
    final AuthProvider authProvider = context.read<AuthProvider>();

    try {
      await authProvider.unlockWithPin(pinCode: pinCodeTextController.text);

      if (!mounted) return;
      context.go('/chat');
    } catch (_) {
      if (!mounted) return;

      final String messageToShow =
          authProvider.lastErrorMessage ?? 'Неверный PIN';

      TopToast.show(
        context,
        messageToShow,
        type: TopToastType.error,
        duration: const Duration(seconds: 2),
      );

      pinCodeTextController.clear();
    }
  }

  Future<void> _handleResetKey() async {
    final bool? isConfirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Сбросить ключ?'),
        content: const Text(
            'PIN и ключ будут удалены. Нужно будет ввести ключ заново.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (isConfirmed != true) return;

    if (!mounted) return;
    await context.read<AuthProvider>().resetAuth();
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider authProvider = context.watch<AuthProvider>();

    final PinTheme pinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Введите PIN',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('PIN нужен для входа в приложение.'),
                  ),
                  const SizedBox(height: 12),
                  Pinput(
                    controller: pinCodeTextController,
                    length: 4,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    defaultPinTheme: pinTheme,
                    onCompleted: (_) => _handleUnlock(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          authProvider.isProcessing ? null : _handleUnlock,
                      child: authProvider.isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Войти'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed:
                          authProvider.isProcessing ? null : _handleResetKey,
                      child: const Text('Сбросить ключ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

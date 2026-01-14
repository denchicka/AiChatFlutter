import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../features/auth/domain/ai_provider_detector.dart';
import '../../../providers/auth_provider.dart';

import '../../../widgets/top_toast.dart';

/// ApiKeyEntryScreen - экран ввода API ключа
///
/// Функциональность:
/// - Ввод API ключа (OpenRouter или VseGPT)
/// - Автоматическое определение провайдера по формату ключа
/// - Ручной выбор провайдера, если автоматическое определение не сработало
/// - Проверка валидности ключа через API
/// - Генерация PIN кода после успешной проверки
/// - Отображение инструкций по получению ключа для каждого провайдера
///
/// Жизненный цикл:
/// 1. Пользователь вводит API ключ
/// 2. Система определяет провайдера (или пользователь выбирает вручную)
/// 3. При нажатии "Проверить" - отправляется запрос к API для проверки ключа
/// 4. При успехе - генерируется PIN и показывается диалог с PIN
/// 5. После подтверждения PIN - переход на экран чата
///
/// UI компоненты:
/// - TextField для ввода ключа с кнопкой "Вставить"
/// - DropdownButtonFormField для ручного выбора провайдера (если не определён)
/// - _ProviderInfoCallout: информационный блок с инструкциями
/// - _ProviderChip: бейдж с названием провайдера

class ApiKeyEntryScreen extends StatefulWidget {
  const ApiKeyEntryScreen({super.key});

  @override
  State<ApiKeyEntryScreen> createState() => _ApiKeyEntryScreenState();
}

class _ApiKeyEntryScreenState extends State<ApiKeyEntryScreen> {
  final TextEditingController authorizationKeyTextController =
      TextEditingController();

  final FocusNode _apiKeyFocusNode = FocusNode();

  AiProviderType? detectedProviderType;
  AiProviderType? selectedProviderType;
  // Флаг для отслеживания, есть ли текст в поле ввода (для скрытия информационного блока)
  bool _hasKeyText = false;

  @override
  void dispose() {
    // Освобождаем связанные ресурсы (поле и фокус)
    _apiKeyFocusNode.dispose();
    authorizationKeyTextController.dispose();
    super.dispose();
  }

  void _updateProviderBadge(String value) {
    final detected = AiProviderDetector.detectProviderTypeFromApiKey(value);

    setState(() {
      // Обновляем флаг наличия текста в поле ввода
      _hasKeyText = value.trim().isNotEmpty;
      
      detectedProviderType = detected;

      // Если провайдер определился по ключу — ручной выбор больше не нужен
      if (detected != null) {
        selectedProviderType = null;
      }
    });
  }

  Future<void> _handleContinue() async {
    final authProvider = context.read<AuthProvider>();

    final effectiveProvider = detectedProviderType ?? selectedProviderType;
    if (effectiveProvider == null) {
      TopToast.show(
        context,
        'Не удалось определить провайдера. Выберите его вручную.',
        type: TopToastType.error,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    try {
      final pin = await authProvider.registerApiKeyAndGeneratePin(
        apiKeyEnteredByUser: authorizationKeyTextController.text,
        providerOverride: effectiveProvider,
      );

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('PIN создан'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Сохраните PIN. Он потребуется при следующем входе.'),
              const SizedBox(height: 12),
              SelectableText(
                pin,
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: pin));
                if (!dialogContext.mounted) return;

                TopToast.show(
                  dialogContext,
                  'PIN скопирован',
                  type: TopToastType.success,
                  duration: const Duration(seconds: 1),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Скопировать'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Продолжить'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      authProvider.completeRegistrationAndEnter();
      context.go('/chat');
    } catch (_) {
      if (!mounted) return;

      final message =
          authProvider.lastErrorMessage ?? 'Не удалось проверить ключ.';

      TopToast.show(
        context,
        message,
        type: TopToastType.error,
        duration: const Duration(seconds: 4),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

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
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Вход по API-ключу',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (detectedProviderType != null)
                        _ProviderChip(providerType: detectedProviderType!),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                      'Вставьте ключ OpenRouter или VSEGPT. Мы проверим ключ и создадим PIN.'),
                  const SizedBox(height: 12),
                  // Информационный блок о том, где взять ключи (показывается только если ключ не введен)
                  if (!_hasKeyText) ...[
                    const _WhereToGetKeyInfo(),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    focusNode:
                        _apiKeyFocusNode, // ✅ чтобы возвращать фокус после paste
                    controller: authorizationKeyTextController,
                    onChanged: _updateProviderBadge,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.visiblePassword,
                    decoration: InputDecoration(
                      labelText: 'API-ключ',
                      hintText: 'sk-or-v1-... или sk-or-vv-...',

                      // ✅ чтобы suffixIcon точно влезал, особенно если isDense/компактная тема
                      isDense: true,
                      suffixIconConstraints:
                          const BoxConstraints.tightFor(width: 44, height: 44),

                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _NoSplashSuffixIconButton(
                          tooltip: 'Вставить из буфера',
                          icon: Icons.content_paste_rounded,
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            final pasted = data?.text ?? '';
                            authorizationKeyTextController.text = pasted;
                            _updateProviderBadge(pasted);
                          },
                        ),
                      ),
                    ),
                  ),
                  if (detectedProviderType == null) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AiProviderType>(
                      initialValue: selectedProviderType,
                      decoration: const InputDecoration(
                        labelText: 'Провайдер',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: AiProviderType.openRouter,
                          child: Text('OpenRouter'),
                        ),
                        DropdownMenuItem(
                          value: AiProviderType.vseGpt,
                          child: Text('VseGPT'),
                        ),
                      ],
                      onChanged: (v) {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => selectedProviderType = v);
                      },
                    ),
                  ],
                  // Убрали нижний infobox - он больше не показывается
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          authProvider.isProcessing ? null : _handleContinue,
                      icon: authProvider.isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: authProvider.isProcessing
                          ? const Text('Проверка...')
                          : const Text('Проверить и продолжить'),
                    ),
                  ),
                  if (authProvider.lastErrorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      authProvider.lastErrorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _kOpenRouterKeysUrl = 'https://openrouter.ai/settings/keys';
const _kVseGptApiUrl = 'https://vsegpt.ru/User/API';
const _kVseGptSettingsModelsUrl = 'https://vsegpt.ru/User/SettingsModels';

/// Информационный блок о том, где взять API ключи для обоих провайдеров
/// Показывается до ввода ключа, чтобы пользователь знал, где их получить
class _WhereToGetKeyInfo extends StatelessWidget {
  const _WhereToGetKeyInfo();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final actionStyle = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Где взять API-ключ?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Информация для OpenRouter
          _ProviderSection(
            title: 'OpenRouter',
            description: 'Откройте страницу ключей: Settings → Keys',
            buttonText: 'Ключи OpenRouter',
            icon: Icons.key_rounded,
            url: _kOpenRouterKeysUrl,
            actionStyle: actionStyle,
          ),
          const SizedBox(height: 12),
          // Информация для VseGPT
          _ProviderSection(
            title: 'VseGPT',
            description: '1) Создайте API-ключ\n'
                '2) Включите «Разрешить запрашивать баланс по API»',
            buttonText: 'Ключ VseGPT',
            icon: Icons.vpn_key_rounded,
            url: _kVseGptApiUrl,
            actionStyle: actionStyle,
            secondaryButtonText: 'Настройки (баланс)',
            secondaryUrl: _kVseGptSettingsModelsUrl,
            secondaryIcon: Icons.tune_rounded,
          ),
        ],
      ),
    );
  }
}

/// Секция с информацией об одном провайдере
class _ProviderSection extends StatelessWidget {
  final String title;
  final String description;
  final String buttonText;
  final IconData icon;
  final String url;
  final ButtonStyle actionStyle;
  final String? secondaryButtonText;
  final String? secondaryUrl;
  final IconData? secondaryIcon;

  const _ProviderSection({
    required this.title,
    required this.description,
    required this.buttonText,
    required this.icon,
    required this.url,
    required this.actionStyle,
    this.secondaryButtonText,
    this.secondaryUrl,
    this.secondaryIcon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              style: actionStyle,
              onPressed: () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
              icon: Icon(icon, size: 16),
              label: Text(buttonText, style: const TextStyle(fontSize: 12)),
            ),
            if (secondaryButtonText != null && secondaryUrl != null)
              OutlinedButton.icon(
                style: actionStyle,
                onPressed: () => launchUrl(
                  Uri.parse(secondaryUrl!),
                  mode: LaunchMode.externalApplication,
                ),
                icon: Icon(secondaryIcon ?? Icons.link, size: 16),
                label: Text(secondaryButtonText!, style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ],
    );
  }
}

class _ProviderChip extends StatelessWidget {
  final AiProviderType providerType;
  const _ProviderChip({required this.providerType});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(AiProviderDetector.providerTitle(providerType)),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
  }
}

class _NoSplashSuffixIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _NoSplashSuffixIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Theme(
      data: Theme.of(context).copyWith(splashFactory: NoSplash.splashFactory),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 20,
        style: IconButton.styleFrom(
          foregroundColor: cs.onSurfaceVariant,
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          focusColor: Colors.transparent,
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(40, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

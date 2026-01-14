// SettingsProvider - провайдер состояния для настроек приложения
//
// Ответственность:
// - Управление настройками приложения (AppSettings)
// - Загрузка/сохранение настроек из/в persistent storage
// - Debounce сохранения (чтобы не спамить диск при частых изменениях)
// - Управление toast сообщениями для уведомлений
//
// Настройки:
// - Отображение метаданных в чате (токены, стоимость, модель)
// - Настройки уведомлений (Telegram, Email)
// - Другие пользовательские предпочтения
//
// Производительность:
// - Debounce сохранения: изменения сохраняются не чаще, чем раз в 350мс
// - Ленивая загрузка: настройки загружаются при первом обращении

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'app_settings.dart';
import 'settings_service.dart';

/// Типы toast уведомлений
enum ToastKind { info, success, error }

/// Провайдер состояния для настроек приложения
class SettingsProvider with ChangeNotifier {
  AppSettings _s = const AppSettings();
  AppSettings get s => _s;

  bool _loaded = false;
  bool get loaded => _loaded;

  bool get showTokensInChat => _s.showTokensInChat;
  bool get showCostInChat => _s.showCostInChat;
  bool get showModelInfoInChat => _s.showModelInfoInChat;

  Timer? _saveDebounce;

  String? toastMessage;
  ToastKind toastKind = ToastKind.info;
  int toastSeconds = 3;

  void emitToast(
    String msg, {
    ToastKind type = ToastKind.info,
    int seconds = 3,
  }) {
    toastMessage = msg;
    toastKind = type;
    toastSeconds = seconds;
    notifyListeners();
  }

  void clearToast() {
    toastMessage = null;
    notifyListeners();
  }

  Future<void> init() async {
    _s = await SettingsService.instance.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(AppSettings next) async {
    _s = next;
    notifyListeners();

    // Debounce: сохраняем не чаще, чем раз в ~350мс после последнего изменения
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        await SettingsService.instance.save(_s);
      } catch (_) {
        // намеренно тихо: UI не должен падать от ошибки сохранения
      }
    });
  }

  Future<void> resetToDefaults({bool clearSecrets = false}) async {
    _s = const AppSettings();
    notifyListeners();

    await SettingsService.instance.save(_s);

    if (clearSecrets) {
      await SettingsService.instance.clearSecrets();
    }

    _s = await SettingsService.instance.load();
    notifyListeners();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Провайдер для управления состоянием onboarding (обучения пользователя)
/// 
/// Отслеживает:
/// - Прошел ли пользователь приветственный экран
/// - Прошел ли обучение на каждом экране
/// - Текущий шаг обучения на активном экране
class OnboardingProvider extends ChangeNotifier {
  static const String _kWelcomeCompleted = 'onboarding_welcome_completed';
  static const String _kHomeCompleted = 'onboarding_home_completed';
  static const String _kChatCompleted = 'onboarding_chat_completed';
  static const String _kProviderCompleted = 'onboarding_provider_completed';
  static const String _kSettingsCompleted = 'onboarding_settings_completed';
  static const String _kStatsCompleted = 'onboarding_stats_completed';
  static const String _kChartCompleted = 'onboarding_chart_completed';

  bool _loaded = false; // Флаг загрузки состояния
  bool _welcomeCompleted = false;
  bool _homeCompleted = false;
  bool _chatCompleted = false;
  bool _providerCompleted = false;
  bool _settingsCompleted = false;
  bool _statsCompleted = false;
  bool _chartCompleted = false;

  bool get loaded => _loaded;
  bool get welcomeCompleted => _welcomeCompleted;
  bool get homeCompleted => _homeCompleted;
  bool get chatCompleted => _chatCompleted;
  bool get providerCompleted => _providerCompleted;
  bool get settingsCompleted => _settingsCompleted;
  bool get statsCompleted => _statsCompleted;
  bool get chartCompleted => _chartCompleted;

  /// Загружает состояние onboarding из SharedPreferences
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    
    _welcomeCompleted = prefs.getBool(_kWelcomeCompleted) ?? false;
    _homeCompleted = prefs.getBool(_kHomeCompleted) ?? false;
    _chatCompleted = prefs.getBool(_kChatCompleted) ?? false;
    _providerCompleted = prefs.getBool(_kProviderCompleted) ?? false;
    _settingsCompleted = prefs.getBool(_kSettingsCompleted) ?? false;
    _statsCompleted = prefs.getBool(_kStatsCompleted) ?? false;
    _chartCompleted = prefs.getBool(_kChartCompleted) ?? false;
    
    _loaded = true;
    notifyListeners();
  }

  /// Отмечает приветственный экран как пройденный
  Future<void> completeWelcome() async {
    if (_welcomeCompleted) return;
    _welcomeCompleted = true;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWelcomeCompleted, true);
  }

  /// Отмечает обучение на экране как пройденное
  Future<void> completeScreen(String screenName) async {
    final prefs = await SharedPreferences.getInstance();
    
    switch (screenName) {
      case 'home':
        if (_homeCompleted) return;
        _homeCompleted = true;
        await prefs.setBool(_kHomeCompleted, true);
        break;
      case 'chat':
        if (_chatCompleted) return;
        _chatCompleted = true;
        await prefs.setBool(_kChatCompleted, true);
        break;
      case 'provider':
        if (_providerCompleted) return;
        _providerCompleted = true;
        await prefs.setBool(_kProviderCompleted, true);
        break;
      case 'settings':
        if (_settingsCompleted) return;
        _settingsCompleted = true;
        await prefs.setBool(_kSettingsCompleted, true);
        break;
      case 'stats':
        if (_statsCompleted) return;
        _statsCompleted = true;
        await prefs.setBool(_kStatsCompleted, true);
        break;
      case 'chart':
        if (_chartCompleted) return;
        _chartCompleted = true;
        await prefs.setBool(_kChartCompleted, true);
        break;
    }
    
    notifyListeners();
  }

  /// Сбрасывает все onboarding (для тестирования)
  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    
    _welcomeCompleted = false;
    _homeCompleted = false;
    _chatCompleted = false;
    _providerCompleted = false;
    _settingsCompleted = false;
    _statsCompleted = false;
    _chartCompleted = false;
    
    await prefs.remove(_kWelcomeCompleted);
    await prefs.remove(_kHomeCompleted);
    await prefs.remove(_kChatCompleted);
    await prefs.remove(_kProviderCompleted);
    await prefs.remove(_kSettingsCompleted);
    await prefs.remove(_kStatsCompleted);
    await prefs.remove(_kChartCompleted);
    
    // Состояние остается загруженным после сброса
    notifyListeners();
  }

  /// Проверяет, нужно ли показывать обучение для экрана
  /// 
  /// Возвращает false, если состояние еще не загружено (чтобы не показывать onboarding до загрузки)
  bool shouldShowOnboarding(String screenName) {
    // Не показываем onboarding, пока состояние не загружено
    if (!_loaded) return false;
    
    switch (screenName) {
      case 'home':
        return !_homeCompleted;
      case 'chat':
        return !_chatCompleted;
      case 'provider':
        return !_providerCompleted;
      case 'settings':
        return !_settingsCompleted;
      case 'stats':
        return !_statsCompleted;
      case 'chart':
        return !_chartCompleted;
      default:
        return false;
    }
  }
}

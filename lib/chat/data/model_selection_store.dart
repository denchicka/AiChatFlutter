import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/domain/ai_provider_detector.dart';

class ModelSelectionStore {
  static const _kLastModelOpenRouter = 'last_model_openrouter';
  static const _kLastModelVseGpt = 'last_model_vsegpt';

  String _key(AiProviderType t) {
    return switch (t) {
      AiProviderType.openRouter => _kLastModelOpenRouter,
      AiProviderType.vseGpt => _kLastModelVseGpt,
    };
  }

  Future<void> saveLastModel(
      AiProviderType providerType, String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(providerType), modelId);
  }

  Future<String?> loadLastModel(AiProviderType providerType) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(providerType));
  }
}

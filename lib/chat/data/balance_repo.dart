import '../../features/auth/domain/ai_provider_detector.dart';
import '../../services/database_service.dart';
import '../../api/auth_balance_client.dart';

class BalanceRepo {
  final DatabaseService db;
  final AuthBalanceClient client;

  BalanceRepo({required this.db, required this.client});

  Future<double?> readCachedBalance() async {
    final auth = await db.getAuth();
    final cached = auth?['last_balance'];
    if (cached is num) return cached.toDouble();
    return null;
  }

  Future<double?> fetchBalance({
    required AiProviderType providerType,
    required Uri baseUri,
    required String apiKey,
  }) async {
    final value = await client.getBalanceOrThrow(
      providerType: providerType,
      baseUri: baseUri,
      apiKey: apiKey,
    );

    await db.updateAuthCheck(lastBalance: value, lastCheckedAt: DateTime.now());
    return value;
  }
}

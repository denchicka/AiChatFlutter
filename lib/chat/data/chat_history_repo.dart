import '../../models/message.dart';
import '../../services/database_service.dart';

class ChatHistoryRepo {
  final DatabaseService db;
  ChatHistoryRepo(this.db);

  Future<List<ChatMessage>> loadMessages({int limit = 1000}) {
    return db.getMessages(limit: limit);
  }

  Future<void> saveMessage(ChatMessage m) => db.saveMessage(m);

  Future<void> clearHistory() => db.clearHistory();

  Future<void> setActiveAssistantVariant({
    required String turnId,
    required String activeUid,
  }) {
    return db.setActiveAssistantVariant(turnId: turnId, activeUid: activeUid);
  }

  Future<Map<String, dynamic>> getStatistics() => db.getStatistics();
}

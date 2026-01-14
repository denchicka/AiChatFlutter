/// Модель сообщения в чате
/// 
/// Представляет одно сообщение в диалоге (от пользователя или от AI).
/// Поддерживает:
/// - Уникальную идентификацию (uid) для каждого сообщения
/// - Группировку по "ходам" (turnId) - один вопрос пользователя + варианты ответов AI
/// - Отслеживание активного варианта ответа (isActiveVariant)
/// - Метаданные: модель, токены, стоимость, провайдер
/// 
/// Сериализация: toJson/fromJson для сохранения в БД
class ChatMessage {
  /// Уникальный идентификатор сообщения (генерируется при создании)
  final String uid;
  
  /// Идентификатор "хода" диалога (один turnId = один вопрос пользователя + варианты ответов AI)
  /// Позволяет группировать сообщения по логическим парам вопрос-ответ
  final String turnId;
  
  /// Флаг активного варианта ответа (для AI сообщений)
  /// Если у одного turnId несколько вариантов ответа, только один может быть активным
  final bool isActiveVariant;

  /// Текст сообщения (может содержать Markdown и LaTeX)
  final String content;
  
  /// Флаг: true = сообщение от пользователя, false = сообщение от AI
  final bool isUser;
  
  /// Время создания сообщения
  final DateTime createdAt;

  /// ID модели AI, которая сгенерировала ответ (null для сообщений пользователя)
  final String? modelId;
  
  /// Количество использованных токенов (null если неизвестно)
  final int? tokens;
  
  /// Стоимость запроса в долларах/рублях (null если бесплатно или неизвестно)
  final double? cost;

  /// Идентификатор провайдера (openrouter, vsegpt, unknown)
  final String providerId;
  
  /// Флаг: true = цена в рублях (VseGPT), false = цена в долларах (OpenRouter)
  final bool pricedAsVseGpt;

  const ChatMessage({
    required this.uid,
    required this.turnId,
    this.isActiveVariant = true,
    required this.content,
    required this.isUser,
    required this.createdAt,
    this.modelId,
    this.tokens,
    this.cost,
    this.providerId = 'unknown',
    this.pricedAsVseGpt = false,
  });

  DateTime get timestamp => createdAt;

  ChatMessage copyWith({
    String? uid,
    String? turnId,
    bool? isActiveVariant,
    String? content,
    bool? isUser,
    DateTime? createdAt,
    String? modelId,
    int? tokens,
    double? cost,
    String? providerId,
    bool? pricedAsVseGpt,
  }) {
    return ChatMessage(
      uid: uid ?? this.uid,
      turnId: turnId ?? this.turnId,
      isActiveVariant: isActiveVariant ?? this.isActiveVariant,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      createdAt: createdAt ?? this.createdAt,
      modelId: modelId ?? this.modelId,
      tokens: tokens ?? this.tokens,
      cost: cost ?? this.cost,
      providerId: providerId ?? this.providerId,
      pricedAsVseGpt: pricedAsVseGpt ?? this.pricedAsVseGpt,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'turn_id': turnId,
        'is_active_variant': isActiveVariant ? 1 : 0,
        'content': content,
        'is_user': isUser ? 1 : 0,
        'timestamp': createdAt.toIso8601String(),
        'model_id': modelId,
        'tokens': tokens,
        'cost': cost,
        'provider_id': providerId,
        'priced_as_vsegpt': pricedAsVseGpt ? 1 : 0,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> m) {
    return ChatMessage(
      uid: (m['uid'] ?? '').toString(),
      turnId: (m['turn_id'] ?? '').toString(),
      isActiveVariant: ((m['is_active_variant'] as int?) ?? 1) == 1,
      content: (m['content'] ?? '').toString(),
      isUser: ((m['is_user'] as int?) ?? 0) == 1,
      createdAt: DateTime.parse((m['timestamp'] ?? '').toString()),
      modelId: m['model_id']?.toString(),
      tokens: (m['tokens'] as int?),
      cost: (m['cost'] as num?)?.toDouble(),
      providerId: (m['provider_id'] ?? 'unknown').toString(),
      pricedAsVseGpt: ((m['priced_as_vsegpt'] as int?) ?? 0) == 1,
    );
  }
}

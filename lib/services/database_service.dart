// DatabaseService - сервис для работы с локальной SQLite базой данных
//
// Ответственность:
// - Хранение истории сообщений чата
// - Хранение зашифрованных данных авторизации (API ключи, PIN хеши)
// - Миграции схемы БД при обновлениях
//
// Архитектура:
// - Singleton паттерн (один экземпляр на всё приложение)
// - Ленивая инициализация БД (при первом обращении)
// - Поддержка desktop платформ через sqflite_common_ffi
//
// Таблицы:
// - messages: история сообщений (uid, turn_id, content, tokens, cost, provider_id и т.д.)
// - auth: данные авторизации (encrypted_api_key, pin_hash, provider, last_balance)
//
// Миграции:
// - Версия 1: создание таблиц messages и auth
// - Версия 2: добавление таблицы auth
// - Версия 3: добавление provider_id в messages
// - Версия 4: добавление priced_as_vsegpt в messages
// - Версия 5: добавление uid, turn_id, is_active_variant для поддержки вариантов ответов
// - Версия 6: текущая версия
//
// Производительность:
// - Индексы на часто используемых полях (timestamp, turn_id, uid)
// - Batch операции для массовых обновлений
// - Лимиты на выборку (например, последние 1000 сообщений)

import 'dart:io' show Platform;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' if (dart.library.html) '';
import '../models/message.dart';

/// Сервис для работы с локальной базой данных SQLite
/// 
/// Реализует паттерн Singleton для единой точки доступа к БД
class DatabaseService {
  // Единственный экземпляр класса (Singleton)
  static final DatabaseService _instance = DatabaseService._internal();
  // Экземпляр базы данных
  static Database? _database;

  // Фабричный метод для получения экземпляра
  factory DatabaseService() => _instance;

  // Приватный конструктор для реализации Singleton
  DatabaseService._internal();

  // Геттер для получения экземпляра базы данных
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Метод инициализации базы данных
  Future<Database> _initDatabase() async {
    // Инициализация FFI для desktop платформ
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'chat_cache.db');

    return await openDatabase(
      path,
      version: 6,
      onCreate: (Database db, int version) async {
        await _createMessagesTable(db);
        await _createAuthTable(db);
        await _createIndexes(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await _createAuthTable(db);
        }
        if (oldVersion < 3) {
          await db.execute("ALTER TABLE messages ADD COLUMN provider_id TEXT");
          await db.execute(
            "UPDATE messages SET provider_id = 'unknown' "
            "WHERE provider_id IS NULL OR TRIM(provider_id) = ''",
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            "ALTER TABLE messages ADD COLUMN priced_as_vsegpt INTEGER NOT NULL DEFAULT 0",
          );
          await db.execute(
            "UPDATE messages "
            "SET priced_as_vsegpt = CASE WHEN provider_id = 'vsegpt' THEN 1 ELSE 0 END",
          );
        }
        if (oldVersion < 5) {
          await db.execute("ALTER TABLE messages ADD COLUMN uid TEXT");
          await db.execute("ALTER TABLE messages ADD COLUMN turn_id TEXT");
          await db.execute(
              "ALTER TABLE messages ADD COLUMN is_active_variant INTEGER NOT NULL DEFAULT 1");

          // Заполним legacy uid и turn_id для старых записей
          await db.execute(
              "UPDATE messages SET uid = 'legacy_' || id WHERE uid IS NULL OR TRIM(uid) = ''");
          await db.execute(
              "UPDATE messages SET turn_id = uid WHERE turn_id IS NULL OR TRIM(turn_id) = ''");
        }
        if (oldVersion < 6) {
          // Удаляем дубликаты по uid (оставляем запись с максимальным id)
          await db.execute('''
            DELETE FROM messages
            WHERE uid IS NOT NULL AND TRIM(uid) <> ''
              AND id NOT IN (
                SELECT MAX(id)
                FROM messages
                WHERE uid IS NOT NULL AND TRIM(uid) <> ''
                GROUP BY uid
              )
          ''');

          // Индекс ускорит update-then-insert и выборки
          await db.execute(
              "CREATE INDEX IF NOT EXISTS idx_messages_uid ON messages(uid)");
          await db.execute(
              "CREATE INDEX IF NOT EXISTS idx_messages_turn ON messages(turn_id)");

          await db.execute('''
            CREATE UNIQUE INDEX IF NOT EXISTS ux_messages_uid
            ON messages(uid)
            WHERE uid IS NOT NULL AND TRIM(uid) <> ''
          ''');
        }
      },
    );
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      "CREATE INDEX IF NOT EXISTS idx_messages_uid ON messages(uid)",
    );
    await db.execute(
      "CREATE INDEX IF NOT EXISTS idx_messages_turn ON messages(turn_id)",
    );
  }

  Future<void> _createMessagesTable(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uid TEXT,
      turn_id TEXT,
      is_active_variant INTEGER NOT NULL DEFAULT 1,

      content TEXT NOT NULL,
      is_user INTEGER NOT NULL,
      timestamp TEXT NOT NULL,
      model_id TEXT,
      tokens INTEGER,
      cost REAL,
      provider_id TEXT NOT NULL DEFAULT 'unknown',
      priced_as_vsegpt INTEGER NOT NULL DEFAULT 0
    )
    ''');
  }

  Future<void> _createAuthTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS auth_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        provider TEXT NOT NULL,
        api_key TEXT NOT NULL,
        pin_hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_balance REAL,
        last_checked_at TEXT
      )
    ''');
  }

  // ----------------------------
  // Сообщения
  // ----------------------------

  Future<void> saveMessage(ChatMessage message) async {
    try {
      final db = await database;

      final uid = message.uid.trim();
      final data = <String, Object?>{
        'uid': uid,
        'turn_id': message.turnId.trim(),
        'is_active_variant': message.isActiveVariant ? 1 : 0,
        'content': message.content,
        'is_user': message.isUser ? 1 : 0,
        'timestamp': message.timestamp.toIso8601String(),
        'model_id': message.modelId,
        'tokens': message.tokens,
        'cost': message.cost,
        'provider_id': message.providerId,
        'priced_as_vsegpt': message.pricedAsVseGpt ? 1 : 0,
      };

      // safety: если uid пустой — лучше вставить как есть (но это уже аварийный кейс)
      if (uid.isEmpty) {
        await db.insert('messages', data);
        return;
      }

      final updated = await db.update(
        'messages',
        data,
        where: 'uid = ?',
        whereArgs: [uid],
      );

      if (updated == 0) {
        await db.insert('messages', data);
      }
    } catch (e) {
      debugPrint('Error saving message: $e');
    }
  }

  Future<List<ChatMessage>> getMessages({int limit = 50}) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'messages',
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      final items = List.generate(maps.length, (i) {
        final row = maps[i];

        final rawUid = (row['uid'] as String?)?.trim();
        final uid = (rawUid != null && rawUid.isNotEmpty)
            ? rawUid
            : 'legacy_${row['id']}';

        final rawTurn = (row['turn_id'] as String?)?.trim();
        final turnId = (rawTurn != null && rawTurn.isNotEmpty) ? rawTurn : uid;

        return ChatMessage(
          uid: uid,
          turnId: turnId,
          isActiveVariant: ((maps[i]['is_active_variant'] as int?) ?? 1) == 1,
          content: maps[i]['content'] as String,
          isUser: maps[i]['is_user'] == 1,
          createdAt: DateTime.parse(maps[i]['timestamp'] as String),
          modelId: maps[i]['model_id'] as String?,
          tokens: maps[i]['tokens'] as int?,
          cost: (maps[i]['cost'] as num?)?.toDouble(),
          providerId: (maps[i]['provider_id'] ?? 'unknown').toString(),
          pricedAsVseGpt: ((maps[i]['priced_as_vsegpt'] as int?) ?? 0) == 1,
        );
      });

      // Возвращаем в хронологическом порядке (старые -> новые) для UI
      return items.reversed.toList();
    } catch (e, stackTrace) {
      debugPrint('Error getting messages: $e');
      debugPrint('Stack trace: $stackTrace');
      // Возвращаем пустой список, чтобы UI не сломался
      return [];
    }
  }

  Future<void> clearHistory() async {
    try {
      final db = await database;
      await db.delete('messages');
    } catch (e, stackTrace) {
      debugPrint('Error clearing history: $e');
      debugPrint('Stack trace: $stackTrace');
      // Пробрасываем ошибку дальше, чтобы UI мог показать уведомление
      rethrow;
    }
  }

  Future<void> setActiveAssistantVariant({
    required String turnId,
    required String activeUid,
  }) async {
    final db = await database;

    await db.update(
      'messages',
      {'is_active_variant': 0},
      where: 'turn_id = ? AND is_user = 0',
      whereArgs: [turnId],
    );

    await db.update(
      'messages',
      {'is_active_variant': 1},
      where: 'uid = ?',
      whereArgs: [activeUid],
    );
  }

  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final db = await database;

      final totalMessagesResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM messages');
      final totalMessages = Sqflite.firstIntValue(totalMessagesResult) ?? 0;

      final totalTokensResult = await db.rawQuery(
          'SELECT SUM(tokens) as total FROM messages WHERE tokens IS NOT NULL');
      final totalTokens = Sqflite.firstIntValue(totalTokensResult) ?? 0;

      final modelStats = await db.rawQuery('''
        SELECT 
          model_id,
          COUNT(*) as message_count,
          SUM(tokens) as total_tokens
        FROM messages 
        WHERE model_id IS NOT NULL 
        GROUP BY model_id
      ''');

      final modelUsage = <String, Map<String, int>>{};
      for (final stat in modelStats) {
        final modelId = stat['model_id'] as String;
        modelUsage[modelId] = {
          'count': stat['message_count'] as int,
          'tokens': stat['total_tokens'] as int? ?? 0,
        };
      }

      return {
        'total_messages': totalMessages,
        'total_tokens': totalTokens,
        'model_usage': modelUsage,
      };
    } catch (e) {
      debugPrint('Error getting statistics: $e');
      return {
        'total_messages': 0,
        'total_tokens': 0,
        'model_usage': {},
      };
    }
  }

  // ----------------------------
  // Auth
  // ----------------------------

  /// Есть ли сохранённые auth-данные (ключ + PIN)?
  Future<bool> hasAuth() async {
    final record = await getAuth();
    return record != null;
  }

  /// Получить запись auth_state (или null)
  Future<Map<String, dynamic>?> getAuth() async {
    try {
      final db = await database;
      final rows = await db.query(
        'auth_state',
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first;
    } catch (e) {
      debugPrint('Error getting auth: $e');
      return null;
    }
  }

  /// Сохранить/обновить auth_state (upsert)
  Future<void> saveAuth({
    required String provider,
    required String apiKey,
    required String pinHash,
    double? lastBalance,
    DateTime? lastCheckedAt,
  }) async {
    try {
      final db = await database;

      final existing = await db.query(
        'auth_state',
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );

      final createdAt = existing.isNotEmpty
          ? (existing.first['created_at'] as String? ??
              DateTime.now().toIso8601String())
          : DateTime.now().toIso8601String();

      await db.insert(
        'auth_state',
        {
          'id': 1,
          'provider': provider,
          'api_key': apiKey,
          'pin_hash': pinHash,
          'created_at': createdAt,
          'last_balance': lastBalance,
          'last_checked_at': lastCheckedAt?.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error saving auth: $e');
    }
  }

  /// Обновить только баланс/дату проверки (не трогаем PIN и ключ)
  Future<void> updateAuthCheck({
    required double lastBalance,
    required DateTime lastCheckedAt,
  }) async {
    try {
      final db = await database;
      await db.update(
        'auth_state',
        {
          'last_balance': lastBalance,
          'last_checked_at': lastCheckedAt.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [1],
      );
    } catch (e) {
      debugPrint('Error updating auth check: $e');
    }
  }

  /// Удалить auth_state (сброс ключа)
  Future<void> clearAuth() async {
    try {
      final db = await database;
      await db.delete(
        'auth_state',
        where: 'id = ?',
        whereArgs: [1],
      );
    } catch (e) {
      debugPrint('Error clearing auth: $e');
    }
  }
}

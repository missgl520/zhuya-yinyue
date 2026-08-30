// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 对话本地数据源（Chat Local Data Source）
//
// 位于：data/datasources/chat_local_data_source.dart
// 职责：离线优先的"本地事实来源"——持久化对话历史 + 管理发件箱
//
// 为什么独立一张库（zhuyu_chat.db）？
//   MemoryService 已有 zhuyu_memory.db（长期记忆）。对话历史是高频、
//   按时间顺序读写的结构，与记忆库职责不同，分开更清晰，也避免
//   一张表被两类数据互相拖慢。
//
// 加密：content 字段按项目合规姿态用 LocalEncryption 做 at-rest 加密
//   （参考 MemoryService v2）。对话历史不需要全文搜索，加密零副作用。
//
// 两张表：
//   chat_history  所有对话（user / assistant），pending_sync 标记待同步
//   outbox        断网/后端不可达时待补发的用户消息，sync 成功后删除
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/message.dart';
import '../../core/security/local_encryption.dart';

/// 发件箱条目（待同步的用户消息）
class OutboxItem {
  final String clientMsgId;
  final String message; // 明文（库内加密存储，读取时已解密）
  final int attempts;
  final String? lastError;

  OutboxItem({
    required this.clientMsgId,
    required this.message,
    this.attempts = 0,
    this.lastError,
  });
}

/// 对话本地数据源（单例）
class ChatLocalDataSource {
  ChatLocalDataSource._();

  static const _dbName = 'zhuyu_chat.db';
  static const _dbVersion = 1;

  static final ChatLocalDataSource instance = ChatLocalDataSource._();

  Database? _db;
  bool _initialized = false;
  bool _initStarted = false;
  final Completer<void> _initLock = Completer<void>();

  Future<void> _ensureInit() async {
    if (_initialized) return;
    if (_initStarted) return _initLock.future;
    _initStarted = true;
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _dbName);
      _db = await openDatabase(path, version: _dbVersion, onCreate: _onCreate);
      _initialized = true;
      if (!_initLock.isCompleted) _initLock.complete();
    } catch (e) {
      if (!_initLock.isCompleted) _initLock.completeError(e);
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_history (
        id            TEXT PRIMARY KEY,
        client_msg_id TEXT NOT NULL,
        role          TEXT NOT NULL,
        content       TEXT NOT NULL,
        created_at    TEXT NOT NULL,
        pending_sync  INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chat_client ON chat_history(client_msg_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outbox (
        client_msg_id TEXT PRIMARY KEY,
        message       TEXT NOT NULL,
        created_at    TEXT NOT NULL,
        attempts      INTEGER NOT NULL DEFAULT 0,
        last_error    TEXT
      )
    ''');
  }

  Future<String> _newRowId() async => const Uuid().v4();

  // ── 写：用户消息（乐观写入，标记待同步） ──

  Future<void> appendUserMessage({
    required String clientMsgId,
    required String content,
    required DateTime ts,
  }) async {
    await _ensureInit();
    final enc = await LocalEncryption.encrypt(content);
    await _db!.insert('chat_history', {
      'id': await _newRowId(),
      'client_msg_id': clientMsgId,
      'role': 'user',
      'content': enc,
      'created_at': ts.toIso8601String(),
      'pending_sync': 1,
    });
  }

  // ── 写：AI 回复（与用户消息共享 client_msg_id） ──

  Future<void> appendAssistantMessage({
    required String clientMsgId,
    required String content,
    DateTime? ts,
  }) async {
    await _ensureInit();
    final enc = await LocalEncryption.encrypt(content);
    await _db!.insert('chat_history', {
      'id': await _newRowId(),
      'client_msg_id': clientMsgId,
      'role': 'assistant',
      'content': enc,
      'created_at': (ts ?? DateTime.now()).toIso8601String(),
      'pending_sync': 0,
    });
  }

  Future<void> markUserSynced(String clientMsgId) async {
    await _ensureInit();
    await _db!.update(
      'chat_history',
      {'pending_sync': 0},
      where: 'client_msg_id = ? AND role = ?',
      whereArgs: [clientMsgId, 'user'],
    );
  }

  // ── 读：最近的对话历史（UI 离线优先先读这个） ──

  Future<List<Message>> getRecentHistory({int limit = 200}) async {
    await _ensureInit();
    final rows = await _db!.query(
      'chat_history',
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return _rowsToMessages(rows);
  }

  // ── 读：构造某条待发消息之前的上下文（flush 时作为 history） ──

  Future<List<Message>> getHistoryBefore(String clientMsgId) async {
    await _ensureInit();
    final target = await _db!.query(
      'chat_history',
      columns: ['created_at'],
      where: 'client_msg_id = ?',
      whereArgs: [clientMsgId],
      limit: 1,
    );
    if (target.isEmpty) return const [];
    final ts = target.first['created_at'] as String;
    final rows = await _db!.query(
      'chat_history',
      where: 'created_at < ?',
      whereArgs: [ts],
      orderBy: 'created_at ASC',
    );
    return _rowsToMessages(rows);
  }

  Future<List<Message>> _rowsToMessages(List<Map<String, dynamic>> rows) async {
    final out = <Message>[];
    for (final row in rows) {
      final content = await LocalEncryption.decrypt(row['content'] as String);
      out.add(
        Message(
          id: row['id'] as String,
          role: row['role'] as String,
          content: content,
          timestamp: DateTime.parse(row['created_at'] as String),
          pendingSync: (row['pending_sync'] as int) == 1,
        ),
      );
    }
    return out;
  }

  // ── 发件箱（Outbox）操作 ──

  Future<void> enqueueOutbox({
    required String clientMsgId,
    required String message,
  }) async {
    await _ensureInit();
    final enc = await LocalEncryption.encrypt(message);
    await _db!.insert('outbox', {
      'client_msg_id': clientMsgId,
      'message': enc,
      'created_at': DateTime.now().toIso8601String(),
      'attempts': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<OutboxItem>> getPendingOutbox() async {
    await _ensureInit();
    final rows = await _db!.query('outbox', orderBy: 'created_at ASC');
    final out = <OutboxItem>[];
    for (final row in rows) {
      final msg = await LocalEncryption.decrypt(row['message'] as String);
      out.add(
        OutboxItem(
          clientMsgId: row['client_msg_id'] as String,
          message: msg,
          attempts: (row['attempts'] as int?) ?? 0,
          lastError: row['last_error'] as String?,
        ),
      );
    }
    return out;
  }

  Future<void> markOutboxSynced(String clientMsgId) async {
    await _ensureInit();
    await _db!.delete(
      'outbox',
      where: 'client_msg_id = ?',
      whereArgs: [clientMsgId],
    );
  }

  Future<void> incrementAttempt(String clientMsgId, String err) async {
    await _ensureInit();
    final row = await _db!.query(
      'outbox',
      columns: ['attempts'],
      where: 'client_msg_id = ?',
      whereArgs: [clientMsgId],
      limit: 1,
    );
    final cur = row.isEmpty ? 0 : ((row.first['attempts'] as int?) ?? 0);
    await _db!.update(
      'outbox',
      {'attempts': cur + 1, 'last_error': err},
      where: 'client_msg_id = ?',
      whereArgs: [clientMsgId],
    );
  }
}

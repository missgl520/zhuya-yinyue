// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 同步引擎（Sync Engine）
//
// 位于：core/sync/sync_engine.dart
// 职责：离线优先的"同步基础设施"——把发件箱里的待发消息补发给后端。
//
// 触发时机：
//   - 网络状态从无网 → 有网（Connectivity 监听）
//   - App 启动且当前有网
//   - 定时兜底（后端挂了但网络在，无状态变化事件时仍能补发）
//
// 幂等：重发时带 client_msg_id，后端可去重；本地每条 outbox 只发一次，
//   成功即删除，天然不重复。
//
// 重试：指数退避（1s → 2s → 4s … 上限 30s），避免压垮客户端/服务端。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/datasources/chat_local_data_source.dart';
import '../../data/services/chat_service.dart';

class SyncEngine {
  SyncEngine._();

  static final SyncEngine instance = SyncEngine._();

  final Connectivity _connectivity = Connectivity();
  final ChatService _service = ChatService();
  final ChatLocalDataSource _local = ChatLocalDataSource.instance;

  final StreamController<void> _syncCtrl = StreamController<void>.broadcast();

  /// 同步完成通知（flush 成功后触发，供 UI 刷新刚同步回来的消息）
  Stream<void> get syncStream => _syncCtrl.stream;

  bool _started = false;
  bool _syncing = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    // 联网状态变化 → 只要出现任一非 none 连接即补发
    _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) _flush();
    });

    // 启动即尝试一次（若当前有网）
    final current = await _connectivity.checkConnectivity();
    if (current.any((r) => r != ConnectivityResult.none)) _flush();

    // 定时兜底：后端挂了但网络在时，无状态变化事件也能补发
    Timer.periodic(const Duration(seconds: 30), (_) => _flush());
  }

  Future<void> _flush() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final pending = await _local.getPendingOutbox();
      for (final item in pending) {
        await _resend(item);
      }
    } finally {
      _syncing = false;
    }
  }

  /// 指数退避毫秒数：第 attempts 次重试后等待 1000·2^(attempts-1)，封顶 30s。
  /// 抽成纯函数以便单测（test/sync_engine_test.dart）。
  ///
  /// 注意：Dart 原生 int 为 64 位有符号整数，`1 << (attempts-1)` 在
  /// attempts-1 >= 64（即 attempts >= 65）时会移位溢出归零，导致 clamp 退回到
  /// 下限 1000ms 而非封顶 30000ms。故在 2^(attempts-1) 已超过上限时直接返回上限，
  /// 彻底规避溢出（1000·2^5 = 32000 已 > 30000，故 attempts >= 6 一律封顶）。
  static const int _maxBackoffMs = 30000;
  static int backoffMillis(int attempts) {
    if (attempts <= 0) return 0;
    if (attempts >= 6) return _maxBackoffMs; // 1000·2^5 = 32000 > 30000，已达上限
    // attempts ∈ [1,5] 时 1 << (attempts-1) ∈ [1,16]，无溢出风险
    return (1000 * (1 << (attempts - 1))).clamp(1000, _maxBackoffMs);
  }

  Future<void> _resend(OutboxItem item) async {
    // 指数退避：已尝试次数越多，等待越久（上限 30s）
    if (item.attempts > 0) {
      final delayMs = backoffMillis(item.attempts);
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    try {
      // 用该消息之前真实的本地历史作为上下文，保证连贯
      final history = await _local.getHistoryBefore(item.clientMsgId);
      final buf = StringBuffer();

      await _service.streamChat(
        message: item.message,
        history: history,
        clientMsgId: item.clientMsgId,
        onText: (t) => buf.write(t),
        onDone: () {
          // 补发成功：把 AI 回复落本地，标记已同步，触发 UI 刷新
          _local.appendAssistantMessage(
            clientMsgId: item.clientMsgId,
            content: buf.toString(),
          );
          _local.markUserSynced(item.clientMsgId);
          _local.markOutboxSynced(item.clientMsgId);
          _syncCtrl.add(null);
        },
        onError: (err) {
          // 仍失败：保留，增加尝试次数，等退避后下次再试
          _local.incrementAttempt(item.clientMsgId, err);
        },
      );
    } catch (e) {
      _local.incrementAttempt(item.clientMsgId, e.toString());
    }
  }
}

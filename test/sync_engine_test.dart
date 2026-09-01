// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 同步引擎发件箱单元测试（sync_engine_test.dart）
//
// 验证离线优先「发件箱」重试的退避策略（SyncEngine.backoffMillis）：
//   第 N 次重试等待 1000·2^(N-1) ms，封顶 30s。
//
// 这是 outbox 队列最核心的韧性逻辑（指数退避）。完整 E2E（断网→补发→落库）
// 依赖 sqflite + LocalEncryption(secure_storage)，需在真机/模拟器上验证，
// 这里用纯函数单测覆盖退避公式本身，无需设备或网络。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter_test/flutter_test.dart';
import 'package:zhuyapp/core/sync/sync_engine.dart';

void main() {
  group('SyncEngine 指数退避', () {
    test('未重试 (attempts=0) → 0ms，不等待', () {
      expect(SyncEngine.backoffMillis(0), 0);
    });

    test('第 1 次重试 → 1000ms', () {
      expect(SyncEngine.backoffMillis(1), 1000);
    });

    test('第 2 次重试 → 2000ms', () {
      expect(SyncEngine.backoffMillis(2), 2000);
    });

    test('第 3 次重试 → 4000ms（翻倍）', () {
      expect(SyncEngine.backoffMillis(3), 4000);
    });

    test('第 5 次重试 → 16000ms', () {
      expect(SyncEngine.backoffMillis(5), 16000);
    });

    test('封顶 30s：attempts>=6 一律 30000ms', () {
      expect(SyncEngine.backoffMillis(6), 30000);
      expect(SyncEngine.backoffMillis(10), 30000);
      // attempts=100 触发位移溢出边界：必须封顶而非退回下限 1000ms
      expect(SyncEngine.backoffMillis(100), 30000);
    });
  });
}

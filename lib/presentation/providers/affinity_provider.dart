// 好感度系统（Legacy 版）—— 从 legacy providers 迁移而来。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';

/// 好感度状态（由 AffinityNotifier 管理）
/// 新代码请用 presentation/providers/chat_provider.dart 里的 affinityProvider
final affinityProvider = StateNotifierProvider<AffinityNotifier, AffinityData>((
  ref,
) {
  return AffinityNotifier();
});

class AffinityNotifier extends StateNotifier<AffinityData> {
  AffinityNotifier() : super(const AffinityData());

  /// 从后端更新好感度数据
  void updateFromBackend(AffinityData data) => state = data;

  /// 重置好感度（清空记忆后调用）
  void reset() => state = const AffinityData();
}

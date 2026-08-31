// 情绪识别（Legacy 版，保留用于旧页面兼容）—— 从 legacy providers 迁移而来。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';

/// 当前情绪（驱动 Live2D 表情切换）
/// 新代码请用 presentation/providers/chat_provider.dart 里的 currentEmotionProvider
final currentEmotionProvider = StateProvider<EmotionResult?>((ref) => null);

/// 情绪历史（最近 50 条，用于情绪曲线展示）
final emotionHistoryProvider =
    StateNotifierProvider<EmotionHistoryNotifier, List<EmotionResult>>((ref) {
  return EmotionHistoryNotifier();
});

class EmotionHistoryNotifier extends StateNotifier<List<EmotionResult>> {
  EmotionHistoryNotifier() : super([]);

  void add(EmotionResult emotion) {
    // 只保留最近 50 条
    state = [...state, emotion].take(50).toList();
  }

  void clear() => state = [];
}

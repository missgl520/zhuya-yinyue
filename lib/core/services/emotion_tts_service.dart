// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 情感 TTS 引擎 v2（统一路由）
//
// 职责：
//   - 监听 chat_provider 的情绪状态（currentEmotion）
//   - 根据用户 TTS 模式设置（minimax / system）路由到对应服务
//   - 情绪标签自动映射到对应音色/语速
//
// 接入方式：
//   chat_provider 处理 SSE 时，事件完成（done）后调用 speak(text, emotion)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tts_service.dart';
import 'mini_max_tts_service.dart';
import '../../presentation/providers/settings_provider.dart';
import '../../presentation/providers/chat_provider.dart';

/// 情感 TTS 统一服务
/// 自动根据用户选择的 TTS 模式路由到对应引擎。
class EmotionTtsEngine {
  final Ref _ref;

  EmotionTtsEngine(this._ref);

  /// 朗读带情感的文本
  /// [text] — 要朗读的文本
  /// [emotion] — 当前情绪标签（happy/sad/shy/cute/neutral/excited）
  Future<void> speak(String text, {String emotion = 'neutral'}) async {
    // 1. 检查 TTS 开关
    if (!_ref.read(ttsEnabledProvider)) return;

    final mode = _ref.read(ttsModeProvider);

    if (mode == 'minimax') {
      // MiniMax 情感语音
      final mmService = _ref.read(miniMaxTtsServiceProvider);
      final apiKey = _ref.read(miniMaxApiKeyProvider);
      if (apiKey == null || apiKey.isEmpty) {
        // 没配置 MiniMax Key → 回退 system
        await _speakSystem(text, emotion);
        return;
      }
      mmService.configure(apiKey: apiKey);
      await mmService.speak(text, emotion: emotion);
    } else {
      // System TTS（本地 IndexTTS）
      await _speakSystem(text, emotion);
    }
  }

  Future<void> _speakSystem(String text, String emotion) async {
    final service = _ref.read(ttsServiceProvider);
    await service.speak(text, emotion: emotion, lang: 'ZH');
  }

  /// 停止朗读
  Future<void> stop() async {
    _ref.read(ttsServiceProvider).stop();
    await _ref.read(miniMaxTtsServiceProvider).stop();
  }
}

/// EmotionTtsEngine 单例 Provider
final emotionTtsEngineProvider = Provider<EmotionTtsEngine>((ref) {
  return EmotionTtsEngine(ref);
});

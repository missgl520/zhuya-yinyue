// 服务单例 Providers（Backend / Agnes / TTS / ASR / LipSync / Live2D 等）
// 从 legacy providers 迁移而来。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/backend_service.dart';
import '../../core/services/agnes_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/services/cartesia_tts_service.dart';
import '../../core/services/mini_max_tts_service.dart';
import '../../core/services/lip_sync_service.dart';
import '../../core/services/asr_service.dart';
import '../../core/services/memory_service.dart';
import '../../widgets/live2d_controller.dart';

/// 统一后端服务单例
final backendServiceProvider = Provider<BackendService>((ref) {
  return BackendService.instance;
});

/// Agnes 直连模式（已废弃，保留兼容性）
final agnesServiceProvider = Provider<AgnesService>((ref) {
  return AgnesService.instance;
});

/// 系统 TTS 服务（pyttsx3 / espeak-ng，离线方案）
final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

/// ASR 语音识别服务（speech_to_text 插件）
final asrServiceProvider = Provider<AsrService>((ref) {
  return AsrService();
});

/// SinoMem 长期记忆服务
final memoryServiceProvider = Provider<MemoryService>((ref) {
  return MemoryService();
});

/// Cartesia 情感 TTS 服务
final cartesiaTtsServiceProvider = Provider<CartesiaTTSService>((ref) {
  return CartesiaTTSService();
});

/// MiniMax 情感 TTS 服务（替代 Cartesia，密钥经 dart-define 注入）
final miniMaxTtsServiceProvider = Provider<MiniMaxTTSService>((ref) {
  return MiniMaxTTSService();
});

/// 唇形同步服务
final lipSyncServiceProvider = Provider<LipSyncService>((ref) {
  return LipSyncService();
});

/// Lip Sync 口型值流（Live2D Widget 监听此流驱动嘴型）
final lipSyncStreamProvider = StreamProvider<double>((ref) {
  final service = ref.watch(lipSyncServiceProvider);
  return service.mouthStream;
});

/// Live2D 控制器单例（管理 Live2D 模型加载、表情、动作）
final live2dControllerProvider = Provider<ZhuaLive2DController>((ref) {
  return ZhuaLive2DController.instance;
});

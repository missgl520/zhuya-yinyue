// 用户设置（API Key / 区域 / TTS 开关与模式）—— 从 legacy providers 迁移而来。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Agnes API Key（用户手动输入，存在 Hive）
final apiKeyProvider = StateProvider<String>((ref) {
  final box = Hive.box('settings');
  return box.get('agnesApiKey', defaultValue: '') as String;
});

/// Agnes 服务器区域：true = 国内版（apihub.agnes-ai.cn）
final agnesUseCNProvider = StateProvider<bool>((ref) {
  final box = Hive.box('settings');
  return box.get('agnesUseCN', defaultValue: true) as bool;
});

/// TTS 开关：true = 开启语音播报
final ttsEnabledProvider = StateProvider<bool>((ref) {
  final box = Hive.box('settings');
  return box.get('ttsEnabled', defaultValue: true) as bool;
});

/// TTS 模式：'minimax'（云端情感TTS）| 'system'（本地 IndexTTS 2.5 离线合成）
final ttsModeProvider = StateProvider<String>((ref) {
  final box = Hive.box('settings');
  return box.get('ttsMode', defaultValue: 'system') as String;
});

/// MiniMax TTS API Key（用户在设置页输入，存 Hive 'miniMaxApiKey'）。
/// 为空表示未配置，聊天朗读时 MiniMax 分支会降级到系统 TTS。
final miniMaxApiKeyProvider = StateProvider<String>((ref) {
  final box = Hive.box('settings');
  return box.get('miniMaxApiKey', defaultValue: '') as String;
});

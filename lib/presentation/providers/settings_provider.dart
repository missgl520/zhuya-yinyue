// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 用户设置 Provider（Settings Provider）
//
// 位于：presentation/providers/settings_provider.dart
// 职责：管理主题、TTS、ASR 等用户设置（持久化到 Hive）
//
// 迁移自：providers/app_providers_legacy.dart
// 旧代码不再引用 legacy，本文件是唯一入口。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/services/tts_service.dart';
import '../../core/services/mini_max_tts_service.dart';

// ════════════════════════════════════════════════════════════
// 设置状态（不可变）
// ════════════════════════════════════════════════════════════

/// 用户设置数据（不可变类）
class SettingsState {
  final bool isDark; // 主题：true = 暗色，false = 亮色
  final bool ttsEnabled; // TTS 开关
  final String ttsMode; // TTS 模式：'minimax' | 'system'
  final bool agnesUseCN; // Agnes 国内版：true = 国内（apihub.agnes-ai.cn）
  final String? agnesApiKey; // Agnes API Key（用户输入，存 Hive）
  final bool asrListening; // ASR 录音状态
  final String? asrResult; // ASR 识别结果

  const SettingsState({
    this.isDark = false,
    this.ttsEnabled = true,
    this.ttsMode = 'system',
    this.agnesUseCN = true,
    this.agnesApiKey,
    this.asrListening = false,
    this.asrResult,
  });

  SettingsState copyWith({
    bool? isDark,
    bool? ttsEnabled,
    String? ttsMode,
    bool? agnesUseCN,
    String? agnesApiKey,
    bool? asrListening,
    String? asrResult,
  }) {
    return SettingsState(
      isDark: isDark ?? this.isDark,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      ttsMode: ttsMode ?? this.ttsMode,
      agnesUseCN: agnesUseCN ?? this.agnesUseCN,
      agnesApiKey: agnesApiKey ?? this.agnesApiKey,
      asrListening: asrListening ?? this.asrListening,
      asrResult: asrResult ?? this.asrResult,
    );
  }
}

// ════════════════════════════════════════════════════════════
// Settings Notifier
// ════════════════════════════════════════════════════════════

class SettingsNotifier extends StateNotifier<SettingsState> {
  late final Box _settingsBox;

  SettingsNotifier() : super(const SettingsState()) {
    _settingsBox = Hive.box('settings');
    _loadFromHive();
  }

  void _loadFromHive() {
    state = SettingsState(
      isDark: _settingsBox.get('isDarkMode', defaultValue: false) as bool,
      ttsEnabled: _settingsBox.get('ttsEnabled', defaultValue: true) as bool,
      ttsMode: _settingsBox.get('ttsMode', defaultValue: 'system') as String,
      agnesUseCN: _settingsBox.get('agnesUseCN', defaultValue: true) as bool,
      agnesApiKey: _settingsBox.get('agnesApiKey', defaultValue: '') as String,
    );
  }

  /// 切换主题
  void toggleTheme() {
    state = state.copyWith(isDark: !state.isDark);
    _settingsBox.put('isDarkMode', state.isDark);
  }

  /// 设置 TTS 开关
  void setTtsEnabled(bool enabled) {
    state = state.copyWith(ttsEnabled: enabled);
    _settingsBox.put('ttsEnabled', enabled);
  }

  /// 设置 TTS 模式
  void setTtsMode(String mode) {
    state = state.copyWith(ttsMode: mode);
    _settingsBox.put('ttsMode', mode);
  }

  /// 设置 Agnes API Key
  void setAgnesApiKey(String key) {
    state = state.copyWith(agnesApiKey: key);
    _settingsBox.put('agnesApiKey', key);
  }

  /// 设置 Agnes 国内版开关
  void setAgnesUseCN(bool useCN) {
    state = state.copyWith(agnesUseCN: useCN);
    _settingsBox.put('agnesUseCN', useCN);
  }

  /// 设置 ASR 录音状态
  void setAsrListening(bool listening) {
    state = state.copyWith(asrListening: listening);
  }

  /// 设置 ASR 识别结果
  void setAsrResult(String? result) {
    state = state.copyWith(asrResult: result);
  }
}

// ════════════════════════════════════════════════════════════
// Provider 声明
// ════════════════════════════════════════════════════════════

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((
  ref,
) {
  return SettingsNotifier();
});

// ── 快捷访问 Provider ───────────────────────────────────

/// 主题 Provider（true = 暗色）
final themeProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).isDark;
});

/// TTS 开关
final ttsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).ttsEnabled;
});

/// TTS 模式
final ttsModeProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider).ttsMode;
});

/// Agnes 国内版
final agnesUseCNProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).agnesUseCN;
});

/// Agnes API Key
final agnesApiKeyProvider = Provider<String?>((ref) {
  return ref.watch(settingsProvider).agnesApiKey;
});

/// ASR 录音状态
final asrListeningProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).asrListening;
});

/// ASR 识别结果
final asrResultProvider = StateProvider<String?>((ref) => null);

// ════════════════════════════════════════════════════════════
// Services（只读单例，保留自 legacy）
// ════════════════════════════════════════════════════════════

final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

final miniMaxTtsServiceProvider = Provider<MiniMaxTTSService>((ref) {
  return MiniMaxTTSService();
});

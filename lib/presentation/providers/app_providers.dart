// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 统一 Provider 入口（App Providers）
//
// 位于：presentation/providers/app_providers.dart
// 职责：集中导出所有 Provider，方便其他文件统一 import
//
// 迁移记录（2026-08-31）：
//   - 移除 app_providers_legacy.dart（442行技术债已清除）
//   - 主题/TTS/ASR → settings_provider.dart
//   - 消息管理 → chat_provider.dart（ChatNotifier）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// 导出用户设置（主题、TTS、ASR）
export 'settings_provider.dart';

// 导出对话状态管理（状态机、情绪、好感度）
// 隐藏 currentEmotionProvider / affinityProvider 避免与 settings_provider 冲突
export 'chat_provider.dart'
    hide currentEmotionProvider, affinityProvider;

// 导出换装系统状态
export 'avatar_provider.dart';

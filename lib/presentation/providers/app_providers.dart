// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 统一 Provider 入口（App Providers）
//
// 位于：presentation/providers/app_providers.dart
// 职责：集中导出所有 Provider，方便其他文件统一 import
//
// 使用方式（其他文件）：
//   import 'package:zhuyapp/presentation/providers/app_providers.dart';
//   // 然后直接用 ref.watch(chatNotifierProvider) 即可
//
// 这样做的好处：
//   - 避免每个文件都要写一长串 import 路径
//   - 新增 Provider 只需要改这一个文件
//   - 避免循环依赖（legacy 和新架构通过这个文件隔离）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// 导出旧版 legacy providers（Hive、ASR、TTS、Live2D 等历史遗留）
// 路径：presentation/providers/ → lib/providers/
export '../../providers/app_providers_legacy.dart';

// 导出新版状态管理（对话状态机、情绪、好感度）
// 注意：隐藏 currentEmotionProvider 以避免与 legacy 冲突
//   legacy 有 currentEmotionProvider（旧版 EmotionResult 类型）
//   chat_provider 有 currentEmotionProvider（新版本 Emotion 类型）
//   旧页面用 legacy 版，新页面如果需要新版 emotion 用 chat_provider
export 'chat_provider.dart' hide currentEmotionProvider, affinityProvider;

export 'avatar_provider.dart';

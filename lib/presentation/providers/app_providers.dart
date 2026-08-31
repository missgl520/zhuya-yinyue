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

// ━ 全局状态 Providers（2026-08-31 已从 lib/providers/app_providers_legacy.dart 拆分迁移）━

// 后端配置导出（原 legacy 中 export；注意本文件位于 presentation/providers/，需向上两级到 lib/）
export '../../core/config.dart' show BackendConfig;
// 数据模型
export 'models.dart' show Message, AffinityData, EmotionResult, ZhuaStatus;
// 主题
export 'theme_provider.dart';
// 用户设置
export 'settings_provider.dart';
// 服务单例
export 'services_provider.dart';
// 消息列表
export 'messages_provider.dart';
// 其它 UI 状态
export 'ui_state_provider.dart';
// 情绪（Legacy 版 EmotionResult）
export 'emotion_provider.dart';
// 好感度（Legacy 版 AffinityData）
export 'affinity_provider.dart';

// 新版状态管理（对话状态机、情绪、好感度）
// 隐藏与 legacy 同名的 provider，避免冲突：
//   legacy 的 emotion_provider/affinity_provider 用 EmotionResult/AffinityData 类型
//   chat_provider 用 Emotion/Affinity 类型；旧页面走 legacy 版
export 'chat_provider.dart' hide currentEmotionProvider, affinityProvider;

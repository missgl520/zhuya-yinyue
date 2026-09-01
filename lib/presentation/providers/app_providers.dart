// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 统一 Provider 入口（App Providers）
//
// 位于：presentation/providers/app_providers.dart
// 职责：集中导出所有 Provider，方便其他文件统一 import
//
// 迁移记录（2026-08-31）：
//   - 移除旧 providers 文件引用，全面使用新架构
//   - 主题/TTS/ASR → settings_provider.dart
//   - 对话/情绪/好感度 → chat_provider.dart
//   - Service 单例 → 本文件直接定义（BackendService / AgnesService / AsrService）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/backend_service.dart';
import '../../core/services/agnes_service.dart';
import '../../core/services/asr_service.dart';
import '../../core/services/memory_service.dart';

// ── 导出用户设置（主题、TTS、ASR）──────────────────────────

export 'settings_provider.dart';

// ── 导出对话状态管理（状态机、情绪、好感度）──────────────────

export 'chat_provider.dart';

// ── 导出换装系统状态 ──────────────────────────────────────

export 'avatar_provider.dart';

// ── Service 单例 Provider ─────────────────────────────────
// （这些是全局一次性服务，不需要每个文件都重新 import）

/// 后端服务（单例）
final backendServiceProvider = Provider<BackendService>((ref) {
  return BackendService.instance;
});

/// Agnes 服务（单例，统一对话后端）
final agnesServiceProvider = Provider<AgnesService>((ref) {
  return AgnesService.instance;
});

/// ASR 服务（单例）
final asrServiceProvider = Provider<AsrService>((ref) {
  return AsrService();
});

/// Memory 服务（单例）
final memoryServiceProvider = Provider<MemoryService>((ref) {
  return MemoryService();
});

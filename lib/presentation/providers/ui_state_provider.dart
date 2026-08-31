// 其它 UI 状态（对话状态机 / 草稿 / ASR 监听与结果）—— 从 legacy providers 迁移而来。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';

/// 当前状态（UI 根据这个渲染不同状态：加载动画/输入框等）
final zhuaStatusProvider = StateProvider<ZhuaStatus>((ref) => ZhuaStatus.idle);

/// 输入框草稿（用户打字时临时保存，防止切换页面丢失）
final draftProvider = StateProvider<String>((ref) => '');

/// ASR 监听状态：true = 正在录音识别
final asrListeningProvider = StateProvider<bool>((ref) => false);

/// ASR 识别结果：语音转文字的结果
final asrResultProvider = StateProvider<String?>((ref) => null);

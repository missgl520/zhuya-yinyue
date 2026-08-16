// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ZhuaLive2DController - 竹笌 Live2D 全局控制器
//
// 单例模式：全局唯一，整个 App 共享
//
// 用法：
//   ZhuaLive2DController.instance.init()         // App 启动时
//   ZhuaLive2DController.instance.setStatus(...)  // 对话时更新状态
//   ZhuaLive2DController.instance.handleTouch()   // 单击触摸（Widget 内部调用）
//   ZhuaLive2DController.instance.playTap()       // 摇晃动画
//   ZhuaLive2DController.instance.playDoubleTap() // 双击彩蛋
//   ZhuaLive2DController.instance.getZone(...)    // 获取触摸区域
//   ZhuaLive2DController.instance.startLongPress() // 长按开始
//   ZhuaLive2DController.instance.endLongPress()  // 长按结束
//   ZhuaLive2DController.instance.dispose()        // App 销毁时
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_live2d/flutter_live2d.dart';
import '../core/services/lip_sync_service.dart';

/// 竹笌的 Live2D 动画状态
enum ZhuaLive2DStatus {
  idle,      // 待机
  thinking,  // 等回复
  speaking,  // 竹笌在说话（TTS）
  listening, // 用户在说话（ASR）
}

/// 触摸区域（v2.0 精细分区）
enum TouchZone {
  head,   // 头部区域（上方 50%，含边缘留白）
  body,   // 身体区域（下方 50%，含边缘留白）
  edge,   // 边缘区域（宽/高 < 5% 的窄边，不响应）
}

/// Live2D 全局控制器（单例）
class ZhuaLive2DController {
  static ZhuaLive2DController? _instance;
  static ZhuaLive2DController get instance =>
      _instance ??= ZhuaLive2DController._();

  ZhuaLive2DController._();

  Live2DViewController? _viewController;
  bool _modelLoaded = false;
  bool _disposed = false;

  /// 唇形同步服务（TTS 说话时驱动嘴巴开合）
  final LipSyncService _lipSync = LipSyncService();
  StreamSubscription<double>? _lipSub;

  /// 长按状态中（防止重复触发）
  bool _longPressing = false;

  /// Flutter 层的 Live2DViewController，供 ZhuaLive2DWidget 使用
  Live2DViewController get viewController {
    _viewController ??= Live2DViewController();
    return _viewController!;
  }

  static const String _modelDir = 'assets/live2d/ren/';
  static const String _modelFile = 'Ren.model3.json';

  bool get modelLoaded => _modelLoaded;
  bool get disposed => _disposed;

  /// 初始化并加载竹笌 Live2D 模型
  Future<void> init() async {
    if (_modelLoaded || _disposed) return;
    try {
      await viewController.whenAttached;
      // 等待原生 TextureView surface 完成第一次 onSurfaceChanged，
      // 否则 C++ 层 view->width/height=0 会导致 loadModel 直接返回 false。
      await Future.delayed(const Duration(milliseconds: 800));
      final ok = await viewController.loadModel(
        modelDir: _modelDir,
        modelFileName: _modelFile,
      );
      _modelLoaded = ok;
      if (ok) {
        await viewController.startMotion(group: 'Idle', priority: 1);
        await viewController.setExpression(0); // exp_01 默认表情
      }
    } catch (e) {
      debugPrint('[ZhuaLive2D] 加载失败: $e');
      _modelLoaded = false;
    }
  }

  /// 根据竹笌状态播放对应动画和表情
  Future<void> setStatus(ZhuaLive2DStatus status) async {
    if (!_modelLoaded || _disposed) return;
    // 长按状态中不打断
    if (_longPressing) return;
    try {
      switch (status) {
        case ZhuaLive2DStatus.idle:
          await resetToIdle();
        case ZhuaLive2DStatus.thinking:
          await viewController.setExpression(1); // exp_02 思考
        case ZhuaLive2DStatus.speaking:
          await viewController.setExpression(2); // exp_03 说话
          await viewController.startMotion(
            group: 'TapBody',
            index: Random().nextInt(2),
            priority: 2,
          );
        case ZhuaLive2DStatus.listening:
          await viewController.setExpression(3); // exp_04 专注
      }
    } catch (e) {
      debugPrint('[ZhuaLive2D] 动画失败: $e');
    }
  }

  /// 强制恢复到待机常态：停止唇形同步、闭嘴、回默认表情、重播 Idle 动画。
  ///
  /// 用于对话结束或状态切回 idle 时，避免人物卡在说话/思考表情或半张嘴姿态。
  Future<void> resetToIdle() async {
    if (!_modelLoaded || _disposed) return;
    if (_longPressing) return;
    try {
      stopLipSync();
      await viewController.setParameter('ParamMouthOpenY', 0.0);
      await viewController.setExpression(0); // 默认表情
      await viewController.startMotion(group: 'Idle', priority: 1);
      // 二次确认：300ms 后再把嘴闭上，防止 lipSync 末帧残留
      Future.delayed(const Duration(milliseconds: 300), () async {
        if (_disposed || _longPressing) return;
        try {
          await viewController.setParameter('ParamMouthOpenY', 0.0);
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[ZhuaLive2D] 恢复 idle 失败: $e');
    }
  }

  /// 设置口型开度（唇形同步专用）
  /// value: 0=闭嘴，1=张嘴最大
  Future<void> setMouthOpen(double value) async {
    if (!_modelLoaded || _disposed) return;
    try {
      await viewController.setParameter('ParamMouthOpenY', value.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('[ZhuaLive2D] 口型设置失败: $e');
    }
  }

  /// 开始唇形同步：竹笌 TTS 说话时，让嘴巴随正弦波自然开合
  ///
  /// 内部启动 LipSyncService 的 60fps 嘴型动画，并把嘴型值接到 setMouthOpen。
  /// [amplitude] 嘴型幅度，默认 0.5（说话时口型明显）；模型未加载则静默跳过。
  void startLipSync({double amplitude = 0.5}) {
    if (!_modelLoaded || _disposed) return;
    _lipSync.start(amplitude: amplitude);
    _lipSub?.cancel();
    _lipSub = _lipSync.mouthStream.listen((v) => setMouthOpen(v));
  }

  /// 停止唇形同步：取消监听、停止动画并闭嘴复位
  void stopLipSync() {
    _lipSub?.cancel();
    _lipSub = null;
    _lipSync.stop();
    setMouthOpen(0.0);
  }

  /// 根据情绪标签切换 Live2D 表情
  ///
  /// 情绪 → Live2D 表情索引映射：
  ///   neutral   → 0（默认）
  ///   happy     → 4（开心，f05）
  ///   sad       → 5（难过，f06）
  ///   angry     → 6（生气，f07）
  ///   surprised → 7（惊讶，f08）
  ///   anxious   → 8（焦虑，f09）
  Future<void> setEmotion(String emotion) async {
    if (!_modelLoaded || _disposed) return;
    // Ren 模型仅 5 个表情（索引 0~4 = exp_01~exp_05），映射到可用范围
    final mapping = {
      'neutral':   0,
      'happy':     1,
      'sad':       2,
      'angry':     3,
      'surprised': 4,
      'anxious':   4,
    };
    final idx = mapping[emotion] ?? 0;
    try {
      await viewController.setExpression(idx);
    } catch (e) {
      debugPrint('[ZhuaLive2D] 表情切换失败 ($emotion): $e');
    }
  }

  // ━━━ 触摸交互（v2.0 优化） ━━━

  /// 获取触摸区域（v2.0 精细分区，含边缘检测）
  ///
  /// 分区逻辑（基于 Widget 尺寸）：
  ///   边缘区域（宽/高 < 5% 的窄边）  → TouchZone.edge，不响应
  ///   上半区（y < height * 0.5）     → TouchZone.head
  ///   下半区（y >= height * 0.5）    → TouchZone.body
  TouchZone getZone(Offset localPosition, Size widgetSize) {
    // 边缘检测：防止模型边缘区域误触发
    const edgeThreshold = 0.05;
    final edgeW = widgetSize.width * edgeThreshold;
    final edgeH = widgetSize.height * edgeThreshold;

    if (localPosition.dx < edgeW ||
        localPosition.dx > widgetSize.width - edgeW ||
        localPosition.dy < edgeH ||
        localPosition.dy > widgetSize.height - edgeH) {
      return TouchZone.edge;
    }

    final threshold = widgetSize.height * 0.5;
    return localPosition.dy < threshold ? TouchZone.head : TouchZone.body;
  }

  /// 处理用户单击：按位置分区触发不同反应
  Future<void> handleTouch(Offset localPosition, Size widgetSize) async {
    if (!_modelLoaded || _disposed) return;

    final zone = getZone(localPosition, widgetSize);
    if (zone == TouchZone.edge) return; // 边缘区域不响应单击

    try {
      if (zone == TouchZone.head) {
        // 头区：随机切换表情
        final expressions = [0, 1, 2, 3, 4];
        await viewController.setExpression(
          expressions[Random().nextInt(expressions.length)],
        );
        await viewController.startMotion(group: 'TapBody', index: 0, priority: 3);
      } else {
        // 身体区：播放摇晃动画
        await playTap();
      }
    } catch (e) {
      debugPrint('[ZhuaLive2D] 触摸反应失败: $e');
    }
  }

  /// 长按开始：按区域持续触发动画
  ///
  /// 头部长按 → 持续害羞表情
  /// 身体长按 → 持续摇晃动画
  Future<void> startLongPress(TouchZone zone) async {
    if (!_modelLoaded || _disposed || _longPressing) return;
    if (zone == TouchZone.edge) return;

    _longPressing = true;

    try {
      if (zone == TouchZone.head) {
        // 记录当前表情，切换害羞
        await viewController.setExpression(4); // exp_05 害羞/惊讶
        await viewController.startMotion(group: 'TapBody', index: 1, priority: 4);
      } else {
        // 身体：持续摇晃，循环播放
        await viewController.startMotion(group: 'TapBody', index: 1, priority: 4);
      }
    } catch (e) {
      debugPrint('[ZhuaLive2D] 长按开始失败: $e');
      _longPressing = false;
    }
  }

  /// 长按结束：恢复正常状态
  Future<void> endLongPress() async {
    if (!_longPressing) return;
    _longPressing = false;

    try {
      if (_modelLoaded && !_disposed) {
        await viewController.setExpression(0); // 恢复默认表情
        await viewController.startMotion(group: 'Idle', priority: 1);
      }
    } catch (e) {
      debugPrint('[ZhuaLive2D] 长按结束恢复失败: $e');
    }
  }

  /// 双击彩蛋：害羞脸红
  /// 触发后 2 秒自动恢复默认表情（带 dispose 保护）
  Future<void> playDoubleTap() async {
    if (!_modelLoaded || _disposed) return;
    try {
      await viewController.setExpression(4); // exp_05 害羞/惊讶
      await viewController.startMotion(group: 'TapBody', index: 1, priority: 4);
      // 延迟恢复，用计数器方式防止竞态
      _scheduleRestore(2);
    } catch (e) {
      debugPrint('[ZhuaLive2D] 双击彩蛋失败: $e');
    }
  }

  int _restoreCountdown = 0;

  void _scheduleRestore(int seconds) {
    _restoreCountdown++;
    final ticket = _restoreCountdown;
    Future.delayed(Duration(seconds: seconds), () async {
      // 只执行最新的恢复请求
      if (ticket != _restoreCountdown || _disposed) return;
      if (_modelLoaded && !_disposed) {
        try {
          await viewController.setExpression(0);
        } catch (_) {}
      }
    });
  }

  /// 单击竹笌身体：随机播放 tap_body 动画
  Future<void> playTap() async {
    if (!_modelLoaded || _disposed) return;
    await viewController.startMotion(
      group: 'TapBody',
      index: Random().nextInt(2),
      priority: 3,
    );
  }

  /// 加载外部 Live2D 模型（从用户本地文件）
  ///
  /// [modelDir]  模型所在文件夹的完整路径（来自 file_picker）
  /// [modelFileName] .model3.json 文件名
  ///
  /// 流程：先卸载旧模型 → 加载新模型 → 重播 idle 动画
  Future<void> loadExternalModel(String modelDir, String modelFileName) async {
    if (_disposed) return;
    try {
      // 先卸载旧模型
      await viewController.unloadModel();
      _modelLoaded = false;

      // 加载新模型
      final ok = await viewController.loadModel(
        modelDir: modelDir,
        modelFileName: modelFileName,
      );
      _modelLoaded = ok;
      if (ok) {
        await viewController.setExpression(0);
        await viewController.startMotion(group: 'Idle', priority: 1);
      }
    } catch (e) {
      debugPrint('[ZhuaLive2D] 外部模型加载失败: $e');
      rethrow;
    }
  }

  void dispose() {
    _disposed = true;
    _longPressing = false;
    _lipSub?.cancel();
    _lipSync.dispose();
    _viewController?.dispose();
    _viewController = null;
    _modelLoaded = false;
    _instance = null;
  }
}

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
  idle, // 待机
  thinking, // 等回复
  speaking, // 竹笌在说话（TTS）
  listening, // 用户在说话（ASR）
}

/// 触摸区域（v2.0 精细分区）
enum TouchZone {
  head, // 头部区域（上方 50%，含边缘留白）
  body, // 身体区域（下方 50%，含边缘留白）
  edge, // 边缘区域（宽/高 < 5% 的窄边，不响应）
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

  /// 程序化全身灵动动画（v2.x 增强）：
  /// 不播放任何 motion —— 本模型所有 motion 均为 Loop=True（永久循环），且原生每帧
  /// draw 时 motion 会【覆盖】同名参数的 setParameter 值，播放 motion 后程序化四肢
  /// 动作完全看不到。故改为用多条不同频率/相位的正弦波分层驱动 头/躯干/肩/手臂/
  /// 手/腿/呼吸，让手关节、脚关节持续有机地摆动。
  Timer? _livelinessTimer;
  Timer? _blinkTimer;
  bool _speaking = false;
  DateTime? _animStart;
  DateTime _reactionUntil = DateTime.fromMillisecondsSinceEpoch(0);
  String _reactionType = 'none';

  /// 当前由 chat_page 同步过来的情绪（用于 resetToIdle 时不覆盖情绪表情）
  String _currentEmotion = 'neutral';

  /// Flutter 层的 Live2DViewController，供 ZhuaLive2DWidget 使用
  Live2DViewController get viewController {
    _viewController ??= Live2DViewController();
    return _viewController!;
  }

  static const String _modelDir = 'assets/live2d/ren_official/';
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
        await viewController.setExpression(0); // exp_01 默认表情
        _startLiveliness(); // 启动程序化全身灵动动画（四肢/躯干/呼吸/眨眼）
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
    _speaking = status == ZhuaLive2DStatus.speaking; // 说话时程序化手部比划更明显
    try {
      switch (status) {
        case ZhuaLive2DStatus.idle:
          await resetToIdle();
        case ZhuaLive2DStatus.thinking:
          await viewController.setExpression(1); // exp_02 思考
        case ZhuaLive2DStatus.speaking:
          await viewController.setExpression(2); // exp_03 说话
        // 不再播放 motion（会覆盖程序化四肢），手部比划由帧循环 _speaking 接管
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
      // 关键修复：保持当前情绪表情，不再强制重置为 exp_01（默认脸）。
      // 修复前每次回到 idle 都会覆盖情绪表情，导致"对话完看不到情绪"的 bug。
      await setEmotion(_currentEmotion);
      // 不再播放 Idle motion（会覆盖程序化四肢）；程序化帧循环持续接管
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

  // ━━━ 程序化全身灵动动画（v2.x 重写）━━━

  /// 启动程序化全身灵动动画：分层正弦波驱动四肢/躯干/呼吸 + 眨眼兜底。
  ///
  /// 为什么不用 motion：
  ///   - 本模型所有 motion 均 Loop=True（永久循环）。
  ///   - 原生每帧 draw 时 motion 会【覆盖】同名参数的 setParameter 值，
  ///     播放任何 motion 都会让程序化四肢动作完全不可见。
  ///   因此这里【不播放任何 motion】，纯程序化驱动，确保手关节/脚关节持续灵动。
  void _startLiveliness() {
    _stopLiveliness();
    _animStart ??= DateTime.now();
    // 1) 全身程序化动画：25fps 足够顺滑，平台通道开销可控
    _livelinessTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      _animateFrame();
    });
    // 2) 眨眼兜底：每 3.5s 闭眼 130ms 后睁开
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) async {
      if (!_modelLoaded || _disposed) return;
      try {
        await viewController.setParameter('ParamEyeLOpen', 0.0);
        await viewController.setParameter('ParamEyeROpen', 0.0);
        await Future.delayed(const Duration(milliseconds: 130));
        if (_disposed) return;
        await viewController.setParameter('ParamEyeLOpen', 1.0);
        await viewController.setParameter('ParamEyeROpen', 1.0);
      } catch (_) {}
    });
  }

  void _stopLiveliness() {
    _livelinessTimer?.cancel();
    _livelinessTimer = null;
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }

  /// 触发一次"反应"摆幅（戳人物 / 双击彩蛋等），在基础呼吸摆动上叠加额外晃动。
  void _triggerReaction(String type) {
    _reactionType = type;
    _reactionUntil = DateTime.now().add(const Duration(milliseconds: 1100));
  }

  /// 每帧程序化驱动全部骨骼参数（头/躯干/肩/手臂/手/腿/呼吸）。
  ///
  /// 设计：以各参数在模型中的「自然中心值」为基准、分层不同频率/相位
  /// 的正弦摆动 → 有机、不机械的肢体活动。手臂左右反相摆动是「灵动」的
  /// 关键；腿做重心微移；肩随手臂交替微抬；说话时手部额外比划。
  ///
  /// 摆幅均落在 Ren 模型参数有效范围内（mtn_01 校准：约 -2 ~ 5.85），
  /// 环绕各自中心值摆动，不越界导致畸形。
  ///
  /// 注意：本函数设置的参数经 cpp 层 override 机制，在 Live2DModel::Update()
  /// 内部、顶点计算之前重新应用，不会被 motion/physics 覆盖。
  /// 模型已换为官方完整版 Ren（ren_official）：ParamLegL/R 真绑定 deformer，腿会动。
  void _animateFrame() {
    if (!_modelLoaded || _disposed) return;
    final t = (_animStart == null
        ? 0.0
        : DateTime.now().difference(_animStart!).inMilliseconds / 1000.0);

    // 步态相位：0.85 Hz ≈ 正常步行（一秒走 0.85 个完整步态循环 = 1.7 步/秒）
    final gaitHz = 0.85;
    final g = 2 * pi * gaitHz * t;
    final gs = sin(g);

    // 反应强度（戳/双击彩蛋 / 长按 / 说话）
    final reacting = DateTime.now().isBefore(_reactionUntil);
    final react = reacting ? (_reactionType == 'double' ? 1.0 : 0.7) : 0.0;
    final armBoost = _speaking ? 1.15 : 1.0;
    final lp = _longPressing ? 1.12 : 1.0;

    // ━━━ 手臂：在身体前反相步行摆动（蹦跶跑大幅：amp 5.5） ━━━
    _safeSet('ParamArmL01', -5.0 + 5.5 * gs * armBoost * lp + react);
    _safeSet('ParamArmR01', -5.0 - 5.5 * gs * armBoost * lp + react);
    _safeSet('ParamArmL02', -2.0 + 4.0 * gs);
    _safeSet('ParamArmR02', -2.0 - 4.0 * gs);
    _safeSet('ParamArmL03', 2.0 + 3.5 * gs);
    _safeSet('ParamArmR03', 2.0 - 3.5 * gs);

    // ━━━ 肩：随对侧手臂交替微抬（自然步行联动） ━━━
    _safeSet('ParamLeftShoulderUp', 1.5 + 2.0 * gs + react);
    _safeSet('ParamRightShoulderUp', 1.5 - 2.0 * gs);

    // ━━━ 手：微动 + 说话时额外比划 ━━━
    _safeSet(
      'ParamHandL',
      0.5 +
          1.5 * sin(0.7 * g) +
          (_speaking ? 1.2 * sin(2 * pi * 1.4 * t) : 0.0),
    );
    _safeSet(
      'ParamHandR',
      0.3 -
          1.5 * sin(0.7 * g) +
          (_speaking ? 1.2 * sin(2 * pi * 1.4 * t + pi) : 0.0),
    );

    // ━━━ 躯干：步行重心左右转移 + 扭转 + 髋部反向扭（制造腿部摆动感） ━━━
    _safeSet('ParamBodyAngleX', 2.0 * gs * lp); // 左右重心转移
    _safeSet('ParamBodyAngleZ', -1.0 + 1.5 * gs * lp); // 躯干扭转
    _safeSet('ParamWaistAngleZ', -1.0 - 2.0 * gs * lp); // 髋部反向扭（腿跟着微微甩）
    _safeSet('ParamBodyAngleY', 1.5 + 1.2 * sin(2 * g) * lp); // 蹦跶跑：明显前倾/恢复

    // ━━━ 头：自然张望（频率比躯干低，更自然） ━━━
    _safeSet('ParamAngleX', 3.0 * sin(0.5 * g) * lp);
    _safeSet('ParamAngleY', -2.0 + 2.0 * sin(0.3 * g) * lp);
    _safeSet('ParamAngleZ', 2.0 * sin(0.4 * g) * lp);

    // ━━━ 呼吸 ━━━
    _safeSet('ParamBreath', 0.6 + 0.4 * sin(0.35 * g) * lp);

    // ━━━ 假装抬腿跑（蹦跶步态）：模型无膝/踝 deformer，ParamLegL/R 不能真抬脚。
    // 用半波整流腿（明确迈出）+ 加大身体上下颠（chat_page 36px）+ 大幅手摆 + 躯干前倾
    // → 视觉上"蹦跶跑"感（每步上抛 36px + 腿大幅迈出 + 手大幅摆 + 躯干前倾）
    final liftL = max(0.0, gs); // 0..1 左腿迈出强度
    final liftR = max(0.0, -gs); // 0..1 右腿迈出强度
    _safeSet('ParamLegL', 1.0 + 8.5 * liftL);
    _safeSet('ParamLegR', 1.0 + 8.5 * liftR);
  }

  /// 安全设置参数：未知参数或渲染未就绪时静默忽略，避免刷错误日志刷屏。
  void _safeSet(String id, double value) {
    try {
      viewController.setParameter(id, value).catchError((_) {});
    } catch (_) {}
  }

  /// 设置口型开度（唇形同步专用）
  /// value: 0=闭嘴，1=张嘴最大
  Future<void> setMouthOpen(double value) async {
    if (!_modelLoaded || _disposed) return;
    try {
      await viewController.setParameter(
        'ParamMouthOpenY',
        value.clamp(0.0, 1.0),
      );
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
    // 记录当前情绪，供 resetToIdle 恢复表情时使用（避免覆盖情绪表情 bug）
    _currentEmotion = emotion;
    // Ren 模型仅 5 个表情（索引 0~4 = exp_01~exp_05），映射到可用范围
    final mapping = {
      'neutral': 0,
      'happy': 1,
      'sad': 2,
      'angry': 3,
      'surprised': 4,
      'anxious': 4,
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
        // 头区：随机切换表情（与程序化四肢互不冲突）
        final expressions = [0, 1, 2, 3, 4];
        await viewController.setExpression(
          expressions[Random().nextInt(expressions.length)],
        );
        _triggerReaction('tap');
      } else {
        // 身体区：触发程序化摇晃反应（不再播放 motion）
        _triggerReaction('tap');
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
        // 记录当前表情，切换害羞；整体晃动幅度由 _longPressing 在帧循环放大
        await viewController.setExpression(4); // exp_05 害羞/惊讶
      }
      // 不再播放 motion；长按期间 _animateFrame 会自动加大全身摆幅
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
        // 不再播放 Idle motion；程序化帧循环自动恢复常态摆幅
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
      _triggerReaction('double'); // 程序化大幅晃动彩蛋
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

  /// 单击竹笌身体：触发程序化摇晃反应（不再播放 motion）
  Future<void> playTap() async {
    if (!_modelLoaded || _disposed) return;
    _triggerReaction('tap');
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
        _startLiveliness(); // 外部模型也走程序化灵动（未知参数会被 _safeSet 静默忽略）
      }
    } catch (e) {
      debugPrint('[ZhuaLive2D] 外部模型加载失败: $e');
      rethrow;
    }
  }

  void dispose() {
    _disposed = true;
    _longPressing = false;
    _stopLiveliness(); // 停掉程序化灵动 Timer + 眨眼 Timer
    _lipSub?.cancel();
    _lipSync.dispose();
    _viewController?.dispose();
    _viewController = null;
    _modelLoaded = false;
    _instance = null;
  }
}

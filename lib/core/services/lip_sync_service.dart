// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 唇形同步服务（Lip Sync Service）
//
// 位于：core/services/lip_sync_service.dart
// 职责：把音频信号转换为 Live2D 嘴型参数
//
// 技术原理：
//   声音的响度（振幅）驱动嘴型开合。
//   响度越大 → 嘴张得越开。
//   这叫"音量驱动唇形同步"（Volume-Driven Lip Sync）。
//
// 实现方式：
//   - 录音时实时采集音量（0.0 ~ 1.0）
//   - 用正弦波平滑处理（避免抖动）
//   - 输出 ParamMouthOpenY 值（Live2D 的嘴型参数，范围 0 ~ 1）
//
// 为什么不用口型识别（AI Lip Reading）？
//   太重了。手机端实时跑不动。用音量驱动够用且省资源。
//
// 竹笌用法：
//   角色开始 TTS 说话时调 start(amplitude: 0.5)，mouthStream 会持续吐出
//   嘴型值（正弦波模拟说话口型），监听方（ZhuaLive2DController）用
//   setMouthOpen() 驱动 Live2D；说话结束调 stop() 复位闭嘴。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:math' as math;

/// 唇形同步服务
///
/// 负责：
/// 1. 接收原始音量（0.0 ~ 1.0）
/// 2. 正弦波平滑处理
/// 3. 输出 Live2D 嘴型参数
class LipSyncService {
  LipSyncService();

  /// 控制流：停止监听时通知
  final _stopController = StreamController<void>.broadcast();

  /// 正弦波参数
  /// phase：当前相位（弧度），随时间累积
  /// mouthOpen：当前嘴型值（0.0 ~ 1.0）
  double _phase = 0;
  double _mouthOpen = 0;

  /// 正弦波参数：每秒转几圈（控制嘴型"颤动"速度）
  /// 1.5 圈/秒 ≈ 自然语速时的嘴型变化频率
  static const _frequency = 1.5;

  /// 正弦波参数：嘴型震荡幅度（0.0 ~ 1.0）
  /// 默认 0.20 = 说话时嘴型有轻微的自然颤动；可由 start(amplitude:) 调大让口型更明显
  double _amplitude = 0.20;

  /// 音量阈值：低于此值认为在"停顿"，不触发唇形
  /// 避免呼吸声、环境噪音触发无效嘴型
  static const _silenceThreshold = 0.05;

  /// 嘴型开合的最小值（静默时嘴不完全闭上，有微张感）
  static const _minMouthOpen = 0.02;

  /// 最大值（大笑时嘴全开）
  static const _maxMouthOpen = 0.85;

  /// 嘴型值输出流（供 Live2D Widget 监听）
  final StreamController<double> _mouthController =
      StreamController<double>.broadcast();
  Stream<double> get mouthStream => _mouthController.stream;

  /// 嘴型值输出流（别名，方便 legacy 兼容）
  Stream<double> get volumeStream => _mouthController.stream;

  Timer? _animationTimer;

  /// 开始唇形同步
  ///
  /// 内部启动一个 60fps 的定时器，用正弦波模拟说话时的嘴型动画。
  /// [amplitude] 嘴型震荡幅度，默认 0.20（自然颤动）；调大（如 0.5）让说话口型更明显。
  void start({double amplitude = 0.20}) {
    _amplitude = amplitude;
    _animationTimer?.cancel();

    // 60fps 动画循环
    _animationTimer = Timer.periodic(
      const Duration(milliseconds: 16), // ~60fps
      (_) => _tick(),
    );
  }

  /// 停止唇形同步
  void stop() {
    _animationTimer?.cancel();
    _animationTimer = null;
    _phase = 0;
    _mouthOpen = _minMouthOpen; // 停止时嘴复位
    _stopController.add(null);
  }

  /// 接收外部音量（通常来自 ASR 录音）
  /// [volume] 0.0 ~ 1.0
  double getLipSyncValue(double volume) {
    // 低于阈值视为静默
    if (volume < _silenceThreshold) {
      // 静默时：正弦波驱动，小幅自然颤动
      _phase += 2 * math.pi * _frequency / 60; // 每帧相位增量
      _mouthOpen =
          _minMouthOpen + (_amplitude * math.sin(_phase)).clamp(0, _amplitude);
      return _mouthOpen;
    }

    // 有声音时：音量直接驱动 + 正弦波叠加
    // volume 范围 [_silenceThreshold, 1.0]，映射到 [_minMouthOpen, _maxMouthOpen]
    final scaled =
        _minMouthOpen +
        (volume - _silenceThreshold) /
            (1.0 - _silenceThreshold) *
            (_maxMouthOpen - _minMouthOpen);

    // 正弦波叠加：说话时嘴型有自然颤动
    _phase += 2 * math.pi * _frequency / 60;
    _mouthOpen =
        scaled + (_amplitude * math.sin(_phase)).clamp(-_amplitude, _amplitude);
    return _mouthOpen.clamp(_minMouthOpen, _maxMouthOpen);
  }

  /// 动画帧（每 16ms 执行一次）
  void _tick() {
    // 无外部音量时，纯正弦波驱动（模拟说话中的自然颤动）
    _phase += 2 * math.pi * _frequency / 60;
    _mouthOpen =
        _minMouthOpen + (_amplitude * math.sin(_phase)).clamp(0, _amplitude);
    // 把嘴型值推到流，供监听方（Live2D 控制器）实时驱动口型
    if (!_mouthController.isClosed) _mouthController.add(_mouthOpen);
  }

  /// 释放资源
  void dispose() {
    stop();
    _stopController.close();
    _mouthController.close();
  }
}

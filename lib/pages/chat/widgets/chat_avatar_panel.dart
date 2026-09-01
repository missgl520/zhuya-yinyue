// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 漂移 3D 形象面板
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/avatar_viewer.dart';

/// 右侧漂移 3D 形象（随机漂移 + 走路动画）
class ChatAvatarPanel extends ConsumerStatefulWidget {
  const ChatAvatarPanel({super.key});

  @override
  ConsumerState<ChatAvatarPanel> createState() => _ChatAvatarPanelState();
}

class _ChatAvatarPanelState extends ConsumerState<ChatAvatarPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(vsync: this);
  final math.Random _rnd = math.Random();

  Size? _screen;
  Offset _offset = Offset.zero;
  Timer? _timer;
  Animation<Offset>? _anim;
  Animation<Offset>? _prevAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _screen = MediaQuery.of(context).size;
      _scheduleNextDrift();
    });
  }

  void _scheduleNextDrift() {
    if (!mounted) return;
    _timer = Timer(
      Duration(milliseconds: 3500 + _rnd.nextInt(5000)),
      _driftToRandom,
    );
  }

  void _onAnimTick() {
    if (mounted) setState(() => _offset = _anim!.value);
  }

  void _driftToRandom() {
    if (!mounted || _screen == null) {
      _scheduleNextDrift();
      return;
    }
    final sw = _screen!.width;
    final sh = _screen!.height;
    final target = Offset(
      (_rnd.nextDouble() * 2 - 1) * sw * 0.28,
      (_rnd.nextDouble() * 2 - 1) * sh * 0.22,
    );

    _prevAnim?.removeListener(_onAnimTick);
    _anim = Tween<Offset>(begin: _offset, end: target).animate(
      CurvedAnimation(parent: _drift, curve: Curves.easeInOutSine),
    );
    _anim!.addListener(_onAnimTick);
    _prevAnim = _anim;

    _drift.duration = Duration(milliseconds: 4000 + _rnd.nextInt(4000));
    _drift.forward(from: 0).then((_) {
      if (!mounted) return;
      _offset = target;
      avatarViewerController.stopWalk();
      _scheduleNextDrift();
    });
    avatarViewerController.playWalk();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _prevAnim?.removeListener(_onAnimTick);
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height * 0.78,
        child: const AvatarViewer(),
      ),
    );
  }
}

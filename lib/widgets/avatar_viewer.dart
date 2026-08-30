import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/avatar_provider.dart';

/// 3D 换装视图（WebView + Three.js）
class AvatarViewer extends ConsumerStatefulWidget {
  const AvatarViewer({super.key});

  @override
  ConsumerState<AvatarViewer> createState() => _AvatarViewerState();
}

class _AvatarViewerState extends ConsumerState<AvatarViewer> {
  late final WebViewController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setMediaPlaybackRequiresUserGesture(false)
      ..addJavaScriptChannel('avatarChannel', onMessageReceived: (_) {})
      ..loadFlutterAsset('assets/web/avatar_viewer.html');

    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) {
          setState(() => _ready = true);
          _sendFullState();
        },
        onWebResourceError: (err) {
          debugPrint('WebView error: ${err.description}');
        },
      ),
    );
  }

  // 公开方法，供外部调用
  void postMessage(Map<String, dynamic> msg) => _post(msg);

  void _post(Map<String, dynamic> msg) {
    if (!_ready) return;
    final json = jsonEncode(msg).replaceAll("'", "\\'");
    _controller.runJavaScript("window.postMessage($json, '*')").catchError((_) {});
  }

  void _sendFullState() {
    final state = ref.read(avatarStateProvider);
    _post({
      'type': 'load',
      'baseUrl':   state.basePath,
      'hairUrl':   state.hairPath,
      'topUrl':    state.topPath,
      'bottomUrl': state.bottomPath,
      'shoesUrl':  state.shoesPath,
      'eyeUrl':    state.eyePath,
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AvatarState>(avatarStateProvider, (prev, next) {
      if (!_ready) return;

      // 性别/基础模型变化 → 全量重载
      if (prev?.gender != next.gender) {
        _sendFullState();
        return;
      }

      if (prev?.hairId != next.hairId) {
        _post({'type': 'hair', 'url': next.hairPath});
      }
      if (prev?.topId != next.topId) {
        _post({'type': 'top', 'url': next.topPath});
      }
      if (prev?.bottomId != next.bottomId) {
        _post({'type': 'bottom', 'url': next.bottomPath});
      }
      if (prev?.shoesId != next.shoesId) {
        _post({'type': 'shoes', 'url': next.shoesPath});
      }
      if (prev?.eyeColor != next.eyeColor) {
        _post({'type': 'eye', 'url': next.eyePath});
      }
    });

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        // 走路/停止 按钮
        Positioned(
          bottom: 12, right: 12,
          child: _WalkButton(
            onPlay: () => _post({'type': 'playWalk'}),
            onStop: () => _post({'type': 'stopWalk'}),
          ),
        ),
      ],
    );
  }
}

class _WalkButton extends StatefulWidget {
  final VoidCallback onPlay, onStop;
  const _WalkButton({required this.onPlay, required this.onStop});
  @override
  State<_WalkButton> createState() => _WalkButtonState();
}

class _WalkButtonState extends State<_WalkButton> {
  bool _walking = false;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(24),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          setState(() => _walking = !_walking);
          _walking ? widget.onPlay() : widget.onStop();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _walking ? Icons.stop_rounded : Icons.directions_walk,
                size: 18, color: const Color(0xFF4a7a52),
              ),
              const SizedBox(width: 6),
              Text(
                _walking ? '停下' : '走路',
                style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: Color(0xFF4a7a52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';
import '../presentation/providers/avatar_provider.dart';

/// Web 平台 HTML 文件的相对 URL（相对于 Flutter web app 根路径）
const String _kWebAvatarViewerUrl = 'avatar_viewer.html';

/// 静态控制器，供外部（如 chat_page 漂移）驱动 AvatarViewer
class AvatarViewerController extends ChangeNotifier {
  void playWalk()  => _post({'type': 'playWalk'});
  void stopWalk()  => _post({'type': 'stopWalk'});

  void _post(Map<String, dynamic> msg) {
    _msg = msg;
    notifyListeners();
  }
  Map<String, dynamic>? _msg;
  Map<String, dynamic>? consume() {
    final m = _msg; _msg = null;
    return m;
  }
}
final avatarViewerController = AvatarViewerController();

/// 3D 换装视图（WebView + Three.js）
///
/// 加载策略：
/// - **Flutter Web**：从 web/ 目录加载 HTML（Three.js 可直接访问同目录的 models/）
/// - **iOS/Android**：从 assets 加载 HTML + CDN GLB（需 GLB 上传到公开 URL）
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
    avatarViewerController.addListener(_onControllerMsg);
  }

  void _onControllerMsg() {
    final msg = avatarViewerController.consume();
    if (msg != null) _post(msg);
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setMediaPlaybackRequiresUserGesture(false)
      ..addJavaScriptChannel('avatarChannel', onMessageReceived: (_) {});

    if (kIsWeb) {
      // Flutter Web：从 web/ 目录加载（models/ 是同目录子文件夹，Three.js 可直接访问）
      _controller.loadRequest(Uri.parse(_kWebAvatarViewerUrl));
    } else {
      // iOS/Android：从 assets 加载 HTML
      // 注意：需要 GLB 文件通过 CDN URL 加载，详见 docs/3D-AVATAR-RESEARCH.md
      _controller.loadFlutterAsset('assets/web/avatar_viewer.html');
    }

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

  /// 将 asset 路径映射为 web/ 相对路径（Flutter Web 用）
  String _toWebPath(String? assetPath) {
    if (assetPath == null) return '';
    // assets/vrm_test/avatar_system/base_female.glb → models/base_female_v2.glb
    // 只处理已知的路径模式，未知路径直接返回
    if (assetPath.contains('avatar_system')) {
      // 从 manifest.json 的 assets/ 路径 → web/ 相对路径
      final name = assetPath.split('/').last;
      if (name.startsWith('base_female')) return 'models/avatar_female_v2.glb';
      if (name.startsWith('base_male'))   return 'models/avatar_male_v2.glb';
      // 配件路径：hair_001.glb → models/hair_001.glb
      if (name.contains('_')) {
        return 'models/$name';
      }
    }
    // 其他资产路径（已经在 models/ 下）
    if (assetPath.startsWith('models/')) return assetPath;
    // 已经是 web/ 相对路径
    if (assetPath.startsWith('http')) return assetPath;
    return assetPath;
  }

  void _post(Map<String, dynamic> msg) {
    if (!_ready) return;
    final json = jsonEncode(msg).replaceAll("'", "\\'");
    _controller.runJavaScript("window.postMessage($json, '*')").catchError((_) {});
  }

  void _sendFullState() {
    final state = ref.read(avatarStateProvider);
    final baseUrl = kIsWeb ? _toWebPath(state.basePath) : state.basePath;
    _post({
      'type': 'load',
      'baseUrl':   baseUrl,
      'hairUrl':   kIsWeb ? _toWebPath(state.hairPath)   : state.hairPath,
      'topUrl':    kIsWeb ? _toWebPath(state.topPath)    : state.topPath,
      'bottomUrl': kIsWeb ? _toWebPath(state.bottomPath) : state.bottomPath,
      'shoesUrl':  kIsWeb ? _toWebPath(state.shoesPath)  : state.shoesPath,
      'eyeUrl':    kIsWeb ? _toWebPath(state.eyePath)   : state.eyePath,
    });
  }

  @override
  void dispose() {
    avatarViewerController.removeListener(_onControllerMsg);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AvatarState>(avatarStateProvider, (prev, next) {
      if (!_ready) return;
      if (prev?.gender != next.gender) {
        _sendFullState();
        return;
      }
      if (prev?.hairId != next.hairId)
        _post({'type': 'hair',   'url': kIsWeb ? _toWebPath(next.hairPath)   : next.hairPath});
      if (prev?.topId != next.topId)
        _post({'type': 'top',    'url': kIsWeb ? _toWebPath(next.topPath)    : next.topPath});
      if (prev?.bottomId != next.bottomId)
        _post({'type': 'bottom', 'url': kIsWeb ? _toWebPath(next.bottomPath) : next.bottomPath});
      if (prev?.shoesId != next.shoesId)
        _post({'type': 'shoes',  'url': kIsWeb ? _toWebPath(next.shoesPath)  : next.shoesPath});
      if (prev?.eyeColor != next.eyeColor)
        _post({'type': 'eye',    'url': kIsWeb ? _toWebPath(next.eyePath)   : next.eyePath});
    });

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
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

class _WalkButton extends ConsumerStatefulWidget {
  final void Function() onPlay, onStop;
  const _WalkButton({required this.onPlay, required this.onStop});

  @override
  ConsumerState<_WalkButton> createState() => _WalkButtonState();
}

class _WalkButtonState extends ConsumerState<_WalkButton> {
  @override
  Widget build(BuildContext context) {
    final isWalking = ref.watch(avatarStateProvider).isWalking;
    return Material(
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(24),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          final notifier = ref.read(avatarStateProvider.notifier);
          if (isWalking) {
            notifier.setWalking(false);
            widget.onStop();
          } else {
            notifier.setWalking(true);
            widget.onPlay();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isWalking ? Icons.stop_rounded : Icons.directions_walk,
                size: 18, color: const Color(0xFF4a7a52),
              ),
              const SizedBox(width: 6),
              Text(
                isWalking ? '停下' : '走路',
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

path = r"C:/Users/ROG/AppData/Local/Pub/Cache/hosted/pub.flutter-io.cn/model_viewer_plus-1.10.0/lib/src/model_viewer_plus_mobile.dart"
s = open(path, encoding="utf-8").read()
old = """    return WebViewWidget(
      platform: AndroidWebViewWidget(
        AndroidWebViewWidgetCreationParams(
          controller: _webViewController!,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
          },
          // Hybrid Composition：让 WebView 直接合成到 UI，规避 VirtualDisplay
          // 下页面被判「不可见」导致 WebGL/rAF 暂停、动画冻结的问题。
          displayWithHybridComposition: true,
        ),
      ),
    );"""
new = """    return WebViewWidget.fromPlatformCreationParams(
      params: android.AndroidWebViewWidgetCreationParams(
        controller: _webViewController!.platform,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
          Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
        },
        // Hybrid Composition：让 WebView 直接合成到 UI，规避 VirtualDisplay
        // 下页面被判「不可见」导致 WebGL/rAF 暂停、动画冻结的问题。
        displayWithHybridComposition: true,
      ),
    );"""
assert old in s, "OLD NOT FOUND"
s = s.replace(old, new, 1)
open(path, "w", encoding="utf-8").write(s)
print("PATCHED OK")

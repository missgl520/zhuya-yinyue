# 竹笌 · 技术深挖报告

> 生成时间：2026-09-04
> 范围：架构设计 / 代码质量 / 集成问题 / 优化路线

---

## 一、项目全貌

| 指标 | 数值 |
|------|------|
| Dart 文件 | 73 个 |
| 总代码行 | ~16,292 行 |
| 架构 | Clean Architecture（domain/data/presentation） |
| 状态管理 | Riverpod（StateNotifier） |
| 路由 | go_router |
| 3D 渲染 | WebView + Three.js（avatar_viewer.html） |

### 核心模块

```
lib/
├── core/               # 基础设施
│   ├── auth/          ✅ ClientAuth（HMAC-SHA256 鉴权，已实现）
│   ├── config.dart    # 后端地址、API 配置
│   ├── services/      # 服务层
│   │   ├── agnes_service.dart       # Agnes AI 多模态
│   │   ├── sherpa_onnx_service.dart ⚠️ 占位实现
│   │   ├── model_manager.dart       ⚠️ 硬编码 URL
│   │   ├── chat_service.dart        ✅ SSE 流式对话
│   │   ├── tts_service.dart         # TTS 抽象层
│   │   └── ...
│   └── theme/         # AppTheme
├── data/services/
│   └── chat_service.dart  ✅ SSE 解析、情绪事件
├── domain/entities/   # Message、Emotion、Affinity
├── presentation/providers/
│   ├── avatar_provider.dart       ✅ Riverpod 换装状态
│   ├── chat_provider.dart        ✅ ChatNotifier
│   ├── sherpa_onnx_provider.dart  ⚠️ 依赖占位服务
│   └── settings_provider.dart
└── widgets/
    ├── avatar_viewer.dart   ⚠️ WebView asset 路径问题
    └── ...
```

---

## 二、严重问题（需立即修复）

### 🔴 问题 1：Sherpa-ONNX 是空壳代码

`sherpa_onnx_service.dart` 中 ASR 和 TTS 均是占位实现：

```dart
// lib/core/services/sherpa_onnx_service.dart

// 第 220 行
Future<String> _placeholderRecognize(String audioPath, SherpaAsrConfig config) async {
  await Future.delayed(const Duration(milliseconds: 100));
  return '（ASR 识别结果）';  // ← 永远返回占位文字
}

// 第 225 行
Future<String?> _placeholderSynthesize(...) async {
  await Future.delayed(const Duration(milliseconds: 100));
  return null;  // ← 永远返回 null（失败）
}
```

`sherpa_onnx_provider.dart` 调用的就是这个空壳——**语音对话功能实际上不可用**。

**影响：** 用户的语音输入无法被识别，TTS 语音合成也无效。用户在 App 里的语音功能形同虚设。

**根本原因：** `pubspec.yaml` 声明了 `sherpa_onnx: ^1.13.7` 依赖，但实际代码里只写了接口框架，没有调用 `sherpa_onnx` 包的真实 API。

---

### 🔴 问题 2：ModelManager 硬编码占位 URL

```dart
// lib/core/services/model_manager.dart 第 103 行
static const String _versionCheckUrl =
    'https://github.com/your-org/sherpa-models/releases/latest/download/version.json';
    //                        ↑ 需要替换为真实 CDN
```

`your-org/sherpa-models` 只是一个占位符，模型增量更新功能完全无法工作。

**需要：** 替换为实际的 CDN 地址（如火山引擎 OSS、Gitee、GitHub Releases 等）。

---

### 🔴 问题 3：Avatar WebView 无法加载 GLB 文件

Flutter 传路径给 WebView 的方式有 bug：

```dart
// avatar_viewer.dart 第 78 行
_post({
  'type': 'load',
  'baseUrl': state.basePath,  // → 'assets/vrm_test/avatar_system/base_female.glb'
  ...
});
```

但 `avatar_viewer.html` 里的 `loadGLB(url)` 直接用 Three.js 的 `GLTFLoader.load(url)`：

```javascript
// avatar_viewer.html
loader.load(url, ...)  // url 必须是 HTTP URL 或相对于 HTML 的路径
```

**问题：** WebView 无法解析 Flutter asset URI（`asset:///` 协议）。需要通过 `toFlutterAssetUri()` 将 asset 路径转为可访问的 HTTP URL，或者将 GLB 文件放到 WebView 可访问的位置。

---

## 三、中等问题

### 🟡 问题 4：avatar_provider 路径与实际资源不匹配

`avatar_provider.dart` 返回的路径：
```dart
String get basePath => 'assets/vrm_test/avatar_system/base_$genderStr.glb';
```

但本次生成的 QQ 炫舞模型位于：
```
assets/web/models/avatar_female_v2.glb   ← 不在 vrm_test/avatar_system/
assets/web/models/avatar_male_v2.glb
```

**两个选择：**

**方案 A（独立展示）：** v2 模型作为独立的"展示模式"，不和现有换装系统混用。用户点击"3D 预览"时加载 v2 模型，换装页面仍用原有 base + accessories。

**方案 B（替换 base）：** 将 `avatar_female_v2.glb` / `avatar_male_v2.glb` 复制到 `assets/vrm_test/avatar_system/base_female_v2.glb`，修改 `avatar_provider.dart` 的 `basePath` 指向 v2。

---

### 🟡 问题 5：生成的模型是"一体式"，不适配换装槽位

现有的换装系统是**模块化**的：
- `base` = 裸身体
- `hair` / `top` / `bottom` / `shoes` / `eye` = 可拆卸配件

v2 模型是**一体式**（头发+服装+帽子全合并），不能拆成配件槽位。

**建议：** v2 模型用作「完整角色展示」或「换装系统的 base model」，在 base 基础上叠加配件。

---

## 四、架构亮点（做得好的）

### ✅ ClientAuth 设计完善
- HMAC-SHA256 请求签名，防篡改
- `--dart-define` 注入密钥，不进仓库
- UUID 设备标识，Hive 持久化

### ✅ SSE 流式对话
- 后端推送 `text` / `emotion` / `done` 事件分离
- 情绪变化触发 avatar 表情变化（`emotionTtsEngineProvider`）

### ✅ Riverpod 状态管理
- 新架构（`presentation/providers/`）结构清晰，`AvatarStateNotifier` 用 `copyWith` 保证不可变性
- `manifest.json` 静态资源清单 + `AvatarCatalog` 中文名映射，设计合理

### ✅ Three.js 换装系统
- WebView 隔离渲染，避免 Flutter WebGL 兼容性问题
- 淡入淡出、骨骼动画、待机呼吸、手动走路等细节完整
- `EffectComposer` + `UnrealBloomPass` 增强视觉效果

---

## 五、优先级修复路线

### P0（影响核心功能）

**1. 实现 Sherpa-ONNX ASR/TTS**

参考 sherpa-onnx 官方 Dart 示例：

```dart
// ASR（Paraformer-zh）
import 'package:sherpa_onnx/sherpa_onnx.dart';

final recognizer = await OnlineRecognizer.create(
  model: config.modelPath,
  tokens: config.tokensPath,
  sampleRate: 16000,
);
// 定时喂 PCM 数据
recognizer.acceptWaveform(samples);
final text = recognizer.text;

// TTS（Vits 中文）
final tts = await OfflineTts.create(
  model: config.modelPath,
  tokens: config.tokensPath,
);
await tts.connect();
await tts.addText(text);
final wav = await tts.output;
```

**2. 修复 WebView GLB 加载**

在 avatar_viewer.dart 中使用 Flutter 1.24+ 的 `toFlutterAssetUri`：

```dart
final assetUri = await _controller.getUrl();
// 或用 flutter_asset_loader 包
```

**3. 上线 ModelManager CDN**

替换 `_versionCheckUrl` 为实际可用的版本检查接口。

### P1（体验优化）

- 将 v2 模型接入 avatar_viewer（选方案 A 或 B）
- 完善 avatar_viewer.html 的走路动画（当前走路动画是手动实现的，GLB 需要骨骼动画）
- AvatarCatalog 中的中文名称增加更多条目

### P2（长期）

- Blender 精修 3D 模型拓扑，加 Mixamo 骨骼动画
- TripoSR/MiDaS 集成（网络好时替换参数化建模）
- 端侧记忆系统（Sqflite FTS5 搜索）

---

## 六、文件索引

| 文件 | 行数 | 状态 |
|------|------|------|
| `lib/core/services/sherpa_onnx_service.dart` | 313 | ⚠️ 占位 |
| `lib/core/services/model_manager.dart` | ~300 | ⚠️ 占位URL |
| `lib/widgets/avatar_viewer.dart` | 179 | ⚠️ 路径bug |
| `lib/presentation/providers/avatar_provider.dart` | ~200 | ✅ 好 |
| `lib/presentation/providers/chat_provider.dart` | ~300 | ✅ 好 |
| `lib/data/services/chat_service.dart` | 290 | ✅ 好 |
| `lib/core/auth/client_auth.dart` | ~150 | ✅ 好 |
| `assets/web/avatar_viewer.html` | 553 | ⚠️ 需配路径 |
| `assets/web/preview_3d.html` | ~250 | ✅ 新增 |
| `tools/enhanced_image_to_glb.py` | ~350 | ✅ 新增 |

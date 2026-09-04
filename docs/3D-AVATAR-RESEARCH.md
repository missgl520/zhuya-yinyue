# 3D 头像系统 · 深度调研报告

> 范围：avatar_viewer 技术细节 / 同类开源项目对比 / 集成路线
> 日期：2026-09-04

---

## 一、当前 avatar_viewer 完整解析

### 1.1 架构全貌

```
Flutter 端                          WebView 端 (Three.js)
─────────────────                   ─────────────────────
avatar_viewer.dart ──postMessage──→ avatar_viewer.html
     │                                      │
     │ loadFlutterAsset()                   │ GLTFLoader.load(url)
     │     ↓                                │     ↓
     │ HTML served from asset://            │ Three.js Scene
     │     ↓                                │
     │ basePath: "assets/vrm_test/..."     │ baseGroup (主角色)
     │     ↓                                │ accessoryGroups[5槽位]
     │ JS postMessage({baseUrl: ...})      │
```

### 1.2 已实现的特性（做得好的）

| 特性 | 实现方式 |
|------|---------|
| 淡入淡出 | 手动 opacity 插值，500ms |
| 待机呼吸 | `sin(idleT*1.3)*0.007` Y轴浮动 |
| 走路动画 |骨骼动画优先 / 手动 sine 备用 |
| 配件跟随 | `syncAccessories()` 同步 baseGroup 位移 |
| 骨骼动画混合 | `crossFadeTo()` + `AnimationMixer` |
| Bloom 发光 | `UnrealBloomPass(0.25, 0.6, 0.82)` |
| 轮廓描边 | `OutlinePass` + `visibleEdgeColor` |
| 三点布光 | keyLight(2.2) + fillLight(0.8) + rimLight(0.6) |
| PMREM 环境贴图 | `RoomEnvironment` → `scene.environment` |
| 投影阴影 | `castShadow` + `ShadowMaterial` |
| GLB 缓存 | `cache[url]` 复用 `clone(true)` |
| 阴影圆环 | `shadowCircle` + `ring` 装饰 |

### 1.3 关键 Bug：WebView 无法加载 GLB

**根因：** Flutter `loadFlutterAsset()` 将 HTML 作为 asset 加载，但 `baseUrl` 参数传的是 Flutter asset 路径字符串。Three.js `GLTFLoader.load(url)` 收到这个字符串后：

```javascript
// avatar_viewer.html 第 236 行
async function loadGLB(url, onProgress) {
  loader.load(url, ...)  // url = "assets/vrm_test/avatar_system/base_female.glb"
  // ↑ 在 asset:// 协议下，这个路径根本不存在
}
```

**修复方案（三选一）：**

```
方案 A：FlutterAssetLoader（推荐，改动最小）
  Flutter 端：注册 JavaScript channel，拦截 asset 路径请求
  Flutter 端：读取 asset 文件内容，转为 data URL 或 blob URL
  Flutter 端：通过 channel 返回给 JS
  JS 端：拦截 loader.load()，改为 fetch(dataURL)

方案 B：web/ 目录（Flutter web 专用，最干净）
  将 GLB 文件放到 web/models/（Flutter web 编译时打包进 assets）
  JS 端：loader.load('models/avatar_female_v2.glb') 相对路径即可
  注意：web/ 只在 web 平台生效，不影响 iOS/Android

方案 C：CDN URL（生产环境推荐）
  GLB 上传到 CDN（jsdelivr / 自己的 OSS）
  JS 端：loader.load('https://cdn.jsdelivr.net/.../avatar_female_v2.glb')
  Flutter 端：传 URL 字符串，不传 asset 路径
```

---

## 二、同类开源项目调研

### 2.1 Ready Player Me（最相关竞品）

**地址：** https://readyplayerme.com / https://github.com/readyplayerme
**定位：** 通用头像平台，176k GitHub stars，支持 glTF/VRM

**核心 SDK：**
- Web SDK：`<iframe src="https://[partner].readyplayer.me/...">`
- REST API：创建 session → 用户自定义 → 导出 glTF URL
- Flutter SDK（社区）：`ready_player_me_flutter`

**技术亮点：**
- 体型选择（ slim / normal / broad / athletic）
- 服装分层（base + 配件完全模块化）
- glTF 2.0 导出，100% 标准格式
- 面部表情 BlendShape 支持
- 配套 Ready Player Me Unity/Unreal/Three.js 示例

**可借鉴点：**
- 头像"模块化"设计理念 → 竹笌的 base + accessories 槽位是一致的思路
- RPM 用 blendShape 驱动表情 → 竹笌的 Live2D 表情系统可以对应
- 导出 URL 直接可下载 → 竹笌的 CDN 分发方案

**局限性：** 不支持中文/国风服装风格，自定义程度有限

---

### 2.2 VRM（虚拟偶像行业标准）

**地址：** https://vrm.dev / https://github.com/vrm-c/vrm-specification
**定位：** Anime-style 3D avatar 通用格式，VRChat / Virtual YouTuber 圈标配

**技术规格：**
- 基于 glTF 2.0 扩展
- 内置 `VRMC_springBone`（程序化骨骼物理：头发/裙子飘动）
- `VRMC_vrm` 扩展：BlendShape（表情）、LookAt（视线追踪）、FirstPerson（VR单眼渲染）
- Humanoid skeleton（与 Unity humanoid 兼容）
- 一体化格式：模型+纹理+骨骼+表情+碰撞体 全部打包在 .vrm

**工具链：**
- UniVRM（Unity）— VRM 导出器
- `vrmlib` / `vrmpy` — Python VRM 读写
- three.js VRM loader — `three-vrm`

**可借鉴点：**
- VRM 的 `springBone` 物理系统 → 解决竹笌裙子/头发飘动
- `BlendShape` 表情映射 → 对接 Live2D 表情事件
- `LookAt` 视线追踪 → 角色视线跟随鼠标/对话对象

**现状：** 竹笌的 `avatar_system/manifest.json` 结构已经类似 VRM 的思路（资源清单+元数据），升级到 VRM 格式是可行的长期目标。

---

### 2.3 VRoid Hub / PixiKaze

**地址：** https://vroid.com / https://hub.vroid.com
**定位：** 字节跳动旗下，动漫风头像平台（月活 1000 万+）

**技术特点：**
- AI 生成初始头像（用户选风格/特征）
- 在线换装（服装库）
- VRM 格式输出
- Unity SDK（VRoid SDK）

**可借鉴点：** AI 生成初始头像 → 对应竹笌的 2D→3D 管线（我们已有）

---

### 2.4 Mixamo（骨骼动画金标准）

**地址：** https://mixamo.com（Adobe 旗下）
**定位：** 免费骨骼动画库 + 自动绑定工具

**技术细节：**
- 自动骨骼绑定（上传 GLB，Auto-Rigger 30秒完成）
- 20+ 免费动画：走路/跑步/跳舞/待机/打招呼
- 可以调整动画速度、循环方式
- 下载 .glb / .fbx，含骨骼+AnimationClip

**对竹笌的价值：**
```
v2 模型 → Mixamo Auto-Rigger → 骨骼绑定 →走路/待机/跳舞动画
                                     ↓
              avatar_viewer.html 的 playWalk() 就能用骨骼动画
              而不是现在的手动 sine 插值
```

**实际操作路径：**
1. 下载 `avatar_female_v2.glb` 和 `avatar_male_v2.glb`
2. 上传 mixamo.com 自动绑定骨骼
3. 选择走路、待机动画，下载 GLB（含 `Walk` / `Idle` AnimationClip）
4. 将动画 GLB 分离为 base.glb + walk.glb + idle.glb
5. avatar_viewer.html 的 `playWalk()` 自动找到 `Walk` 动画播放

---

### 2.5 Exporter 工具链对比

| 工具 | 用途 | 适用格式 |
|------|------|---------|
| Blender + three.js export | glTF 2.0 导出 | glTF/GLB |
| VRoid Studio | AI 生成动漫头像 | VRM |
| Ready Player Me | 通用头像创建 | glTF |
| Mixamo Auto-Rigger | 骨骼绑定 | glTF |
| fSpy | 从单张图片估算相机参数 | 3D 重建 |
| TripoSR | AI 单图→3D（需 GPU） | glTF |

---

## 三、avatar_viewer 改进路线图

### P0：修 Bug，让 GLB 能正常加载

**方案 B（web/ 目录）实现步骤：**

```bash
# 1. 将 v2 模型复制到 web/models/
mkdir -p assets/web/models/
cp assets/web/models/avatar_female_v2.glb web/models/
cp assets/web/models/avatar_male_v2.glb web/models/

# 2. 更新 avatar_provider.dart 路径
# 原来：'assets/vrm_test/avatar_system/base_female.glb'
# 改为：'models/avatar_female_v2.glb'  （相对于 HTML 的路径）
```

**Flutter 端：** `avatar_viewer.dart` 不需要改，它只传字符串路径。HTML 里 `loader.load('models/avatar_female_v2.glb')` 即可访问。

---

### P1：为 v2 模型添加骨骼动画

**方法 A（Mixamo 在线）：**
```
avatar_female_v2.glb → mixamo.com Auto-Rigger → 下载含骨骼的 GLB
→ three.js AnimationMixer 自动播放 Walk/Idle 动画
```

**方法 B（Blender 绑定）：**
```
Blender:
1. import avatar_female_v2.glb
2. 添加 Armature → 自动权重绑定
3. 创建 Walk / Idle NLA 轨道
4. Export as GLB（animation 勾选 ✅）
```

---

### P2：VRM 格式升级（长期）

**路线：**
```
v2 GLB → Blender → VRM 格式导出
  ↓
VRM 的 springBone → 头发/裙子自动飘动
VRM 的 BlendShape → 对接 Live2D 表情事件
VRM 的 LookAt → 视线跟随
```

---

### P3：表情系统（参考 Live2D → VRM）

当前竹笌用 Live2D 驱动表情（`emotionTtsEngineProvider` → `setEmotion`），但 3D 模型无表情。两种方案：

```
方案 A：BlendShape 驱动
  Live2D 表情 → 映射到 VRM BlendShape → 3D 角色有表情
  需要：VRM 模型支持 BlendShape

方案 B：道具遮罩
  在 eye 槽位叠加不同表情的 eye_*.glb（张嘴/闭嘴/眨眼）
  简单但素材多
```

---

## 四、具体实现代码

### 4.1 修复：WebView GLB 加载（方案 B）

```dart
// avatar_provider.dart
String get basePath {
  // web/ 目录下的路径，相对于 HTML 文件
  return 'models/avatar_female_v2.glb';  // 或从性别切换
}
```

```html
<!-- web/models/ 下的 GLB 文件会被打包进 Flutter web assets -->
<!-- avatar_viewer.html 直接用相对路径即可 -->
loader.load('models/avatar_female_v2.glb', ...)
```

### 4.2 avatar_viewer.html 添加动画支持

```javascript
// 增强 playWalk — 优先找骨骼动画，找不到用手动摆动
function playWalk() {
  const clips = baseGroup.userData.gltfAnimations || [];
  if (clips.length > 0) {
    // 有骨骼动画 → mixer 播放
    const clip = THREE.AnimationClip.findByName(clips, 'Walk')
              || clips.find(c => /walk/i.test(c.name))
              || clips[0];
    if (mixer) { mixer.stopAllAction(); mixer = null; }
    mixer = new THREE.AnimationMixer(baseGroup);
    const action = mixer.clipAction(clip);
    action.setLoop(THREE.LoopRepeat, Infinity);
    action.reset().fadeIn(0.3).play();
    currentAction = action;
    animMode = 'walk';
  } else {
    // 无骨骼动画 → 增强手动走路（头部+手臂摆动）
    startManualWalk();
  }
}

// 增强手动走路：加入手臂摆动
let manualWalkT = 0;
function startManualWalk() {
  animMode = 'walk';
  manualWalkT = 0;
}
function updateManualWalk(dt) {
  if (animMode !== 'walk' || !baseGroup) return;
  manualWalkT += dt;
  // 身体上下起伏
  baseGroup.position.y = baseIdleY + Math.abs(Math.sin(manualWalkT * 4)) * 0.06;
  // 轻微左右摇摆
  baseGroup.rotation.z = Math.sin(manualWalkT * 4) * 0.03;
  syncAccessories();
}
```

### 4.3 动态表情（BlendShape 映射）

```javascript
// avatar_viewer.html 中接收表情指令
const expressionMap = {
  'happy':   { blendShapes: { 'smile': 1.0 } },
  'sad':     { blendShapes: { 'frown': 0.8 } },
  'angry':   { blendShapes: { 'frown': 0.5, 'eye_squint': 0.6 } },
  'surprised': { blendShapes: { 'brow_up': 1.0 } },
};

// 表情切换（需 GLB 支持 BlendShape）
function setExpression(name) {
  const expr = expressionMap[name];
  if (!expr) return;
  baseGroup.traverse(c => {
    if (c.isSkinnedMesh && c.morphTargetInfluences) {
      Object.entries(expr.blendShapes).forEach(([key, val]) => {
        const idx = c.morphTargetDictionary?.[key];
        if (idx !== undefined) c.morphTargetInfluences[idx] = val;
      });
    }
  });
}

// 监听 Flutter 传来的表情事件
window.addEventListener('message', async (event) => {
  const data = event.data;
  if (data.type === 'expression' && data.emotion) {
    setExpression(data.emotion);
  }
  // ...
});
```

---

## 五、文件清单（建议调整后）

```
assets/
├── web/
│   ├── avatar_viewer.html    # 3D 换装系统（需修复GLB路径）
│   ├── preview_3d.html      # 独立预览页（已验证OK）
│   └── models/              # ⭐ Web 可直接访问的模型目录
│       ├── avatar_female_v2.glb   # 增强参数化模型
│       ├── avatar_male_v2.glb     # 增强参数化模型
│       ├── hair_001.glb           # 换装配件（发型）
│       ├── top_001.glb            # 换装配件（上装）
│       ├── bottom_001.glb         # 换装配件（下装）
│       ├── shoes_001.glb          # 换装配件（鞋子）
│       └── eye_001.glb            # 换装配件（瞳色）
└── vrm_test/                      # Flutter native assets（Android/iOS）
    └── avatar_system/
        └── manifest.json          # 资源清单

# v2 模型接入换装系统后：
# avatar_provider.dart → basePath = 'models/avatar_female_v2.glb'
# 其他配件路径 → 'models/hair_001.glb' 等
```

---

## 六、参考链接

| 项目 | 地址 | 类型 |
|------|------|------|
| Ready Player Me | https://readyplayerme.com | 直接竞品 |
| VRM 规格 | https://vrm.dev/en/vrm_spec/ | 格式标准 |
| three-vrm | https://github.com/pixiv/three-vrm | Three.js VRM 加载器 |
| Mixamo | https://www.mixamo.com | 骨骼动画 |
| VRoid Hub | https://hub.vroid.com | 字节头像平台 |
| Sherpa-ONNX Dart | https://k2-fqa.github.io/sherpa-onnx/ | ASR/TTS |
| Avatar Fusion (meshy.ai) | https://meshy.ai | AI 3D 重建（竞品） |
| TripoSR | https://github.com/VAST-AI-Research-VLL/TripoSR | 开源单图→3D |

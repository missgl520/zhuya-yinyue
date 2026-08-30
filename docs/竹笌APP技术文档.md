# 竹笌（ZhuyApp）技术文档

> 版本：1.0.0  
> 更新日期：2026-08-27  
> 项目仓库：https://github.com/missgl520/zhuyapp

---

## 一、项目概述

### 1.1 产品定位

**竹笌**是一款 **2D/3D 虚拟角色语音陪聊助手**，通过 Live2D 虚拟形象、流式 AI 对话、语音合成与识别、长期记忆、好感度系统等能力，为用户提供沉浸式的虚拟陪伴体验。

### 1.2 核心功能

| 功能模块 | 说明 |
|---|---|
| 流式对话 | 基于 Agnes 大模型的 SSE 流式对话，支持角色设定与指令遵循 |
| 虚拟形象 | Live2D 2D 角色渲染 + 3D VRM 全身模型，支持表情/动作/口型同步 |
| 语音交互 | ASR 语音识别 + 多引擎 TTS（本地 IndexTTS / Cartesia / MiniMax / 系统 TTS） |
| 实时语音通话 | 基于 LiveKit 的实时语音房 |
| 长期记忆 | 对话记忆持久化 + 跨会话记忆注入 + 关键词搜索 + 每日摘要 |
| 好感度系统 | trust / intimacy / familiarity 三维度 + 连续打卡天数 |
| 情绪识别 | 14 维规则情绪引擎，驱动角色表情变化 |
| 离线优先 | 本地 SQLite + Hive 存储，断网消息进发出箱，联网自动同步 |
| 多角色切换 | gentle（温柔）/ playful（俏皮）/ wise（智慧）三种人格 |

### 1.3 关联仓库

| 仓库 | 说明 |
|---|---|
| `zhuyapp` | 主仓库（Flutter 前端 + 文档） |
| `zhuyapp-backend` | Python FastAPI 后端服务 |
| `idiot-dog` | 前端开发分支（git remote: idiotdog） |

---

## 二、技术栈

### 2.1 前端（Flutter）

| 类别 | 技术 | 版本 | 用途 |
|---|---|---|---|
| 框架 | Flutter | Dart SDK ^3.12.2 | 跨平台移动端 |
| 状态管理 | flutter_riverpod | ^2.6.1 | 响应式状态 + 依赖注入 |
| 路由 | go_router | ^14.8.1 | 声明式路由 |
| 本地存储 | hive / hive_flutter | ^2.2.3 / ^1.1.0 | 键值存储（设置/消息/记忆） |
| 本地数据库 | sqflite | ^2.4.2 | 对话历史 + 长期记忆（FTS5 曾用，v2 移除） |
| HTTP | dio / http | ^5.11.0 / ^1.3.0 | API 调用 + SSE 流式 |
| TTS | flutter_tts / just_audio | ^4.2.0 / ^0.9.43 | 系统 TTS + 在线音频播放 |
| ASR | speech_to_text | ^7.0.0 | 语音转文字 |
| 虚拟角色 | flutter_live2d | path: ./vendor | Live2D 2D 渲染 |
| 3D 模型 | model_viewer_plus | ^1.10.0（本地补丁） | VRM/GLB 3D 渲染 |
| 实时语音 | livekit_client | ^2.10.0 | LiveKit 语音房 |
| 权限 | permission_handler | ^12.0.3 | 麦克风/存储权限 |
| 加密 | crypto / pointycastle / flutter_secure_storage | ^3.0.6 / ^4.0.0 / ^9.2.0 | 请求签名 + 本地加密 |
| 网络监听 | connectivity_plus | ^7.0.0 | 离线同步触发 |

### 2.2 后端（Python）

| 类别 | 技术 | 用途 |
|---|---|---|
| 框架 | FastAPI | REST + SSE 流式接口 |
| 数据库 | SQLAlchemy Core | SQLite（开发）/ MySQL（生产）统一接口 |
| 加密 | cryptography (Fernet) | 个人数据 at-rest 加密 |
| 鉴权 | HMAC-SHA256 | API Key + 请求签名 + 防重放 |
| AI 对话 | Agnes 2.0 Flash | 大模型流式生成（国内版 api.agnes-ai.cn） |
| TTS | IndexTTS 2.5 | 本地离线语音合成微服务（端口 8001） |
| 实时语音 | LiveKit | 语音房 JWT 令牌签发 |
| 部署 | Docker + Nginx | 容器化 + 反向代理 + HTTPS |

---

## 三、系统架构

### 3.1 整体架构图

```
┌─────────────────────────────────────────────────────────┐
│                    用户设备（Flutter App）                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐ │
│  │  UI 层   │  │ 状态管理  │  │  服务层   │  │ 本地存储│ │
│  │ (pages)  │  │(Riverpod)│  │(services) │  │Hive+SQL│ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └───┬────┘ │
│       │              │              │              │      │
│       └──────────────┴──────────────┴──────────────┘      │
│                              │                               │
│              ┌───────────────┴───────────────┐             │
│              │   Dio HTTP 客户端（签名拦截器）  │             │
│              └───────────────┬───────────────┘             │
└──────────────────────────────┼──────────────────────────────┘
                               │ HTTPS
┌──────────────────────────────┼──────────────────────────────┐
│                        后端服务（FastAPI）                    │
│  ┌─────────┐ ┌─────────┐ ┌──────────┐ ┌─────────────────┐ │
│  │ 鉴权中间件│ │ 路由层   │ │ 业务逻辑  │ │  外部服务集成    │ │
│  │ (auth)  │ │ (main)  │ │(memory/  │ │(Agnes/LiveKit/  │ │
│  │         │ │         │ │ affinity/ │ │ IndexTTS)        │ │
│  │         │ │         │ │ emotion)  │ │                 │ │
│  └────┬────┘ └────┬────┘ └────┬─────┘ └────────┬────────┘ │
│       │            │            │                 │          │
│       └────────────┴────────────┴─────────────────┘          │
│                              │                                  │
│              ┌───────────────┴───────────────┐                 │
│              │      SQLAlchemy 数据访问层       │                 │
│              └───────────────┬───────────────┘                 │
│                              │                                  │
│              ┌───────────────┴───────────────┐                 │
│              │  SQLite（开发）/ MySQL（生产）   │                 │
│              │  memories / affinity / kv       │                 │
│              └───────────────────────────────┘                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 前端分层架构

竹笌前端采用 **Clean Architecture 风格**的四层结构：

```
lib/
├── presentation/     # 展示层：Riverpod Providers（状态管理）
│   └── providers/
│       ├── app_providers.dart      # 全局 Provider（主题/路由等）
│       └── chat_provider.dart      # 对话状态机（核心）
├── pages/            # 页面层：各功能页面 Widget
│   ├── splash/                    # 启动页
│   ├── chat/                      # 对话主页（核心，43KB）
│   ├── voice/                     # 实时语音通话页
│   ├── avatar/                    # 3D 角色全屏页
│   ├── discover/                  # 发现页
│   ├── profile/                   # 我的页
│   ├── settings/                  # 设置页（菜单/记忆历史/信息模块）
│   └── legal/                     # 法律文档页
├── widgets/          # 组件层：可复用 UI 组件
│   ├── live2d_controller.dart    # Live2D 角色控制器（19KB，核心）
│   ├── live2d_widget.dart        # Live2D 渲染 Widget
│   ├── vrm_avatar_view.dart      # 3D VRM 头像视图
│   ├── chat_bubble.dart          # 聊天气泡
│   ├── voice_button.dart         # 语音按钮
│   ├── dashed_container.dart     # 虚线容器
│   └── image_picker_button.dart  # 图片选择按钮
├── domain/           # 领域层：实体与仓库接口
│   ├── entities/
│   │   ├── message.dart           # 消息实体
│   │   ├── emotion.dart           # 情绪实体
│   │   ├── affinity.dart          # 好感度实体
│   │   └── entities.dart          # 导出
│   └── repositories/
│       ├── chat_repository.dart   # 对话仓库接口（含 ChatEventType）
│       └── repositories.dart
├── data/             # 数据层：仓库实现 + 数据源 + 服务
│   ├── datasources/
│   │   └── chat_local_data_source.dart  # 本地对话数据源（SQLite）
│   ├── repositories/
│   │   └── chat_repository_impl.dart     # 对话仓库实现
│   └── services/
│       └── chat_service.dart     # SSE 流式对话服务（核心）
├── core/             # 核心层：基础设施
│   ├── config.dart               # 后端配置单例
│   ├── auth/
│   │   └── client_auth.dart      # 客户端鉴权（签名拦截器）
│   ├── router/
│   │   └── app_router.dart       # GoRouter 路由配置
│   ├── security/
│   │   └── local_encryption.dart # 本地 AES-256-CBC 加密
│   ├── services/                  # 核心服务集合
│   │   ├── backend_service.dart   # 后端 API 统一入口
│   │   ├── chat_service.dart      # （注：实际在 data/services）
│   │   ├── memory_service.dart    # 记忆服务（本地+后端）
│   │   ├── tts_service.dart       # TTS 调度
│   │   ├── cartesia_tts_service.dart   # Cartesia 在线 TTS
│   │   ├── mini_max_tts_service.dart    # MiniMax 在线 TTS
│   │   ├── asr_service.dart       # ASR 语音识别
│   │   ├── agnes_service.dart     # Agnes 服务
│   │   ├── lip_sync_service.dart  # 口型同步
│   │   └── livekit_service.dart   # LiveKit 语音房
│   ├── sync/
│   │   └── sync_engine.dart       # 离线同步引擎
│   └── theme/
│       └── app_theme.dart         # 主题（亮/暗）
├── providers/        # 旧版 Providers（兼容保留）
│   └── app_providers_legacy.dart
├── vrm_test_main.dart             # 3D 测试入口
└── main.dart                      # App 主入口
```

### 3.3 后端模块结构

```
zhuyapp-backend/
├── main.py                 # FastAPI 主应用 + 全部路由（22KB，核心）
├── config.py               # 配置（.env 读取 + Agnes 硬编码密钥）
├── auth.py                 # 接口签名鉴权（HMAC-SHA256 + 防重放）
├── db.py                   # 统一数据库入口（SQLAlchemy，SQLite/MySQL）
├── encryption.py           # 静态加密（Fernet，at-rest）
├── memory_store.py         # 长期记忆存储（加密 + 搜索 + 摘要）
├── affinity_store.py       # 好感度存储（加密 JSON blob）
├── emotion_engine.py       # 14 维规则情绪识别引擎
├── agnes_client.py         # Agnes 大模型流式客户端 + Mock 兜底
├── content_moderation.py   # 违规内容前置过滤（MVP）
├── livekit_token.py        # LiveKit JWT 令牌签发
├── requirements.txt        # Python 依赖
├── .env.example            # 环境变量模板
├── legal/                  # 隐私政策 / 用户协议（Markdown 模板）
├── deploy/                 # 部署配置（Docker + Nginx）
├── tests/                  # 测试
├── tts_service/            # 本地 IndexTTS 2.5 微服务
│   └── index-tts/          # IndexTTS 引擎 + checkpoints
└── data/                   # 运行时数据（zhuyu.db / .enc_key / 日志）
```

---

## 四、前端核心机制详解

### 4.1 应用启动流程

```
main()
  │
  ├─ WidgetsFlutterBinding.ensureInitialized()
  ├─ Hive.initFlutter()
  │   ├─ openBox('settings')    → 设置/配置
  │   ├─ openBox('messages')    → 消息缓存
  │   └─ openBox('memory')      → 记忆缓存
  ├─ BackendConfig.instance.init()   → 从 Hive 恢复后端地址/唤醒词/角色
  ├─ SyncEngine.instance.start()      → 启动离线同步（监听网络+定时兜底）
  ├─ 首次启动：默认后端地址落库
  └─ runApp(ProviderScope(child: ZhuyApp()))
       │
       └─ MaterialApp.router
            ├─ routerProvider → GoRouter（initialLocation: '/'）
            ├─ themeProvider → 亮/暗主题切换
            └─ 路由表：
                 /          → SplashPage（2.5s 后跳转 /chat）
                 /chat      → ChatPage（对话主页）
                 /voice-call→ VoiceCallPage（实时语音）
                 /avatar    → AvatarFullscreenPage（3D 全屏）
                 /discover  → DiscoverPage（发现）
                 /profile   → ProfilePage（我的）
                 /memory-history → MemoryHistoryPage（记忆历史）
                 /legal     → LegalPage（隐私/协议）
                 /info      → InfoModulesPage（信息模块）
```

### 4.2 对话状态机（ChatProvider）

对话流程采用 **Riverpod StateNotifier** 管理，状态机如下：

```
                    ┌─────────┐
                    │  idle   │ ← 空闲，等待用户输入
                    └────┬────┘
                         │ 用户发送消息
                         ▼
                    ┌─────────┐
                    │thinking │ ← 后端推理中（尚未输出文字）
                    └────┬────┘
                         │ 收到第一个 text token
                         ▼
                    ┌─────────┐
                    │ writing │ ← 流式输出中（拼接 currentText）
                    └────┬────┘
                         │ 收到 done 事件
                         ▼
                    ┌─────────┐
                    │  idle   │ ← 回复完成，消息存入历史
                    └─────────┘

          旁支状态：
            speaking → TTS 语音播放中（从 idle 进入，播放完回 idle）
            error    → 错误状态（立即回 idle，error 字段保留提示）
```

**关键设计：**
- `history` 不含当前用户消息（后端 `message` 字段单独拼接，避免重复）
- 流式 token 实时拼接为 `currentText`，UI 逐字显示
- `done` 事件后将完整回复转为 `Message` 实体追加到 `messages`
- 离线时消息进入 `offlineSaved` 状态，标记 `pendingSync: true`

### 4.3 SSE 流式对话（ChatService）

```
前端 POST /chat/v2                    后端 FastAPI
     │                                    │
     │  body: {                           │
     │    message: "你好",                │
     │    history: [...],                 │
     │    temperature: 0.8,               │
     │    max_tokens: 500                 │
     │  }                                  │
     │───────────────────────────────────▶│
     │                                    │ 1. 内容过滤（违规→blocked事件）
     │                                    │ 2. 下发 meta 事件（AI生成标识）
     │                                    │ 3. 拉取长期记忆→注入system prompt
     │                                    │ 4. 调用 Agnes 流式生成
     │  event: text                       │
     │  data: {"text":"你"}               │◀── 逐 token 推送
     │  event: text                       │
     │  data: {"text":"好"}               │◀──
     │  ...                               │
     │  event: emotion                    │
     │  data: {"emotion":"happy",...}     │◀── 情绪识别（基于用户输入）
     │  event: affinity                   │
     │  data: {"trust":30.5,...}          │◀── 好感度更新
     │  event: done                       │
     │  data: {}                           │◀── 流结束
     │◀───────────────────────────────────│
```

**SSE 解析实现要点：**
- Dio `responseType: ResponseType.stream` 接收字节流
- 按 `\n` 分行，`event:` 行存事件类型，`data:` 行攒数据
- 空行（`\n\n`）标记一条事件结束，触发分发
- 支持事件类型：`text` / `emotion` / `affinity` / `meta` / `blocked` / `done`

### 4.4 离线优先同步引擎（SyncEngine）

```
触发条件（任一）：
  1. 网络从无→有（Connectivity 监听）
  2. App 启动且当前有网
  3. 每 30 秒定时兜底

同步流程：
  ┌─────────────────────────────────────┐
  │  读取本地 outbox（待发消息队列）      │
  │  SELECT * FROM outbox WHERE synced=0 │
  └───────────────┬─────────────────────┘
                  │
                  ▼
  ┌─────────────────────────────────────┐
  │  逐条重发（指数退避 1s→2s→4s→30s）  │
  │  带上 client_msg_id 供后端去重        │
  │  用该消息之前的本地历史作为上下文       │
  └───────────────┬─────────────────────┘
                  │
           ┌──────┴──────┐
           │ 成功         │ 失败
           ▼              ▼
  ┌──────────────┐  ┌──────────────────┐
  │ AI回复落本地  │  │ attempts+1       │
  │ 标记已同步    │  │ 记录错误信息      │
  │ 触发UI刷新    │  │ 等退避后下次重试  │
  └──────────────┘  └──────────────────┘
```

### 4.5 请求签名鉴权（ClientAuth）

每个后端请求自动附加以下头（Dio 拦截器 `SigningInterceptor`）：

| 头 | 说明 |
|---|---|
| `X-Api-Key` | 与后端一致的 API Key（`--dart-define=ZHUYU_API_KEY` 注入） |
| `X-Timestamp` | Unix 秒级时间戳 |
| `X-Nonce` | UUID v4 一次性随机串 |
| `X-Signature` | HMAC-SHA256 签名 |
| `X-User-Id` | 设备唯一标识（按安装生成，持久化到 Hive） |

**签名算法：**
```
canonical = "METHOD\nPATH\nTIMESTAMP\nNONCE\nSHA256(BODY)"
signature = HMAC-SHA256(API_KEY, canonical).hexdigest()
```

### 4.6 Live2D 角色控制

`live2d_controller.dart`（19KB）是虚拟形象的核心控制器，负责：
- 模型加载与生命周期管理
- 表情切换（基于情绪识别结果）
- 动作触发（idle / tap / speak 等）
- 口型同步（lip_sync_service 驱动）
- 触摸交互（点击角色触发动作）

**模型资源：**
- `assets/live2d/ren/` — 简化版 Ren 模型
- `assets/live2d/ren_official/` — 官方完整版 Ren（腿真绑定）
- 均为 Live2D 官方免费示例（Cubism 3），合规使用

### 4.7 3D VRM 角色

- `vrm_avatar_view.dart` — 基于 `model_viewer_plus` 的 3D 渲染
- `assets/vrm_test/zhuyu_avatar.glb` — 程序化生成的竹笌 3D 少年人形（126KB，21网格，8材质，walk动画）
- `assets/vrm_test/CesiumMan.glb` — Khronos 测试人形（Apache-2.0）
- 本地补丁：`packages/model_viewer_plus`（修复 Android WebView VirtualDisplay 导致动画冻结问题，改用 Hybrid Composition）

---

## 五、后端核心机制详解

### 5.1 接口鉴权（auth.py）

全路由统一依赖 `auth.verify_request`，校验顺序：

1. **公开路径白名单**：`/` `/health` `/docs` `/redoc` `/openapi.json` `/legal/privacy` `/legal/terms` 免签名
2. **开发模式**：未配置 `ZHUYU_API_KEY` 时跳过签名（便于本地联调）
3. **头完整性**：检查 5 个鉴权头是否齐全
4. **API Key 校验**：`hmac.compare_digest` 防时序攻击
5. **时间戳容差**：默认 300 秒，超出则拒绝（防重放）
6. **Nonce 重放防护**：进程内记录已使用 nonce，过期自动清理
7. **HMAC 签名校验**：重新计算签名并比对

校验通过后，`X-User-Id` 注入到 `request.state.user_id`，供后续路由做多用户数据隔离。

### 5.2 流式对话处理（/chat/v2）

```
请求到达
  │
  ├─ 1. 内容前置过滤（content_moderation）
  │     命中高危词 → 下发 blocked 事件 + done，结束
  │
  ├─ 2. 下发 meta 事件（AI生成标识，暂行办法第九条）
  │     {ai_generated: true, service: "竹笌", notice: "本内容为人工智能生成"}
  │
  ├─ 3. 构建系统提示
  │     ├─ 角色设定（gentle/playful/wise 或前端传入）
  │     ├─ 指令遵循约束（背诗/算数/翻译等任务优先完成）
  │     └─ 长期记忆上下文（最近12条 + 今日摘要，让角色跨会话记得用户）
  │
  ├─ 4. 调用 Agnes 流式生成（has_agnes=true）
  │     异常时降级到 mock 兜底，保证 App 不中断
  │     逐 token 下发 text 事件
  │
  ├─ 5. 情绪识别（基于【用户输入】，非回复）
  │     下发 emotion 事件
  │
  ├─ 6. 持久化记忆（按 user_id 隔离）
  │     ├─ 用户消息 → category=user_memory
  │     └─ 竹笌回复 → category=chat_memory
  │
  ├─ 7. 更新好感度（bump_after_chat）
  │     下发 affinity 事件
  │
  └─ 8. 下发 done 事件，流结束
```

### 5.3 长期记忆系统（memory_store.py）

**存储设计：**
- 表 `memories`：`id / role / content(加密) / category / tags / importance / created_at / user_id`
- 多用户隔离：所有读写均按 `user_id` 过滤
- at-rest 加密：`content` 字段经 Fernet 加密存储

**搜索策略：**
- 因密文无法 SQL LIKE，改为拉取该用户全部记忆 → 内存解密 → 子串过滤
- 相关性打分：命中词数 × 1.0 + 重要性 × 0.5 + 时间加成（今日+2.0，昨日+1.0）
- 支持 `category` 可选过滤
- 个人数据量小，全表扫描可接受

**每日摘要：**
- 按天聚合用户消息，规则生成摘要（去唤醒词 + 拼接 + 截断120字）
- 返回 `date / count / user_count / summary / first_user`

### 5.4 好感度系统（affinity_store.py）

**数据结构（加密 JSON blob 存储）：**

| 字段 | 初始值 | 每轮对话增量 | 上限 |
|---|---|---|---|
| trust（信任） | 30.0 | +0.5 | 100.0 |
| intimacy（亲密） | 20.0 | +0.8 | 100.0 |
| familiarity（熟悉） | 5.0 | +0.3 | 100.0 |
| total_interactions | 0 | +1 | — |
| streak_days | 0 | 连续打卡+1，断签重置为1 | — |
| last_active_date | "" | 更新为今日 | — |

**关系等级（前端计算）：**
- ≥100 次：灵魂伴侣
- 61-99 次：亲密
- 31-60 次：朋友
- 11-30 次：熟人
- 0-10 次：陌生人

### 5.5 情绪识别引擎（emotion_engine.py）

14 维规则情绪，基于关键词命中打分：

| 维度 | 关键词示例 | 类型 |
|---|---|---|
| happy | 开心/高兴/哈哈/喜欢/爱/棒 | 强情感 |
| sad | 难过/伤心/哭/孤独/委屈 | 强情感 |
| angry | 生气/烦/讨厌/气死/滚 | 强情感 |
| fearful | 怕/害怕/担心/紧张 | 强情感 |
| guilt | 对不起/抱歉/内疚 | 强情感 |
| ashamed | 不好意思/害羞/尴尬 | 强情感 |
| disgust | 恶心/反感/呕 | 强情感 |
| frustration | 算了/无奈/烦死了 | 强情感 |
| attachment | 想你/离不开/陪我 | 强情感 |
| curious | 怎么/为什么/什么/吗/？ | 认知类 |
| surprised | 哇/天哪/居然/！ | 认知类 |
| proud | 厉害/牛/强/佩服 | 认知类 |
| trust | 相信/信任/靠谱 | 认知类 |
| awe | 震撼/敬畏/伟大 | 认知类 |

**打分规则：**
- 强情感基础分 0.5/命中，认知类 0.3/命中
- 并列时强情感优先（避免"吗？"等问句词反超真实情绪）
- 无命中返回 `neutral`，置信度 0.6

### 5.6 静态加密（encryption.py）

- 算法：Fernet（AES-128-CBC + HMAC-SHA256，来自 `cryptography` 库）
- 密钥优先级：环境变量 `ZHUYU_ENC_KEY` > 本地文件 `data/.enc_key` > 首次运行自动生成
- 密钥归一化：任意输入经 SHA256 派生 32 字节，再编码为 Fernet 格式（避免部署时格式问题）
- 解密失败：返回原文（兼容迁移期未加密旧数据，保证服务不崩溃）
- 应用范围：`memories.content` / `affinity.data` / `kv.value`

### 5.7 本地 TTS 微服务

- 引擎：IndexTTS 2.5（离线语音合成）
- 架构：主后端启动时自动拉起子进程（端口 8001），`/tts` 接口代理转发
- 自动拉起条件：8001 端口空闲 且 未设置 `ZHUYU_NO_TTS=1` 且 虚拟环境存在
- 降级：微服务未就绪时 `/tts` 返回 503，前端 `TtsService` 静默降级（文字照常显示，跳过朗读）
- 模型缓存：`HF_ENDPOINT=https://hf-mirror.com`（国内镜像加速）

---

## 六、API 接口文档

### 6.1 基础信息

- Base URL：`http://10.0.2.2:8000`（模拟器）/ 生产域名
- 鉴权：除公开路径外，所有请求需携带签名头（见 4.5）
- 响应格式：JSON（SSE 接口除外）

### 6.2 接口列表

#### 健康检查 & 服务信息

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| GET | `/health` | 否 | 健康检查，返回 `{"status":"ok"}` |
| GET | `/` | 否 | 服务信息：`service / status / agnes_enabled / persona / wake_word` |

#### 配置同步

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| POST | `/wake-word` | 是 | 同步唤醒词，body: `{"word":"竹笌竹笌"}` |
| POST | `/persona` | 是 | 切换角色，body: `{"persona":"gentle"\|"playful"\|"wise"}` |

#### 情绪识别

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| POST | `/emotion` | 是 | 情绪识别，body: `{"text":"..."}` → `{"emotion","confidence","scores"}` |

#### 流式对话

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| POST | `/chat/v2` | 是 | SSE 流式对话，见下方详情 |

**请求体：**
```json
{
  "message": "你好",
  "history": [{"role": "user", "content": "..."}],
  "system_prompt": "可选，自定义角色设定",
  "temperature": 0.8,
  "max_tokens": 500
}
```

**SSE 事件：**

| 事件 | data 字段 | 说明 |
|---|---|---|
| `meta` | `{ai_generated, service, notice}` | AI 生成内容标识 |
| `text` | `{text}` | 文字片段（逐 token） |
| `emotion` | `{emotion, confidence, scores}` | 情绪识别结果 |
| `affinity` | `{trust, intimacy, familiarity, total_interactions, streak_days}` | 好感度更新 |
| `blocked` | `{reason}` | 内容被违规过滤拦截 |
| `done` | `{}` | 流结束 |

#### 语音合成

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| POST | `/tts` | 是 | 语音合成，body: `{text, lang, emotion, speed}` → 返回 audio/wav |

#### 记忆系统

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| GET | `/memory/today` | 是 | 今日记忆列表 |
| GET | `/memory/search?q=&category=&limit=` | 是 | 搜索记忆，返回 `{count, results, memories}` |
| GET | `/memory/summaries` | 是 | 每日摘要列表 |
| POST | `/memory` | 是 | 存储一条记忆，body: `{role, content, category}` |
| PUT | `/memory/{id}` | 是 | 更正记忆内容（PIPL 更正权），body: `{content}` |
| POST | `/memory/clear` | 是 | 清空全部记忆 |
| DELETE | `/memory?category=` | 是 | 清空指定分类记忆 |

#### 好感度

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| GET | `/affinity` | 是 | 获取当前用户好感度 |

#### 实时语音

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| GET | `/livekit/connect?room=&user_id=` | 是 | 获取 LiveKit 连接信息，返回 `{available, livekit_url, token}` |

#### 法律文档

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| GET | `/legal/privacy` | 否 | 隐私政策（Markdown） |
| GET | `/legal/terms` | 否 | 用户协议（Markdown） |

#### 用户数据权利（PIPL）

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| GET | `/user/export` | 是 | 导出全部个人数据（访问/可携带权） |
| DELETE | `/user/data` | 是 | 删除全部个人数据（删除权） |

---

## 七、数据模型

### 7.1 前端实体

**Message（消息）**
```dart
class Message {
  final String id;           // 唯一ID（时间戳毫秒）
  final String role;         // 'user' | 'assistant'
  final String content;      // 消息内容
  final DateTime timestamp;  // 时间
  final String? emotion;     // 情绪标签（assistant 消息）
  final bool pendingSync;    // 是否待同步（离线消息）
}
```

**Emotion（情绪）**
```dart
class Emotion {
  final String emotion;      // 情绪标签：happy/sad/angry/.../neutral
  final double confidence;   // 置信度 0-1
  final Map<String, double> scores; // 14维分数
}
```

**Affinity（好感度）**
```dart
class Affinity {
  final double trust;        // 信任
  final double intimacy;     // 亲密
  final double familiarity;  // 熟悉
  final int totalInteractions; // 总交互次数
  final int streakDays;      // 连续打卡天数
}
```

### 7.2 后端数据库表

**memories（长期记忆）**

| 列 | 类型 | 说明 |
|---|---|---|
| id | INTEGER PK | 自增主键 |
| role | VARCHAR(32) | user / assistant |
| content | TEXT | 加密后的记忆内容 |
| category | VARCHAR(64) | user_memory / chat_memory / general |
| tags | TEXT | JSON 数组字符串 |
| importance | FLOAT | 重要性 0-1，默认 0.5 |
| created_at | VARCHAR(32) | ISO 时间戳 |
| user_id | VARCHAR(128) | 用户标识（多租户隔离） |

**affinity（好感度）**

| 列 | 类型 | 说明 |
|---|---|---|
| user_id | VARCHAR(128) PK | 用户标识 |
| data | TEXT | 加密 JSON blob（trust/intimacy/...） |

**kv（运行时键值）**

| 列 | 类型 | 说明 |
|---|---|---|
| key | VARCHAR(128) PK | 键名（persona / wake_word） |
| value | TEXT | 加密后的值 |

---

## 八、安全与合规

### 8.1 已实施的安全措施

| 措施 | 实现位置 | 说明 |
|---|---|---|
| 接口签名鉴权 | 前端 `client_auth.dart` / 后端 `auth.py` | HMAC-SHA256 + 时间戳 + nonce 防重放 |
| 多用户数据隔离 | 后端全部存储模块 | 按 `user_id` 过滤，互不混存 |
| 静态加密（at-rest） | 后端 `encryption.py` / 前端 `local_encryption.dart` | Fernet / AES-256-CBC 加密个人数据 |
| AI 内容标识 | 后端 `/chat/v2` meta 事件 | 暂行办法第九条，标注 AI 生成 |
| 违规内容过滤 | 后端 `content_moderation.py` | 用户输入高危词前置拦截（MVP） |
| 用户权利接口 | 后端 `/user/export` `/user/data` `PUT /memory/{id}` | PIPL 访问/删除/更正权 |
| 隐私政策 & 用户协议 | 后端 `/legal/*` + 前端 `LegalPage` | Markdown 模板，运营信息自动替换 |
| CORS 限制 | 后端 `main.py` | 生产需配置 `ALLOWED_ORIGINS`，不使用通配符 |
| 密钥管理 | 后端 `config.py` | API Key / 加密密钥通过环境变量注入，不硬编码（Agnes 除外，按用户要求写死） |

### 8.2 生产部署必做清单

1. 设置强随机 `ZHUYU_API_KEY`，前端构建用 `--dart-define=ZHUYU_API_KEY=<相同值>` 同步
2. 设置 `ALLOWED_ORIGINS` 为具体域名（不要用 `*`）
3. 设置 `ZHUYU_ENC_KEY`（base64 32字节 Fernet key），避免依赖本地自动生成密钥
4. 在 `legal/` 目录填写正式的《隐私政策》《用户协议》
5. 在 `.env` 设置 `OPERATOR_NAME`、`PRIVACY_CONTACT_EMAIL`、`SERVICE_CONTACT_EMAIL`
6. 完成算法备案与安全评估（向网信办）
7. 配置 HTTPS（Nginx 反代 + SSL 证书）
8. 数据库切换到 MySQL（`DATABASE_URL`），SQLite 仅用于开发

---

## 九、部署与运维

### 9.1 本地开发

**后端启动：**
```bash
cd F:\zhuyapp-backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env   # 编辑 .env
uvicorn main:app --host 0.0.0.0 --port 8000
```

**前端启动：**
```bash
cd F:\zhuyapp
flutter pub get
flutter run            # 连接模拟器/真机
```

**前端生产构建：**
```bash
flutter build apk --release \
  --dart-define=ZHUYU_API_BASE_URL=https://你的域名 \
  --dart-define=ZHUYU_API_KEY=你的密钥
```

### 9.2 生产部署（Docker + Nginx）

后端 `deploy/` 目录已备好完整方案：
- `Dockerfile` — 后端容器镜像
- `docker-compose.yml` — backend + nginx 两容器编排
- `nginx.conf` — 反向代理配置（80/443，后端不直连公网）
- `.env.production.example` — 生产环境变量模板
- `deploy.sh` — 一键部署脚本

三种部署形态：
1. **腾讯云 CVM + Docker（推荐）**：自管服务器，数据持久化在 volume
2. **腾讯云 CloudBase 云托管**：免管服务器，需配合 TencentDB for MySQL
3. **纯 systemd + venv**：轻量备选，gunicorn + uvicorn worker

### 9.3 环境变量

| 变量 | 说明 | 默认值 |
|---|---|---|
| `HOST` | 监听地址 | 0.0.0.0 |
| `PORT` | 监听端口 | 8000 |
| `DATABASE_URL` | 数据库连接 | sqlite:///data/zhuyu.db |
| `ZHUYU_API_KEY` | 接口鉴权密钥 | zhuyu-dev-key-change-me |
| `ZHUYU_ENC_KEY` | 数据加密密钥 | （自动生成到 data/.enc_key） |
| `ALLOWED_ORIGINS` | CORS 允许源（逗号分隔） | （本地方略） |
| `LIVEKIT_URL` | LiveKit 服务器地址 | （空=语音通话关闭） |
| `LIVEKIT_API_KEY` | LiveKit API Key | （空） |
| `LIVEKIT_API_SECRET` | LiveKit API Secret | （空） |
| `OPERATOR_NAME` | 运营主体名称 | 【请填写运营主体名称】 |
| `PRIVACY_CONTACT_EMAIL` | 隐私联系邮箱 | 【请填写隐私联系邮箱】 |
| `SERVICE_CONTACT_EMAIL` | 服务联系邮箱 | 【请填写服务联系邮箱】 |
| `ZHUYU_NO_TTS` | 设为 1 禁用本地 TTS 微服务 | （空=启用） |

---

## 十、开发指南

### 10.1 新增 API 接口

1. 后端 `main.py` 添加路由函数，使用 `@app.get/post/put/delete` 装饰器
2. 路由内通过 `request.state.user_id` 获取用户标识（多租户隔离）
3. 前端 `backend_service.dart` 添加对应方法，使用 `_dio` 发起请求（签名拦截器自动附加）
4. 前端 `chat_provider.dart` 或对应 Provider 中调用 BackendService 方法

### 10.2 新增页面

1. 在 `lib/pages/` 下创建页面目录和 Widget
2. 在 `lib/core/router/app_router.dart` 的 `routes` 列表添加 `GoRoute`
3. 如需状态管理，在 `lib/presentation/providers/` 添加对应 Provider

### 10.3 新增 TTS 引擎

1. 在 `lib/core/services/` 创建 `xxx_tts_service.dart`
2. 实现统一的 `Future<Uint8List?> synthesize(String text, {String? emotion})` 接口
3. 在 `tts_service.dart` 的调度逻辑中添加引擎选择与降级链

### 10.4 代码规范

- 前端：Dart 官方规范 + `flutter_lints` 规则集，`analysis_options.yaml` 已配置
- 后端：PEP 8，类型注解，模块级文档字符串
- 注释：核心模块均有中文文档注释（设计思路、架构决策、坑点记录）

---

## 附录 A：Git 仓库信息

- 主仓库：`https://github.com/missgl520/zhuyapp`（origin）
- 开发分支：`https://github.com/missgl520/idiot-dog.git`（idiotdog remote）
- 本地分支：`main` / `zhuyu-frontend-backup` / `zhuyu-local-backup`
- 最近提交：
  - `93cef4e` feat: 聊天页顶栏新增3D角色入口 → 独立全屏二级页
  - `699c548` feat: 聊天页 Live2D 全屏背景 + 气泡聊天 + 情绪展示
  - `1b21deb` feat(ui): 立体竹笋小人图标、菜单头像同步

## 附录 B：F 盘相关目录

| 目录 | 说明 |
|---|---|
| `F:\zhuyapp` | 主项目（Flutter 前端） |
| `F:\zhuyapp-backend` | 后端服务（Python FastAPI） |
| `F:\zhuyu-frontend` | 前端备份（2026-08-25） |
| `F:\zhuyu-report` | 代码核查与合规报告 |
| `F:\zhuyu_backup` | 项目备份 |
| `F:\flutter` | Flutter SDK |

---

*本文档基于 2026-08-27 的代码库实际状态生成，所有架构描述、接口定义、数据模型均回链到实际源码。*

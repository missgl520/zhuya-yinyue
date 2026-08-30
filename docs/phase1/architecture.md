# 竹笌 × 音乐狗子 合并重设计 · 技术架构文档

| 项 | 值 |
|---|---|
| 文档版本 | v1.0 |
| 编制 | 首席架构师（高见远） |
| 状态 | 待项目总监裁决 |
| 基底 | `F:/zhuyapp` @ `main`（HEAD `1d23c26`） |
| 新增模块来源 | `F:/zhuyapp` @ `zhuyu-frontend-backup` 的 `frontend/lib/modules/pet/` |
| 后端基底 | `F:/zhuyapp-backend`（FastAPI，全局签名鉴权） |
| 后端归档来源 | `F:/zhuyapp` @ `zhuyu-frontend-backup` 的 `backend/` |
| 调研方式 | 全部结论基于实读源码 / 实测命令 / 实测网络请求，无一条来自推测 |

---

## 0. 调研证据台账

本节列出所有结论的取证来源，供审阅方逐条复核。凡本文档下文出现的判断，均可回溯到此处。

| 编号 | 证据 | 取证方式 | 关键读数 |
|---|---|---|---|
| E-01 | 竹笌前端目录为平铺 `lib/`，非 `frontend/lib/` | `find lib -type d` | 28 个目录，47 个 `.dart` 文件，`lib/` 净体积 466 KB |
| E-02 | 竹笌路由为 go_router 声明式，共 10 条 | 读 `lib/core/router/app_router.dart`（120 行） | `/`、`/chat`、`/voice-call`、`/memory-history`、`/legal`、`/info`、`/avatar`、`/home`、`/discover`、`/profile` |
| E-03 | 竹笌状态管理为 Riverpod + ProviderScope | 读 `lib/main.dart`、`presentation/providers/` | `routerProvider` / `themeProvider`，`ProviderScope` 根挂载 |
| E-04 | 竹笌 3D 走 model_viewer_plus 且已本地补丁 | 读 `pubspec.yaml` 末尾 `dependency_overrides` | `packages/model_viewer_plus`，补丁项 `displayWithHybridComposition: true` |
| E-05 | 竹笌另有 Live2D 渲染栈（vendored） | 读 `pubspec.yaml`、`lib/widgets/live2d_*.dart` | `vendor/flutter_live2d` 47 MB，`live2d_controller.dart` 19.4 KB |
| E-06 | 音乐狗子的宠物形象是纯 2D 矢量，不含任何 3D | `grep` `chatty_dog_pet.dart` | `class DogPainter extends CustomPainter`，7 个 `_draw*` 私有方法，零 3D 依赖 |
| E-07 | 音乐狗子调后端用 `package:http` 裸调，绕过签名 | 读 `frontend/lib/services/pet_api_service.dart` | `http.Client()`，仅 `Content-Type` 头，无 `X-Api-Key`/`X-Signature` |
| E-08 | 竹笌后端全路由强制签名鉴权 | 读 `main.py:44-49`、`auth.py` | `FastAPI(dependencies=[Depends(auth.verify_request)])`，canonical = `METHOD\nPATH\nTS\nNONCE\nSHA256(BODY)` |
| E-09 | 竹笌后端现有 22 个端点 | `grep -nE "^@app\." main.py` | 含 `/chat/v2`（SSE 流式）、`/emotion`、`/memory/*`（7 个）、`/affinity`、`/tts`、`/livekit/connect`、`/user/export` 等 |
| E-10 | 音乐生成不是本地模型，是第三方 HTTP API | 读 `backend/pet_api.py:441-443` | `ACE_BASE_URL = "https://api.acemusic.ai/v1/chat/completions"`，密钥硬编码在源码默认值 |
| E-11 | 该第三方密钥当前仍然有效，任何人可调用 | 实测 `curl` 携带该硬编码密钥 | `HTTP 200`，返回真实 MP3 |
| E-12 | 音乐生成实测延迟 48.2 秒，响应 641 KB | 实测 `curl -w` 生成 30 秒中文歌 | `HTTP:200 size:641473 time:48.226823s` |
| E-13 | 返回的不是可播 URL，是 base64 data URI | 解析实测响应 JSON | `audio_url.url` 以 `data:audio/mpeg;base64,` 开头，641,107 字符，解码后约 0.46 MB |
| E-14 | 前端却用 `UrlSource` 直接播它 | 读 `pet_studio_page.dart:707` | `_player.play(UrlSource(widget.url))` |
| E-15 | 竹笌 TTS 微服务实测未就绪 | `ls` + 探测 venv | `index-tts/.venv` 内 `torch`/`fastapi`/`indextts` 全部 MISSING；`checkpoints/` 仅 12 KB（只有 `pinyin.vocab`） |
| E-16 | 该 venv 同步中断在 torch 下载 | 读 `tts_service/uv_sync.log` 末尾 | 最后一行 `Downloading torch (3.2GiB)` |
| E-17 | 音乐狗子那套 MOSS-TTS 权重是 LFS 指针，不是真权重 | `git show` blob 内容 + `od -c` | `moss_tts_prefill.onnx` 内容为 `version https://git-lfs.github.com/spec/v1` |
| E-18 | 备份分支 `backend/` 携带 957 MB 二进制 blob | `git ls-tree -r -l` 汇总 | 合计 956.99 MB，其中 `qwen2.5-0.5b-local/model.safetensors` 单文件 942.32 MB（真实 blob，非指针） |
| E-19 | 仓库 `.git` 已膨胀至 1.6 GB | `du -sh .git` | 1.6 GB（`lib/` 只占 466 KB） |
| E-20 | 待移植文件全部超长，违反单文件 300 行约束 | `wc -l` via `git show` | `chatty_dog_pet.dart` 1097 行、`pet_studio_page.dart` 1088 行、备份 `main.dart` 1193 行 |
| E-21 | 待移植代码含 emoji 字面量与硬编码色值 | Python 正则统计 | `pet_studio_page` 8 处 emoji / 2 处 `Color(0x`；`chatty_dog_pet` 8 / 26；备份 `main.dart` 44 / 26 |
| E-22 | 竹笌自身也有 emoji 与图标字体存量债 | 同上，扫 `lib/` | 7 个文件含 emoji（最多的 `domain/entities/emotion.dart` 11 处）；`Icons.*` 共 61 处 |
| E-23 | 竹笌已有集中设计令牌，可直接承载新模块 | 读 `lib/core/theme/app_theme.dart` | `bamboo`/`bambooDeep`/`warmYellow`/`paper`/`softText`/`subText` + 圆角与间距阶梯，注释明确「杜绝硬编码」 |
| E-24 | 竹笌后端持久化已抽象为 SQLAlchemy Core，可 SQLite/MySQL 切换 | 读 `db.py` | 表 `memories`/`affinity`/`kv`；`content` 与 `affinity.data` 走 `encryption.encrypt` |
| E-25 | 音乐狗子歌词库却是独立 `sqlite3` 直连 | 读 `backend/lyrics_store.py` | `DB_PATH = lyrics_store.db`，裸 `sqlite3.connect`，与 `db.py` 完全平行 |
| E-26 | 后端存在第二处硬编码密钥 | 读 `config.py:20` | `AGNES_API_KEY` 明文写死于源码，注释自述「按用户要求硬编码写死，不走 .env」 |
| E-27 | 宠物状态是进程内内存字典 | 读 `pet_api.py:_sessions` | `_sessions: dict[str, dict] = {}`，重启即丢 |
| E-28 | 宠物状态 API 把 user_id 放在 URL 路径 | 读 `pet_api.py` | `@app.get("/pet/state/{user_id}")`，任意人可读任意用户 |
| E-29 | 磁盘余量与 C 盘禁装约束可满足 | `df -h /c /f` | C 盘可用 74 GB（受禁装约束）；F 盘可用 790 GB |
| E-30 | 竹笌已有 HF 缓存重定向到 F 盘的先例 | 读 `tts_service/app.py`、`main.py:_start_tts_service` | `HF_HOME`、`MODELSCOPE_CACHE` 均显式指向 F 盘目录 |

> 说明：本专家包内 `references/architecture/mvp-stack.md`、`references/01-standards/code-organization.md` 等知识库文件在本机未找到（`find ~/.workbuddy -name ...` 返回空）。因此本文档的选型基线改由「实读现有代码 + pub.dev / 实测网络验证」建立，并在每条选型下标注取证来源，不引用无法核验的内部基线。

---

## 1. 版本锚定（全部实测，非声明值）

### 1.1 前端工具链

| 组件 | 实测版本 | 取证命令 |
|---|---|---|
| Flutter | **3.47.1**（stable，revision `6655482ec0`，2026-08-19） | `flutter --version` |
| Dart SDK | **3.13.1**（stable，2026-08-18） | `dart --version` |
| Flutter Engine | `11d79658c444477b06513d32b52c8c4ccb7276b0`（rev `5d53178869`） | `flutter --version` |
| DevTools | 2.60.0 | `flutter --version` |
| `pubspec.yaml` SDK 约束 | `sdk: ^3.12.2` | 读 `pubspec.yaml` |

约束校验：`^3.12.2` 解析为 `>=3.12.2 <4.0.0`，实测 3.13.1 落在区间内，**无需改动 SDK 约束**。

### 1.2 前端依赖（取自 `pubspec.lock`，为已解析的确切版本）

| 包 | 锁定版本 | 在合并后的角色 |
|---|---|---|
| `flutter_riverpod` | 2.6.1 | 状态管理，全项目唯一方案 |
| `go_router` | 14.8.1 | 路由，全项目唯一方案 |
| `model_viewer_plus` | 1.10.0（被 `dependency_overrides` 指向 `packages/model_viewer_plus` 本地补丁） | 3D 角色容器，仅 `/avatar` 使用 |
| `just_audio` | 0.9.46 | **唯一音频播放器**（见选型 D） |
| `flutter_tts` | 4.2.5 | 系统 TTS 兜底 |
| `speech_to_text` | 7.4.0 | ASR |
| `livekit_client` | 2.11.0 | 实时语音通话 |
| `dio` | 5.11.0 | **唯一后端 HTTP 通道**（携带 `SigningInterceptor`） |
| `http` | 1.6.0 | 存量依赖，新代码禁止用于访问竹笌后端 |
| `sqflite` | 2.4.3 | 本地会话 / 记忆 |
| `hive` | 2.2.3 | 设置项 KV |
| `crypto` | 3.0.7 | 请求签名 HMAC-SHA256 |
| `uuid` | 4.6.0 | 本地 ID |
| `path` | 1.9.1 | 路径拼接 |
| `flutter_lints` | 6.0.0 | 静态分析 |
| `flutter_live2d` | path: `./vendor/flutter_live2d` | Live2D 渲染，仅 `/chat` 使用 |
| `audioplayers` | **未安装**（仅存在于音乐狗子那侧的 `pubspec.yaml`） | **不引入**（见选型 D） |
| `flutter_animate` | **未安装**（同上） | **不引入**（见选型 F） |

### 1.3 后端运行时（探测 `F:/zhuyapp-backend/venv`）

| 组件 | 实测版本 |
|---|---|
| Python（主后端 venv） | **3.13.14** |
| FastAPI | **0.141.1** |
| Uvicorn | **0.52.1** |
| Pydantic | **2.13.4** |
| httpx | **0.28.1** |
| SQLAlchemy | **2.0.51** |
| PyMySQL | **1.2.0** |
| cryptography | **50.0.0** |
| Python（TTS 微服务 venv `tts_service/index-tts/.venv`） | 3.11.13，但 `torch`/`fastapi`/`indextts` 均 MISSING（E-15） |

> `requirements.txt` 只写了下界（`fastapi>=0.110`）。**本次合并要求收紧为区间锁定**，见 4.6。

---

## 2. 现状事实台账

### 2.1 竹笌前端结构（平铺 `lib/`，47 文件）

```
lib/
├── main.dart                     入口：Hive 初始化 → BackendConfig → SyncEngine → ProviderScope
├── core/
│   ├── auth/client_auth.dart     请求签名 + Dio SigningInterceptor
│   ├── router/app_router.dart    go_router，10 条路由
│   ├── security/local_encryption.dart
│   ├── services/                 agnes / asr / backend / cartesia_tts / lip_sync / livekit / memory / mini_max_tts / tts
│   ├── sync/sync_engine.dart     离线优先补发
│   ├── theme/app_theme.dart      设计令牌（色 / 圆角 / 间距 / 字阶）
│   └── config.dart
├── data/{datasources,repositories,services}
├── domain/{entities,repositories}
├── pages/{splash,chat,discover,profile,settings,voice,avatar,legal,home(空)}
├── presentation/providers/{app_providers,chat_provider}
├── providers/app_providers_legacy.dart      遗留，待收敛
└── widgets/                      chat_bubble / live2d_widget / live2d_controller / voice_button / vrm_avatar_view / dashed_container / image_picker_button
```

已存在的结构性债务（不在本次范围内解决，但需登记）：`presentation/providers/` 与 `providers/` 双 Provider 目录并存；`pages/chat/chat_page.dart` 42.6 KB 单文件过重；`pages/home/` 空目录但 `/home` 路由复用 `ChatPage`。

### 2.2 竹笌后端能力盘点（`main.py` 22 个端点）

| 能力 | 端点 | 实现要点 |
|---|---|---|
| 流式对话 | `POST /chat/v2` | SSE `StreamingResponse`，接 Agnes（`api.agnes-ai.cn`），入参 `message`/`history`/`system_prompt`/`temperature`/`max_tokens`，`user_id` 由签名中间件注入 |
| 情绪识别 | `POST /emotion` | `emotion_engine.detect_emotion(text)` |
| 长期记忆 | `GET /memory/today`、`GET /memory/search`、`GET /memory/summaries`、`POST /memory`、`PUT /memory/{id}`、`POST /memory/clear`、`DELETE /memory` | 落 `memories` 表，`content` 字段级加密 |
| 好感度 | `GET /affinity` | 落 `affinity` 表，整行加密 JSON；维度 `trust`/`intimacy`/`familiarity`/`total_interactions`/`streak_days` |
| 人格 / 唤醒词 | `POST /persona`、`POST /wake-word` | 落 `kv` 表，值加密 |
| 语音合成 | `POST /tts` | httpx 反代 `127.0.0.1:8001`（IndexTTS 2.5 微服务），返回 `audio/wav` 二进制；微服务不可用返回 503 |
| 实时通话 | `GET /livekit/connect` | 签发 LiveKit token，未配置则 `available:false` |
| 合规 | `GET /legal/privacy`、`GET /legal/terms`、`GET /user/export`、`DELETE /user/data`、`content_moderation.py` | 隐私政策 / 协议 / 数据导出 / 数据删除 / 内容过滤 |
| 健康 | `GET /`、`GET /health` | 免签白名单 |

### 2.3 音乐狗子（竹芽）侧盘点

前端 6 个源文件，其中真正要移植的只有 3 个：

| 文件 | 行数 | 处置 |
|---|---|---|
| `modules/pet/chatty_dog_pet.dart` | 1097 | **移植并拆分**（矢量狗子渲染 + 语料库 + 交互） |
| `modules/pet/pet_studio_page.dart` | 1088 | **移植并拆分**（创作工坊：对话 / 歌词预览 / 播放器 / 歌词库） |
| `services/pet_api_service.dart` | — | **重写**（改走 Dio + 签名，见 4.1.3） |
| `services/tts_service.dart` | — | **丢弃**（竹笌已有 `core/services/tts_service.dart`，且契约不同，见 4.4） |
| `main.dart` | 1193 | **整份丢弃**（竹笌已有 splash / home / discover / profile + go_router，重复实现一套 `BottomNavigation` 是倒退） |
| `data/local_chat_repository.dart`、`data/message.dart` | 198 / 75 | **丢弃**（竹笌已有 `data/datasources/chat_local_data_source.dart` + `domain/entities/message.dart`） |

后端 `backend/pet_api.py`（859 行，单文件承载全部能力）关键事实：

- 音乐生成：**不是本地模型**，是 `POST https://api.acemusic.ai/v1/chat/completions`，密钥硬编码（E-10、E-11）。
- 歌词生成：走多 provider LLM（groq / cerebras / gemini / ace / local Qwen2.5-0.5B），带 failover；本地 provider 需 942 MB 权重。
- 宠物状态：进程内字典（E-27），端点把 `user_id` 放路径（E-28）。
- 歌词库：独立 `sqlite3`，与竹笌 `db.py` 双轨（E-25）。
- TTS：MOSS-TTS-Nano ONNX，但权重是 LFS 指针（E-17），当前不可运行。
- `/llm/status` 端点会把各 provider 的 `has_key` 与模型名对外暴露。

### 2.4 两侧能力差异矩阵

| 能力 | 竹笌（`zhuyapp-backend`） | 音乐狗子（备份 `backend/`） | 合并后取舍 |
|---|---|---|---|
| 对话 | `/chat/v2` SSE 流式，Agnes | `/chat` 非流式，多 provider | 取竹笌 SSE，把「意图解析」能力并入 |
| 鉴权 | 全局 HMAC 签名 + nonce 防重放 | 无 | 取竹笌，音乐端点一并纳管 |
| 持久化 | SQLAlchemy Core，SQLite/MySQL 双兼容 + 字段加密 | 裸 `sqlite3` + 内存字典 | 取竹笌 |
| TTS | IndexTTS 2.5 微服务，返回 wav 二进制 | MOSS-TTS ONNX，返回 JSON + URL | 取竹笌契约（见 4.4） |
| 情绪 / 记忆 / 好感度 | 有，已落库加密 | 无（只有 `love` 浮点） | 取竹笌，宠物只补专属字段 |
| 歌词创作 | 无 | 有（5 种风格模板 + 结构化 prompt） | **净新增，全量移植** |
| 音乐生成 | 无 | 有（第三方 API） | **净新增，改造后接入** |
| 合规 | 隐私 / 协议 / 导出 / 删除 / 内容过滤 | 无 | 取竹笌，音乐产物纳入过滤与导出 |

---

## 3. 目标架构

### 3.1 分层视图

```
┌─────────────────────────────────────────────────────────────────────┐
│ 表现层  lib/pages/**            go_router 声明式路由（唯一入口）      │
│         lib/widgets/**          无状态展示组件 + AppIcon 图标门面     │
│         设计约束：色/圆角/间距一律取 AppTheme 令牌；图标一律 AppIcon   │
├─────────────────────────────────────────────────────────────────────┤
│ 状态层  lib/presentation/providers/**   Riverpod Notifier / Provider  │
│         规则：页面不持有业务状态，只 ref.watch                        │
├─────────────────────────────────────────────────────────────────────┤
│ 领域层  lib/domain/entities/**          纯 Dart 实体，零 Flutter 导入 │
│         lib/domain/repositories/**      抽象接口                     │
├─────────────────────────────────────────────────────────────────────┤
│ 数据层  lib/data/services/**            远程：Dio + SigningInterceptor│
│         lib/data/datasources/**         本地：sqflite / Hive          │
│         lib/data/repositories/**        实现层，负责在线/离线合流      │
├─────────────────────────────────────────────────────────────────────┤
│ 基础层  lib/core/{auth,router,security,services,sync,theme}          │
└─────────────────────────────────────────────────────────────────────┘
                                  │  HTTPS + HMAC-SHA256 签名
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ FastAPI 0.141.1  main.py（仅装配：app / 中间件 / include_router）     │
│   ├── routers/chat.py      /chat/v2  SSE + 意图解析                  │
│   ├── routers/memory.py    /memory/*                                 │
│   ├── routers/affinity.py  /affinity                                 │
│   ├── routers/tts.py       /tts  反代 127.0.0.1:8001                 │
│   ├── routers/pet.py       /pet/state  /pet/interact      【新增】    │
│   ├── routers/lyrics.py    /lyrics  /lyrics/{id}          【新增】    │
│   ├── routers/music.py     /music/generate  /music/jobs/* 【新增】    │
│   └── routers/legal.py     /legal/*  /user/*                         │
│   服务层：agnes_client / emotion_engine / memory_store /              │
│           affinity_store / content_moderation / encryption /          │
│           music_provider.py【新增】/ lyrics_composer.py【新增】/      │
│           job_queue.py【新增】                                        │
│   持久化：db.py（SQLAlchemy Core，SQLite 开发 / MySQL 生产）          │
└─────────────────────────────────────────────────────────────────────┘
        │                         │                        │
        ▼                         ▼                        ▼
  Agnes LLM API           ACE Music API            IndexTTS 微服务
  （对话/歌词）           （音乐生成 48s）          （127.0.0.1:8001）
```

### 3.2 音乐生成数据流（异步任务模式，为 E-12/E-13 而设计）

```
App                          后端                         ACE Music
 │                            │                                │
 │ POST /music/generate       │                                │
 │  {lyric_id | lyrics,       │                                │
 │   prompt, duration}        │                                │
 ├───────────────────────────>│  1. 内容过滤(content_moderation)│
 │                            │  2. 写 music_jobs(status=queued)│
 │  202 {job_id, poll_after}  │  3. BackgroundTasks 派发        │
 │<───────────────────────────┤                                │
 │                            │  POST /v1/chat/completions      │
 │                            ├───────────────────────────────>│
 │ GET /music/jobs/{job_id}   │                                │  实测 48.2s
 │  （每 3s 轮询，退避到 8s） │                                │
 ├───────────────────────────>│                                │
 │  200 {status:"running",    │                                │
 │       progress:0.4}        │                                │
 │<───────────────────────────┤   200 + data:audio/mpeg;base64  │
 │                            │<───────────────────────────────┤
 │                            │  4. 解 base64 → 落盘 F 盘        │
 │                            │     data/audio/<sha1>.mp3       │
 │                            │  5. 写 songs 表 + job=succeeded │
 │  200 {status:"succeeded",  │                                │
 │       song:{audio_url:     │                                │
 │       "/music/audio/x.mp3"}│                                │
 │<───────────────────────────┤                                │
 │ just_audio.setUrl(...)     │                                │
```

三个必须如此的理由，各有实测支撑：

1. **不能同步等**：实测 48.2 秒（E-12）。移动端 HTTP 栈与用户耐心都撑不住，且音乐狗子原前端用 `package:http` 无超时设置，会挂死到系统级超时。
2. **不能直接回传 data URI**：实测返回体 641 KB 的 JSON 里塞 base64（E-13），而前端用 `UrlSource` 播（E-14）。`data:` scheme 在 Android MediaPlayer / iOS AVPlayer 上不是可靠可播源。后端解码落盘、回传常规 HTTP URL 是唯一稳妥路径。
3. **不能让前端直连第三方**：直连意味着把密钥打进 APK，且绕过 `content_moderation`（AIGC 内容合规不可省）。

---

## 4. 技术可行性结论

### 4.1 前端：把音乐狗子模块 port 进平铺 `lib/`

**结论：可行。** 无框架级冲突，宠物形象是纯 `CustomPainter`（E-06），不引入第二套渲染引擎。工作量集中在「拆文件 + 换状态管理 + 换 HTTP 通道 + 清 P0 违规」四件事，无技术风险，只有工时风险。

#### 4.1.1 文件落位表（源 → 目标，含拆分）

`chatty_dog_pet.dart`（1097 行）拆为 6 个文件：

| 目标文件 | 内容 | 预估行数 | 来源行段 |
|---|---|---|---|
| `lib/domain/entities/pet_state.dart` | `PetMood`/`PetAction` 枚举 + `PetState` 值对象 | ~70 | 原 15-48 |
| `lib/data/datasources/dog_bark_library.dart` | `DogBarkLibrary` 语料常量与随机取词 | ~150 | 原 52-170 |
| `lib/widgets/pet/dog_painter.dart` | `DogPainter`（`CustomPainter`，7 个 `_draw*`） | ~280 | 原 173-590 |
| `lib/widgets/pet/pet_speech_bubble.dart` | `SpeechBubble` | ~60 | 原 592-642 |
| `lib/widgets/pet/pet_love_meter.dart` | `LoveMeterBar` + `PetActionButton` | ~120 | 原 644-752 |
| `lib/widgets/pet/chatty_dog_pet.dart` | `ChattyDogPet` 组合体（改为 `ConsumerWidget`） | ~200 | 原 753-1053 |
| （丢弃） | `ChattyDogDemo` 演示壳 | — | 原 1054-1097 |

`pet_studio_page.dart`（1088 行）拆为 8 个文件：

| 目标文件 | 内容 | 预估行数 |
|---|---|---|
| `lib/pages/pet/pet_studio_page.dart` | 页面骨架 + Scaffold 装配（**只装配，不含业务**） | ~110 |
| `lib/widgets/pet/pet_status_bar.dart` | `_PetStatusBar` | ~80 |
| `lib/pages/pet/widgets/creation_studio.dart` | `_CreationStudio` 对话与创作主区 | ~250 |
| `lib/pages/pet/widgets/lyrics_preview.dart` | `_LyricsPreview` | ~110 |
| `lib/widgets/pet/song_player.dart` | 播放器（**重写为 just_audio**） | ~150 |
| `lib/widgets/pet/pet_chat_bubble.dart` | `_ChatBubble` + `_TypingIndicator` + `_DotBounce` | ~140 |
| `lib/pages/pet/widgets/lyrics_library_view.dart` | `_LyricsLibrary` | ~130 |
| `lib/pages/pet/pet_fullscreen_page.dart` | `_PetAloneScreen` + `_EmptyStudio` | ~110 |

新增（无对应源文件）：

| 文件 | 职责 |
|---|---|
| `lib/domain/entities/lyrics.dart` | `Lyrics` 实体 |
| `lib/domain/entities/song.dart` | `Song` 实体（含 `audioUrl`/`durationSec`/`jobId`） |
| `lib/domain/entities/music_job.dart` | `MusicJob` + `MusicJobStatus` 枚举 |
| `lib/domain/repositories/music_repository.dart` | 抽象接口 |
| `lib/data/services/pet_api_service.dart` | 远程数据源，**Dio 实现** |
| `lib/data/repositories/music_repository_impl.dart` | 在线/离线合流 + 轮询编排 |
| `lib/presentation/providers/pet_provider.dart` | 宠物状态 Notifier |
| `lib/presentation/providers/music_provider.dart` | 创作流程 Notifier（含 job 轮询） |
| `lib/widgets/app_icon.dart` | **图标唯一门面**（见选型 A） |

#### 4.1.2 路由改动（`lib/core/router/app_router.dart`）

新增 3 条，沿用文件内既有的 `CustomTransitionPage` 风格：

```dart
GoRoute(path: '/pet',          name: 'pet',          builder: (c, s) => const PetStudioPage()),
GoRoute(path: '/pet/full',     name: 'pet-full',     builder: (c, s) => const PetFullscreenPage()),
GoRoute(path: '/pet/library',  name: 'pet-library',  builder: (c, s) => const LyricsLibraryPage()),
```

入口挂载点：`/discover`（竹林一角）与 `/profile` 各加一个入口卡片，均取 `AppTheme` 令牌配色。**不新增 BottomNavigation**——竹笌已有 `/home` `/discover` `/profile` 三段式，备份分支那套自制导航整份丢弃。

#### 4.1.3 状态管理与 HTTP 通道改造（两处硬性改动）

**改动一：`setState` → Riverpod。** 音乐狗子侧 `_ChattyDogPetState` 里的 `_barkTimer`（`Timer.periodic(8s)`）与 10 处 `setState` 必须迁到 `PetNotifier`。理由：定时吠叫是跨页面存活的业务状态，留在 `State` 里会随页面销毁而断，且无法与 `/chat` 页共享宠物情绪。

**改动二：`package:http` → `Dio`。** 这是**上线阻断级**改动。证据链：后端 `FastAPI(dependencies=[Depends(auth.verify_request)])` 全局强制签名（E-08），而 `PetApiService` 用裸 `http.Client()` 只带 `Content-Type`（E-07）。生产环境（`ZHUYU_API_KEY` 非空）下所有音乐端点直接 401。改造方式：复用 `lib/core/auth/client_auth.dart` 里已有的 `SigningInterceptor`，`PetApiService` 构造时注入与 `BackendService` 同源的 Dio 实例，`baseUrl` 取 `BackendConfig.instance.baseUrl`。

同时废弃音乐狗子那套 `PET_API_URL` 编译期常量（`String.fromEnvironment('PET_API_URL', default:'http://localhost:8000')`）——竹笌已有 `BackendConfig` + Hive 持久化 + 设置页可改，两套地址源并存必然产生「聊天能通、音乐不通」的诡异故障。

#### 4.1.4 P0 违规清理清单（移植时必须一次做完）

| 违规 | 位置与数量（E-21、E-22） | 处置 |
|---|---|---|
| emoji 作功能图标 | `pet_studio_page` 8 处、`chatty_dog_pet` 8 处、备份 `main.dart` 44 处（整份丢弃）；`pet_api_service.dart` 内 `moodEmojis` 常量映射表 | 全部替换为 `AppIcon`；`moodEmojis` 常量整个删除，改为 `moodIcon` 映射到 SVG 资产名 |
| emoji 存量债（竹笌自身） | 7 个文件，`emotion.dart` 11 处、`info_modules_page` 8、`settings_sheet` 8、`memory_history_page` 3、`menu_panel` 3、`voice_call_page` 2、`profile_page` 1 | 与本次改造同批清理（合计 36 处），否则新旧混用比原状更糟 |
| 硬编码色值 | `chatty_dog_pet` 26 处、`pet_studio_page` 2 处 `Color(0x...)`；播放器内 `Colors.orange`、`Colors.grey.shade200/600` | 全部映射到 `AppTheme` 令牌；狗子毛色等模块专属色作为 `AppTheme` 新增语义令牌（如 `petFur`/`petFurShadow`）集中声明，不散落 |
| 图标字体 | 竹笌 `Icons.*` 61 处 + 移植代码 21 处（`pet_studio_page` 14、`chatty_dog_pet` 7） | 统一走 `AppIcon`（见选型 A），`analysis_options.yaml` 加禁用规则 |
| 紫粉渐变 | 扫描结果：两侧代码均未发现紫→粉渐变 | 无需整改，作为禁令写入设计规范并加 CI 检查 |

### 4.2 后端：音乐生成如何接入 `F:/zhuyapp-backend`

**结论：新增端点，不复用现有端点。模型无需部署——因为它本来就不是本地模型。**

这里必须纠正任务书里的一个前提假设。任务书问「如何部署模型」，但实测证据表明（E-10、E-11、E-12、E-13）：音乐狗子的音乐生成是**调用第三方云 API**（ACE Music），备份分支 `backend/` 里根本没有音乐模型权重。那 957 MB 二进制（E-18）是 **Qwen2.5-0.5B 语言模型**（用于离线生成*歌词*）和 **MOSS-TTS**（语音合成，且权重还是 LFS 指针，E-17），二者都不是音乐生成模型。

因此「音乐生成模型体积 / 算力」这条风险的正确形态是：**没有本地音乐模型，风险从算力转移到了第三方依赖与密钥泄露**。详见 7.1 R-01、R-02、R-08。

#### 4.2.1 三项后端结构性改造

**改造一：`main.py` 拆 router。** 现状 22 433 字节 / 600+ 行单文件承载 22 个端点。再加 8 个音乐端点必然失控。按资源分包为 `routers/{chat,memory,affinity,tts,pet,lyrics,music,legal}.py`，`main.py` 收缩为纯装配（app 构造 + 中间件 + `include_router` + startup hook），目标 120 行以内。

**改造二：歌词库并入 `db.py`。** 音乐狗子的 `lyrics_store.py` 用裸 `sqlite3` 直连本地文件（E-25）。竹笌生产环境把 `DATABASE_URL` 指向 MySQL 时，这套 sqlite 会静默写到容器本地磁盘、重启即失——**是数据丢失级缺陷**。改造为 `db.py` 中的 SQLAlchemy Table 声明，复用其 SQLite/MySQL 双兼容与 `pool_pre_ping` 重连逻辑。

**改造三：宠物状态落库。** `_sessions` 内存字典（E-27）改为 `pet_state` 表。同时**不新建好感度体系**：竹笌 `affinity` 表已有 `trust`/`intimacy`/`familiarity`/`total_interactions`/`streak_days` 五维（E-24），音乐狗子那个单一 `love: float` 是它的退化版。合并后宠物互动写入 `affinity`（`pet` 加 `intimacy`、`feed` 加 `trust` 等映射），`pet_state` 表只存宠物专属的 `mood`/`total_barks`/`songs_created`/`last_song_title`。避免两套好感度打架。

#### 4.2.2 三个新增服务模块

| 模块 | 职责 | 关键约束 |
|---|---|---|
| `music_provider.py` | ACE Music 客户端。负责构造 `<prompt>...</prompt>\n<lyrics>...</lyrics>` 载荷、解 base64 data URI、落盘、算 sha1 去重 | 密钥**必须**从 `os.getenv("ACE_MUSIC_API_KEY")` 读取且无默认值；未配置时 `/music/generate` 返回 503，不静默降级为假数据 |
| `lyrics_composer.py` | 歌词生成。移植 `STYLE_TEMPLATES`（民谣/流行/DJ电音/国风/说唱 5 种，含 bpm/乐器/结构）与 `build_lyrics_prompt`，LLM 调用改走竹笌既有 `agnes_client` | 不移植音乐狗子那套 5-provider failover（groq/cerebras/gemini/ace/local）：竹笌已锚定 Agnes 单一供应商，引入 5 套密钥管理是净负债 |
| `job_queue.py` | 异步任务表驱动。`enqueue` / `mark_running` / `mark_succeeded` / `mark_failed` / `reap_stale` | MVP 用 FastAPI `BackgroundTasks` + `music_jobs` 表，不引入 Celery/Redis（单实例够用；多实例时表上的 `SELECT ... FOR UPDATE` 可平滑升级） |

#### 4.2.3 音频文件落盘策略（C 盘禁装约束下）

```
F:/zhuyapp-backend/data/
├── zhuyu.db              现有 SQLite
├── .enc_key              现有加密密钥
└── audio/                【新增】
    ├── <sha1>.mp3        音乐产物，sha1 = SHA1(lyrics + prompt + duration)
    └── .gitignore        内容为 "*"
```

- 路径根取 `config.settings.DATA_DIR`（已支持 `DATA_DIR` 环境变量覆盖），**天然落在 F 盘**，无需额外改造。
- 复用 `tts_service/app.py` 已验证的模式（E-30）：所有第三方缓存目录显式重定向到 F 盘。若后续引入任何 HF/ModelScope 依赖，`HF_HOME` / `MODELSCOPE_CACHE` / `TORCH_HOME` 必须在 `config.py` 统一声明，不依赖默认值（默认值会落到 `C:/Users/<user>/.cache`，违反 C 盘禁装约束）。
- 清理策略：`sha1` 命名天然去重；单文件实测约 0.46 MB / 30 秒（E-13）。按 1000 首/月估算约 460 MB/月，F 盘余量 790 GB（E-29）可支撑数年。MVP 不做自动清理，只在 `GET /music/quota` 暴露占用量。

### 4.3 3D 渲染方案是否冲突

**结论：不冲突。这是一个被误判的风险。**

证据（E-04、E-05、E-06）：

| 渲染栈 | 技术实现 | 使用位置 | 与音乐狗子的关系 |
|---|---|---|---|
| Live2D | `vendor/flutter_live2d`（47 MB，Cubism 3 原生桥） | `/chat` 竹笌角色 | 无关 |
| `model_viewer_plus` 1.10.0 | Android WebView + `<model-viewer>`，加载 GLB | `/avatar` 3D 全屏页 | 无关 |
| 音乐狗子的狗 | **`CustomPainter` 纯矢量 2D**，`DogPainter` 用 `Canvas` 画 7 个部位 | 新增 `/pet` | **零第三方渲染依赖** |

音乐狗子既不用 3D 也不用 Live2D，它就是一段 Flutter 原生 `Canvas` 绘图代码。所谓「两套 3D 方案冲突」不成立。

但存在一个**真实的相邻风险**，需要写成硬约束（见 7.1 R-06）：`model_viewer_plus` 是 Android PlatformView（且本项目已为它打了 Hybrid Composition 补丁），与 Live2D 的 GL 纹理若同屏共存会显著掉帧。**架构约束：同一路由内最多挂载一个重型渲染视图**（Live2D / ModelViewer / 全屏 CustomPainter 动画三者互斥）。`/pet` 只用 `CustomPainter`，天然满足。

另一条必须守住的：`packages/model_viewer_plus` 本地补丁靠 `dependency_overrides` 生效。本次新增 `flutter_svg` 后必须跑一次 `flutter pub get` 并**确认 `dependency_overrides` 段未被改动**，随后回归「GLB 走路动画长跑不冻结」用例——`pubspec.yaml` 注释已记录官方 1.10.0 在 VirtualDisplay 下「几分钟后冻结」的原始缺陷。

### 4.4 两套 TTS 如何收敛

**结论：保留竹笌 IndexTTS 契约，废弃音乐狗子的 MOSS-TTS 调用层；但必须先修复 IndexTTS 微服务，否则语音能力目前是 0。**

实测现状（E-15、E-16、E-17）：

| 方案 | 实测可用性 | 依赖体积 | 契约 |
|---|---|---|---|
| 竹笌 IndexTTS 2.5 | **不可用**：venv 缺 torch/fastapi/indextts，`checkpoints/` 仅 12 KB | torch 3.2 GB（下载中断） | `POST /tts` → `audio/wav` 二进制 |
| 音乐狗子 MOSS-TTS-Nano | **不可用**：ONNX 权重是 LFS 指针 | onnxruntime（约 50 MB，**无需 torch**） | `POST /tts/generate` → JSON + `/tts/audio/{f}` |

两者都不可用，所以这不是「二选一」而是「先修哪一个」。给项目总监的建议路径与依据：

- **契约层**：锁定竹笌的 `POST /tts` → `audio/wav` 二进制。理由：前端 `core/services/tts_service.dart` 与 `BackendService.tts()` 已按此实现并接了 `just_audio`；改契约要动前端 3 处，改实现只动后端 1 处。
- **实现层（建议）**：MVP 阶段先补齐 **MOSS-TTS-Nano ONNX** 作为 `/tts` 的后端实现，把 IndexTTS 2.5 降级为 Phase 2 的音色克隆升级项。依据：MOSS 走 `onnxruntime` CPU 推理，不需要 3.2 GB torch（E-16 已证明 torch 下载是当前卡点），100M 参数量级模型在 F 盘落地成本远低；IndexTTS 2.5 的价值在音色克隆，而 MVP 阶段用不到。
- **前置动作**：MOSS 权重需从上游（ModelScope / HuggingFace）拉真权重，**不能靠 `git checkout` 备份分支**（拿到的是 LFS 指针）。落盘目录 `F:/zhuyapp-backend/models/MOSS-TTS-Nano-100M-ONNX/`，通过 `MOSS_TTS_MODEL_DIR` 环境变量指向；注意音乐狗子源码里的默认值是 `/root/.cache/moss-tts/...`（Linux 容器路径），在 Windows 本机必然失效，**必须显式配置**。

此项属跨模块决策，超出单纯架构选型，标记为**需项目总监裁决**（见 8.2）。

### 4.5 `/chat/v2` 的意图解析并入方案

音乐狗子的 `/chat` 会在 LLM 回复里夹带 `【CREATE_LYRICS】...【/CREATE_LYRICS】` / `【GENERATE_MUSIC】...【/GENERATE_MUSIC】` 标记块，再正则抽出结构化意图。这个能力有价值（用户说「写首歌」就自动跳创作流），但实现方式与竹笌的 SSE 流式冲突——流式输出时标记块会被逐 token 吐给用户，用户会看到裸标签。

**方案**：意图标记不进 `delta` 事件。`/chat/v2` 的 SSE 事件流增加约定：

```
event: delta      data: {"text": "汪！这个主题我喜欢"}      ← 逐 token，已剥离标记块
event: delta      data: {"text": "，我来写！"}
event: intent     data: {"type":"lyrics","theme":"毕业","style":"民谣","mood":"怀念"}
event: done       data: {"emotion":"excited","affinity_delta":{"intimacy":0.5}}
```

后端在流式聚合缓冲区里做标记块剥离（复用 `pet_api.py` 的正则，但改为流式安全的增量匹配），标记块内容不下发到 `delta`。前端 `chat_provider.dart` 监听 `intent` 事件后调 `context.push('/pet?prefill=...')`。

### 4.6 依赖版本收紧

`requirements.txt` 现状全是下界（`fastapi>=0.110`），实测已装 0.141.1。合并后改为区间锁定，防止 `pip install -U` 引入破坏性变更：

```
fastapi>=0.141,<0.142
uvicorn[standard]>=0.52,<0.53
pydantic>=2.13,<3.0
httpx>=0.28,<0.29
sqlalchemy>=2.0.51,<2.1
pymysql>=1.2,<1.3
cryptography>=50.0,<51.0
python-dotenv>=1.0,<2.0
pyjwt>=2.8,<3.0
```

---

## 5. 选型对比矩阵

评分说明：每项 1-5 分（5 为最优），加权总分 = Σ(得分 × 权重)。权重取自 MVP 阶段优先级：合规硬约束 > 迁移成本 > 生态成熟度 > 体积 > 扩展性。

### 选型 A：图标方案（P0-1 必须锁定，唯一方案，全项目不混用）

| 候选 | P0-1 合规（SVG，权重 0.35） | 迁移成本（0.20） | 跨端一致性（0.15） | 换色/换粗细（0.15） | 体积（0.10） | 生态（0.05） | 加权 |
|---|---|---|---|---|---|---|---|
| A1 Material Icons 字体（Flutter 内置，现状 61 处） | 1（字体非 SVG，不合规） | 5（零迁移） | 5 | 3（只能整体 tint） | 5 | 5 | **2.85** |
| A2 `lucide_icons_flutter` 3.1.17 | 2（打包为 IconData 图标字体，形式上仍非 SVG） | 4 | 5 | 3 | 4 | 4 | **3.15** |
| A3 **`flutter_svg` 2.3.0 + Lucide SVG 资产自托管** | **5** | 3（需建门面 + 迁移 82 处） | 5 | 5（`ColorFilter` + `strokeWidth` 可控） | 4（按需引入单个 svg） | 5（`flutter.dev` 官方发布者） | **4.40** |
| A4 自绘 `CustomPainter` 图标集 | 5 | 1（每个图标手写） | 5 | 5 | 5 | 1 | **3.60** |

**锁定 A3。具体锁定内容：**

| 项 | 值 |
|---|---|
| 渲染库 | `flutter_svg: 2.3.0`（pub.dev 实查：2026-05-08 发布，发布者 `flutter.dev` 已验证） |
| 预编译器 | `vector_graphics_compiler`（可选，`dart run vector_graphics_compiler -i x.svg -o x.svg.vec`） |
| 图标集 | **Lucide**（`lucide.dev`，ISC 许可，允许商用与再分发），取 SVG 源文件 |
| 资产路径 | `assets/icons/lucide/<kebab-case-name>.svg`（如 `music-4.svg`、`heart.svg`、`dog.svg`） |
| 唯一访问门面 | `lib/widgets/app_icon.dart` 暴露 `AppIcon(name: AppIcons.music, size: 24, color: ...)` |
| 名称常量表 | `lib/widgets/app_icons.dart`，`abstract final class AppIcons { static const music = 'music-4'; ... }` |
| 禁令 | 全项目禁止 `Icons.*`、`CupertinoIcons.*`、emoji 字面量、`IconData` 直接构造 |
| 落地校验 | `analysis_options.yaml` 加 `custom_lint` 或 CI 脚本 `grep -rn "Icons\.\|CupertinoIcons\." lib/` 必须为 0 |

**为什么不选 A2（Lucide 的 Flutter 字体包）**：它把 Lucide 打包成 `IconData` 图标字体分发，本质仍是字体而非 SVG，不满足 P0-1 的字面要求；且引入整套字体（1500+ 图标）而 MVP 实际用不到 40 个，体积不划算。选 A3 只需把用到的 SVG 拷进 `assets/`。

**为什么必须现在换而不是留着 61 处 `Icons.*`**：新模块用 SVG、老模块用图标字体，会出现同屏两种视觉语言（Material 的实心圆润 vs Lucide 的 2px 线性），比统一用旧方案更糟。所以迁移范围是**全项目 82 处**（竹笌 61 + 移植代码 21），不是只改新代码。

**MVP 图标清单（约 34 个，一次性拷入）**：`house`、`compass`、`user`、`message-circle`、`mic`、`phone`、`settings`、`chevron-left`、`chevron-right`、`x`、`check`、`plus`、`trash-2`、`pencil`、`search`、`music-4`、`play`、`pause`、`square`（停止）、`volume-2`、`volume-x`、`download`、`share-2`、`heart`、`dog`、`bone`（喂食）、`hand`（摸头）、`sparkles`、`lightbulb`、`library`、`tag`、`clock`、`loader`、`triangle-alert`。

### 选型 B：状态管理

| 候选 | 团队既有（0.30） | 跨页共享（0.25） | 可测性（0.20） | 迁移成本（0.15） | 生态（0.10） | 加权 |
|---|---|---|---|---|---|---|
| B1 **Riverpod 2.6.1**（竹笌现状） | 5 | 5 | 5 | 3（需改造移植代码的 10 处 setState） | 5 | **4.65** |
| B2 原生 `setState`（音乐狗子现状） | 2 | 1 | 2 | 5 | 5 | **2.50** |
| B3 Bloc | 1 | 5 | 5 | 1 | 5 | **3.20** |

**锁定 B1 Riverpod 2.6.1。** 竹笌 `main.dart` 已是 `ProviderScope` 根挂载，`routerProvider`/`themeProvider`/`chatProvider` 全在 Riverpod 上（E-03）。让新模块用 `setState` 会导致宠物情绪无法与 `/chat` 页共享——而「聊天时狗子情绪同步变化」是这次合并的核心体验。改造点：`_ChattyDogPetState` 的 `Timer.periodic(8s)` 吠叫定时器与 `_ChattyDogPetState`/`_CreationStudioState`/`_MusicPlayerState` 三处 State 迁到 `PetNotifier` / `MusicNotifier`。

### 选型 C：音乐生成的「部署方式」

| 候选 | 可行性（0.30） | 密钥安全（0.25） | 用户体验（0.20） | 成本可控（0.15） | 运维（0.10） | 加权 |
|---|---|---|---|---|---|---|
| C1 前端直连 ACE Music | 4 | 1（密钥进 APK，必泄露） | 2（48s 无进度反馈） | 2 | 4 | **2.65** |
| C2 后端同步代理（音乐狗子现状） | 3（48s 挂住连接） | 3（密钥在服务端，但当前硬编码） | 1（前端无超时会挂死） | 3 | 3 | **2.55** |
| C3 **后端异步 job + 落盘 + 轮询** | 5 | 5（密钥仅在服务端 env） | 5（有进度、可后台、可重试） | 4 | 4 | **4.70** |
| C4 本地自托管音乐模型（ACE-Step / YuE 类） | 1（需 GPU，本机不保证） | 5 | 2（CPU 推理分钟级） | 5（无 API 费用） | 1（权重数 GB + 环境） | **2.55** |

**锁定 C3。**

C4 明确判定为 **MVP 阶段不可行**，理由：开源音乐生成模型（ACE-Step 3.5B 级、YuE 7B 级）均以 GPU 推理为设计前提，CPU 上生成 30 秒音频是分钟级；本项目当前后端跑在 Windows 本机 + `venv`，无 GPU 保障。F 盘 790 GB 余量（E-29）足够放权重，磁盘不是瓶颈，**算力是**。若未来要做，前置条件是「有独立 GPU 推理节点」，届时 C3 的 job 表结构可直接复用（只换 `music_provider` 实现），架构无需重做——这是选 C3 的额外收益。

C3 的具体参数（全部有实测依据）：

| 参数 | 值 | 依据 |
|---|---|---|
| 后端调用超时 | 180 s | 实测 48.2 s（E-12），留 3.7 倍余量 |
| 前端首次轮询延迟 | 5 s | 不可能更早完成 |
| 轮询间隔 | 3 s 起，指数退避至 8 s 上限 | 48 s 内约 10-12 次请求，可接受 |
| 前端总放弃阈值 | 240 s | 超时后 job 仍在后端跑，用户可在「我的作品」看结果 |
| 并发上限 | 单用户同时 1 个 running job | 防刷第三方额度 |
| 去重 | `sha1(lyrics + prompt + duration)` 命中已有 song 则直接返回 | 实测同参数返回等价音频 |

### 选型 D：音频播放插件（必须收敛为一套）

| 候选 | 团队既有（0.30） | 能力覆盖（0.25） | 冲突风险（0.25） | 生态（0.20） | 加权 |
|---|---|---|---|---|---|
| D1 **`just_audio` 0.9.46**（竹笌现状） | 5 | 5（`setUrl`/`setFilePath`/`positionStream`/`durationStream`/后台播放） | 5 | 5 | **5.00** |
| D2 `audioplayers` 6.x（音乐狗子现状） | 1 | 4 | 5 | 5 | **3.35** |
| D3 两者并存 | 3 | 5 | 1（双 ExoPlayer 实例 + 音频焦点争抢） | 5 | **3.40** |

**锁定 D1 `just_audio` 0.9.46，不引入 `audioplayers`。** 竹笌的 TTS 播放（Cartesia / MiniMax / IndexTTS 三条链路）都跑在 `just_audio` 上；再装一个 `audioplayers` 会在 Android 上起第二套播放器实例，与 TTS 争抢音频焦点——表现为「歌放着，狗子说话把歌掐了，歌又不恢复」。改造点：重写 `_MusicPlayer`（原用 `AudioPlayer` + `onPositionChanged`/`onDurationChanged`/`onPlayerComplete` 三个回调 + `UrlSource`）为 `just_audio` 的 `positionStream`/`durationStream`/`playerStateStream` + `setUrl`。

### 选型 E：歌词与作品的持久化位置

| 候选 | 生产可用（0.35） | 加密合规（0.25） | 迁移成本（0.20） | 一致性（0.20） | 加权 |
|---|---|---|---|---|---|
| E1 独立 `lyrics_store.db`（音乐狗子现状） | 1（MySQL 生产环境下静默丢数据） | 1（无加密） | 5 | 1 | **1.80** |
| E2 **并入 `db.py` SQLAlchemy Core** | 5 | 5（复用 `encryption.encrypt`） | 3 | 5 | **4.60** |
| E3 新起独立 ORM（如 SQLModel） | 4 | 3 | 1 | 2 | **2.85** |

**锁定 E2。** 关键理由是 E1 有数据丢失级缺陷：`db.py` 支持 `DATABASE_URL` 切 MySQL（E-24），而 `lyrics_store.py` 的 `sqlite3.connect(DB_PATH)` 永远写本地文件（E-25）。生产切 MySQL 后，用户的歌词写进容器临时盘，容器重建即消失，且没有任何报错。

### 选型 F：动画方案

| 候选 | 团队既有（0.35） | 依赖增量（0.25） | 表达力（0.25） | 版本风险（0.15） | 加权 |
|---|---|---|---|---|---|
| F1 **Flutter 内置 `AnimationController` / `TweenAnimationBuilder`** | 5 | 5（零新增） | 4 | 5 | **4.75** |
| F2 `flutter_animate` 4.5.0（音乐狗子现状） | 1 | 3 | 5 | 3（未在 Flutter 3.47 / Dart 3.13 验证） | **2.85** |

**锁定 F1，不引入 `flutter_animate`。** 竹笌已有 `live2d_controller.dart`（19.4 KB）与 `_DogAvatarWithGlowState`（`SingleTickerProviderStateMixin`）两处成熟的 `AnimationController` 用法，内置 API 完全够用。移植代码里 `flutter_animate` 的用法是链式 `.animate().fadeIn().slideY()`，改写为 `AnimatedOpacity` + `SlideTransition` 的成本远低于引入一个未在当前 Flutter 版本验证的依赖。

### 选型汇总（锁定清单，全项目不得混用）

| 维度 | 锁定 | 显式排除 |
|---|---|---|
| 图标 | `flutter_svg` 2.3.0 + Lucide SVG 资产 + `AppIcon` 门面 | Material Icons 字体、Cupertino Icons、`lucide_icons_flutter`、emoji |
| 状态管理 | Riverpod 2.6.1 | `setState` 承载业务状态、Bloc、Provider(旧) |
| 路由 | go_router 14.8.1 | `Navigator.push` 直调、自制 BottomNavigation |
| 后端 HTTP | Dio 5.11.0 + `SigningInterceptor` | `package:http` 访问竹笌后端 |
| 音频播放 | `just_audio` 0.9.46 | `audioplayers` |
| 动画 | Flutter 内置 | `flutter_animate` |
| 音乐生成 | 后端异步 job 代理 ACE Music | 前端直连、同步代理、本地自托管 |
| 持久化（服务端） | `db.py` SQLAlchemy Core | 裸 `sqlite3`、内存字典 |
| TTS 契约 | `POST /tts` → `audio/wav` | JSON + `audio_url` 二段式 |
| 设计令牌 | `AppTheme`（含新增 `pet*` 语义色） | `Color(0x...)` 字面量、`Colors.*` 直用 |

---

## 6. API 端点清单

### 6.1 通用约定

| 项 | 值 |
|---|---|
| Base | `{BackendConfig.baseUrl}`（前端 Hive 持久化，设置页可改） |
| 版本策略 | 沿用现有无前缀路径（`/chat/v2` 已以端点级 `v2` 表达版本）。**不为新端点引入 `/api/v1/` 前缀**——与 22 个存量端点不一致的收益不足以抵偿改造与联调成本。版本演进沿用端点级后缀（如未来 `/music/generate/v2`）。此为对通用规范的显式偏离，记入 ADR-006。 |
| 认证 | 全部端点走 `auth.verify_request`（app 级 `dependencies`）。请求头：`X-Api-Key`、`X-Timestamp`、`X-Nonce`、`X-Signature`、`X-User-Id`。签名串 `METHOD\nPATH\nTIMESTAMP\nNONCE\nSHA256(BODY)`，HMAC-SHA256 |
| 用户标识 | **一律从 `X-User-Id` 头注入 `request.state.user_id`**。新端点路径中禁止出现 `user_id`（修正音乐狗子的 `/pet/state/{user_id}` 越权设计，E-28） |
| 错误体 | `{"detail": "<人类可读描述>"}`（沿用 FastAPI `HTTPException` 默认形态，与 22 个存量端点一致） |
| 错误码 | 400 参数错误 / 401 签名失败或过期或重放 / 403 内容违规 / 404 资源不存在 / 429 并发或频率超限 / 502 第三方失败 / 503 依赖未就绪 |

### 6.2 新增端点（12 个）

#### 宠物状态

| 方法 | 路径 | 功能 | 认证 | 请求 | 响应 |
|---|---|---|---|---|---|
| GET | `/pet/state` | 读当前用户宠物状态 | 签名 | — | `{mood, total_barks, songs_created, last_song_title, affinity:{trust,intimacy,familiarity}}` |
| POST | `/pet/interact` | 宠物互动（摸头/喂食/摇晃/呼唤） | 签名 | `{action: "pet"\|"feed"\|"shake"\|"bark"}` | `{dialogue, mood, affinity_delta:{...}, affinity:{...}}` |

设计说明：`action` 从 query 参数改为 body（音乐狗子原为 `POST /pet/interact/{uid}?action=x`）。理由是签名串包含 `SHA256(BODY)`，query 参数不参与签名，会留下篡改面。

#### 歌词

| 方法 | 路径 | 功能 | 认证 | 请求 | 响应 |
|---|---|---|---|---|---|
| POST | `/lyrics` | 生成并保存歌词 | 签名 | `{theme, style, mood, additional?, user_mood?}` | `201` `{id, title, lyrics, note, theme, style, mood, pet_reaction, created_at}` |
| GET | `/lyrics` | 歌词列表（分页 + 筛选） | 签名 | query: `theme?`、`style?`、`limit=20`、`offset=0` | `{items:[...], total, limit, offset, has_more}` |
| GET | `/lyrics/{id}` | 歌词详情 | 签名 | — | `{id, title, lyrics, note, tags, theme, style, mood, created_at, updated_at}` |
| PATCH | `/lyrics/{id}` | 改标题 / 标签 | 签名 | `{title?, tags?}` | `{...同详情}` |
| DELETE | `/lyrics/{id}` | 软删除歌词 | 签名 | — | `{ok: true, id}` |

`style` 取值锁定为 5 个：`民谣`、`流行`、`DJ电音`、`国风`、`说唱`（移植 `STYLE_TEMPLATES`）。传入其他值回落 `流行`。

#### 音乐生成（异步 job）

| 方法 | 路径 | 功能 | 认证 | 请求 | 响应 |
|---|---|---|---|---|---|
| POST | `/music/generate` | 提交生成任务 | 签名 | `{lyric_id?, lyrics?, prompt, duration=30, language="zh"}` | `202` `{job_id, status:"queued", poll_after_ms:5000}` |
| GET | `/music/jobs/{job_id}` | 查询任务 | 签名 | — | `{job_id, status, progress, song?, error?}` |
| DELETE | `/music/jobs/{job_id}` | 取消排队中的任务 | 签名 | — | `{ok, job_id, status:"cancelled"}` |
| GET | `/music/audio/{filename}` | 取音频文件 | 签名 | — | `audio/mpeg` 二进制 |

`status` 枚举：`queued` / `running` / `succeeded` / `failed` / `cancelled`。
`succeeded` 时 `song` = `{id, title, audio_url:"/music/audio/<sha1>.mp3", duration_sec, lyric_id, created_at}`。
`lyric_id` 与 `lyrics` 二者必填其一；同时给出时以 `lyric_id` 为准。

#### 作品库

| 方法 | 路径 | 功能 | 认证 | 请求 | 响应 |
|---|---|---|---|---|---|
| GET | `/songs` | 作品列表 | 签名 | query: `limit=20`、`offset=0` | `{items:[...], total, limit, offset, has_more}` |
| DELETE | `/songs/{id}` | 软删除作品（同时删磁盘音频，若无其他引用） | 签名 | — | `{ok, id}` |

### 6.3 变更端点（3 个）

| 端点 | 变更 | 原因 |
|---|---|---|
| `POST /chat/v2` | SSE 事件流新增 `event: intent`，`delta` 中剥离 `【CREATE_LYRICS】`/`【GENERATE_MUSIC】` 标记块 | 移植意图路由能力，同时避免用户看到裸标签（见 4.5） |
| `GET /user/export` | 导出内容追加 `lyrics`、`songs`（音频以文件清单 + 下载链接形式给出） | 个人信息导出权必须覆盖新增的用户创作内容 |
| `DELETE /user/data` | 删除范围追加 `lyrics`、`songs`、`music_jobs` 及磁盘音频文件 | 删除权必须彻底，否则磁盘残留用户创作物 |

### 6.4 明确不移植的端点（4 个）

| 端点 | 不移植原因 |
|---|---|
| `POST /chat`（音乐狗子非流式对话） | 与 `/chat/v2` SSE 重复且更弱；两个对话入口必然导致上下文不同步 |
| `GET /llm/status` | 对外暴露各 provider 的 `has_key` 与模型名，是信息泄露面 |
| `GET /history/{user_id}` | `user_id` 在路径 = 越权读取；且竹笌已有 `/memory/*` 承担历史 |
| `POST /tts/generate`、`GET /tts/voices`、`GET /tts/barks`、`GET /tts/audio/{f}` | 与竹笌 `/tts` 契约冲突（JSON+URL vs wav 二进制），保留一套（见 4.4） |

---

## 7. 数据库与存储变更

### 7.1 ER 关系

```
                    ┌──────────────┐
                    │  (X-User-Id) │  用户标识，无独立 users 表
                    │   user_id    │  （沿用现状：设备级标识，无注册体系）
                    └──────┬───────┘
        ┌──────────────┬───┴────────┬──────────────┬──────────────┐
        ▼              ▼            ▼              ▼              ▼
┌──────────────┐┌───────────┐┌──────────┐┌──────────────┐┌─────────────┐
│  memories    ││ affinity  ││   kv     ││  pet_state   ││   lyrics    │
│  （现有）    ││ （现有）  ││ （现有） ││  【新增】    ││  【新增】   │
└──────────────┘└───────────┘└──────────┘└──────────────┘└──────┬──────┘
                                                                 │ 1
                                                                 │
                                                         ┌───────┴───────┐
                                                         │       N       │
                                                  ┌──────────────┐┌──────────────┐
                                                  │ music_jobs   ││    songs     │
                                                  │  【新增】    ││  【新增】    │
                                                  └──────┬───────┘└──────┬───────┘
                                                         │ 1          1  │
                                                         └───────────────┘
                                                          job 成功产出 song
```

### 7.2 新增表 DDL（写入 `db.py`，SQLAlchemy Core 声明）

```sql
-- 宠物专属状态（好感度不在此表，统一读 affinity）
CREATE TABLE pet_state (
    user_id          VARCHAR(128) PRIMARY KEY,
    mood             VARCHAR(32)  NOT NULL DEFAULT 'happy',
    total_barks      INTEGER      NOT NULL DEFAULT 0,
    songs_created    INTEGER      NOT NULL DEFAULT 0,
    last_song_title  VARCHAR(64),
    updated_at       VARCHAR(32)  NOT NULL
);

-- 歌词。lyrics_text 与 note 为用户创作内容，按 memories.content 同规格字段加密
CREATE TABLE lyrics (
    id           VARCHAR(36)  PRIMARY KEY,
    user_id      VARCHAR(128) NOT NULL DEFAULT 'default',
    title        VARCHAR(128) NOT NULL DEFAULT '',
    theme        VARCHAR(128) NOT NULL DEFAULT '',
    style        VARCHAR(32)  NOT NULL DEFAULT '流行',
    mood         VARCHAR(32)  NOT NULL DEFAULT 'happy',
    lyrics_text  TEXT         NOT NULL,          -- encryption.encrypt
    note         TEXT,                            -- encryption.encrypt
    tags         TEXT,                            -- JSON 数组字符串，应用层兜底 '[]'
    created_at   VARCHAR(32)  NOT NULL,
    updated_at   VARCHAR(32)  NOT NULL,
    deleted_at   VARCHAR(32)
);
CREATE INDEX idx_lyrics_user_created ON lyrics (user_id, created_at DESC);
CREATE INDEX idx_lyrics_user_style   ON lyrics (user_id, style);

-- 音乐生成任务
CREATE TABLE music_jobs (
    id            VARCHAR(36)  PRIMARY KEY,
    user_id       VARCHAR(128) NOT NULL,
    lyric_id      VARCHAR(36),
    prompt        TEXT         NOT NULL,
    duration_sec  INTEGER      NOT NULL DEFAULT 30,
    language      VARCHAR(16)  NOT NULL DEFAULT 'zh',
    status        VARCHAR(16)  NOT NULL DEFAULT 'queued',
    progress      FLOAT        NOT NULL DEFAULT 0.0,
    song_id       VARCHAR(36),
    error         VARCHAR(255),
    attempt       INTEGER      NOT NULL DEFAULT 0,
    created_at    VARCHAR(32)  NOT NULL,
    started_at    VARCHAR(32),
    finished_at   VARCHAR(32)
);
CREATE INDEX idx_jobs_user_created  ON music_jobs (user_id, created_at DESC);
CREATE INDEX idx_jobs_status        ON music_jobs (status);

-- 音乐作品
CREATE TABLE songs (
    id            VARCHAR(36)  PRIMARY KEY,
    user_id       VARCHAR(128) NOT NULL,
    lyric_id      VARCHAR(36),
    job_id        VARCHAR(36),
    title         VARCHAR(128) NOT NULL DEFAULT '',
    audio_sha1    VARCHAR(40)  NOT NULL,   -- 文件名 = <sha1>.mp3，天然去重
    audio_bytes   INTEGER      NOT NULL DEFAULT 0,
    duration_sec  INTEGER      NOT NULL DEFAULT 0,
    prompt        TEXT,
    created_at    VARCHAR(32)  NOT NULL,
    deleted_at    VARCHAR(32)
);
CREATE INDEX idx_songs_user_created ON songs (user_id, created_at DESC);
CREATE INDEX idx_songs_sha1         ON songs (audio_sha1);
```

设计取舍说明（诚实记录）：

| 取舍 | 决定 | 代价 |
|---|---|---|
| `lyrics_text` 字段加密 | 加密（与 `memories.content` 同规格） | **失去歌词全文检索能力**。MVP 的 `GET /lyrics` 只按 `theme`/`style`/`created_at` 筛选，不支持内容 LIKE 搜索。若产品侧要全文搜索，需在 Phase 2 引入「明文倒排索引表 + 只存分词」方案，本次不做。 |
| 主键类型 | `VARCHAR(36)`（UUID 字符串） | 比自增整型索引略大。换来的是客户端可先生成 ID、离线创作可先落本地再同步（竹笌已有 `SyncEngine`，此设计为其留口） |
| 时间字段类型 | `VARCHAR(32)` ISO8601 字符串 | 与现有 `memories.created_at` 完全一致，避免同库两种时间表示 |
| 软删除 | `deleted_at` 置位 | 需在所有查询加 `deleted_at IS NULL`。换来的是「误删可恢复」与 `DELETE /user/data` 的硬删除有区分 |
| 不建 `users` 表 | 沿用 `X-User-Id` 设备标识 | 与现状一致（`memories`/`affinity` 都是这样）。多设备同账号不在 MVP 范围 |
| 不建复合索引之外的索引 | 只建 6 个索引 | 遵循「MVP 不过早优化」；`lyrics`/`songs` 的访问模式明确是「按用户按时间倒序翻页」，复合索引已覆盖 |

### 7.3 迁移方案

`db.py` 的 `init()` 已用 `_metadata.create_all(engine, checkfirst=True)`，**新增表声明后自动幂等建表，无需写迁移脚本**。

需补的一次性数据迁移（仅当备份分支的 `lyrics_store.db` 里有真实用户数据时执行）：

```
scripts/migrate_lyrics_store.py
  读 backup 的 lyrics_store.db（裸 sqlite3）
  → 逐行映射 id/user_id/theme/style/mood/lyrics_text/note/tags/title/created_at/updated_at
  → 对 lyrics_text、note 施加 encryption.encrypt
  → 写入新 lyrics 表（INSERT ... 幂等：先按 id 查重）
  → 输出迁移条数与失败明细
```

`_sessions` 内存字典无需迁移（进程重启已丢，本就无数据）。

### 7.4 存储变更

| 位置 | 变更 | 约束 |
|---|---|---|
| `F:/zhuyapp-backend/data/audio/` | 新建，存音乐 MP3 | 路径根取 `settings.DATA_DIR`，天然在 F 盘；目录内 `.gitignore` 内容为 `*` |
| `F:/zhuyapp-backend/models/` | 新建，存 TTS 权重（见 4.4） | 通过 `MOSS_TTS_MODEL_DIR` 环境变量指向；`.gitignore` 排除 |
| `F:/zhuyapp/assets/icons/lucide/` | 新建，存约 34 个 SVG | 需在 `pubspec.yaml` 的 `assets:` 显式声明（注意：该文件注释已记录「本环境 Flutter 对目录资源声明不递归子目录」，故必须逐目录列出） |
| `.dockerignore` | 追加 `data/audio/`、`models/` | 防镜像膨胀。注意现有 `.dockerignore` 已排除 `data/`，需确认新目录被覆盖 |
| 前端本地库 | 不新增 sqflite 表 | 歌词/作品走服务端为单一事实源；离线只读缓存放 Hive `songs_cache` box |

---

## 8. 风险与不可行警告

风险分级：**P0 = 上线阻断，必须在合并前解决**；**P1 = 高危，需在 Phase 1 结束前解决**；**P2 = 需登记与监控**。

### 8.1 P0 阻断级

| ID | 风险 | 证据 | 影响 | 处置 |
|---|---|---|---|---|
| **R-01** | **硬编码密钥已泄露且当前仍然有效** | `backend/pet_api.py` 中 `ACE_MUSIC_API_KEY` 默认值为明文密钥；`config.py:20` 中 `AGNES_API_KEY` 明文写死并附注释「按用户要求硬编码写死，不走 .env」。实测携该 ACE 密钥的请求返回 `HTTP 200` 并产出真实音频（E-11） | 任何拿到源码或反编译产物的人都能免费消耗额度；Agnes 密钥同理，可被用于任意 LLM 调用并计费到本项目 | 1. 两个密钥**立即在上游轮换**（旧密钥作废）；2. 全部改为 `os.getenv(...)` 且**无默认值**，未配置时端点返回 503 而非静默降级；3. `git` 历史中的密钥已无法撤回，轮换是唯一补救；4. 加 CI 检查（`gitleaks` 或等价规则）阻断再次提交 |
| **R-02** | **返回的 data URI 无法播放** | 实测 `audio_url.url` 以 `data:audio/mpeg;base64,` 开头，641 107 字符（E-13）；前端却用 `_player.play(UrlSource(widget.url))`（E-14） | 「生成成功但点播放没声音」，且不报错——最难排查的一类缺陷 | 后端必须解 base64 → 落盘 → 回传常规 HTTP URL（见 4.2.3）。前端严禁把 `data:` 交给播放器 |
| **R-03** | **48.2 秒同步等待 + 前端无超时** | 实测 `time_total: 48.226823s`（E-12）；`PetApiService` 用 `http.Client()` 未设 `timeout`（唯一设超时的是 `tts_service.dart` 的 8s） | 用户点「生成」后 UI 无反馈近 1 分钟；弱网下挂到系统级超时（Android 可达数分钟），期间无法退出，观感等同崩溃 | 必须走 6.2 的异步 job + 轮询。所有前端网络调用强制设 `Dio` 全局 `connectTimeout`/`receiveTimeout` |
| **R-04** | **仓库携带 957 MB 二进制，禁止直接 merge 备份分支** | 备份分支 `backend/` blob 合计 956.99 MB，其中 `qwen2.5-0.5b-local/model.safetensors` 单文件 942.32 MB 为真实 blob（E-18）；`.git` 已 1.6 GB，而 `lib/` 仅 466 KB（E-19） | 若执行 `git merge zhuyu-frontend-backup`，主线 tree 将永久携带这些 blob；后续每个 clone 拉 1.6 GB+；CI 构建时间与流量成本剧增 | **严禁 `git merge`。** 只允许逐文件 `git show <branch>:<path> > <target>` 取文本源码（本文档 4.1.1 已列出全部 3 个待移植文件）。模型权重一律走 `.gitignore` + 下载脚本。备份分支保留归档，不参与合并 |
| **R-05** | **签名鉴权被绕过，生产必 401** | 后端 `FastAPI(dependencies=[Depends(auth.verify_request)])` 全局强制（E-08）；`PetApiService` 用裸 `http.Client()` 无签名头（E-07） | 本地开发（`ZHUYU_API_KEY` 为空进开发模式）一切正常，一上生产音乐功能全挂——典型的「本地能跑，线上全红」 | 必须改走 Dio + `SigningInterceptor`（见 4.1.3）。并在 Phase 1 加一条集成测试：**用非空 API Key 启动后端**，跑通全部音乐端点 |

### 8.2 P1 高危级

| ID | 风险 | 证据 | 处置 |
|---|---|---|---|
| **R-06** | 重型渲染视图同屏共存会掉帧 | `model_viewer_plus` 是 Android WebView PlatformView，且已因「VirtualDisplay 下 GLB 动画几分钟后冻结」打了 Hybrid Composition 补丁（E-04）；Live2D 走原生 GL（E-05） | 架构约束：**同一路由最多一个重型渲染视图**（Live2D / ModelViewer / 全屏 CustomPainter 动画三者互斥）。`/pet` 只用 `CustomPainter`，天然满足。新增依赖后必须回归「GLB 走路动画长跑不冻结」 |
| **R-07** | 本地补丁可能被依赖变更冲掉 | `dependency_overrides: model_viewer_plus: path: packages/model_viewer_plus`（E-04） | 新增 `flutter_svg` 后跑 `flutter pub get`，**必须 diff 确认 `dependency_overrides` 段与 `pubspec.lock` 中该包解析路径未变**；加 CI 断言 |
| **R-08** | 语音能力当前实际为零，且两套 TTS 都不可用 | IndexTTS venv 缺 torch/fastapi/indextts，`checkpoints/` 仅 12 KB，`uv_sync.log` 停在 `Downloading torch (3.2GiB)`（E-15、E-16）；MOSS-TTS 权重是 LFS 指针（E-17） | 见 4.4。**此项需项目总监裁决**：是补 MOSS-TTS-Nano ONNX（轻，约 50 MB 依赖，无 torch）还是续下 IndexTTS（重，3.2 GB torch，但有音色克隆）。架构侧建议前者，并把「`/tts` 返回 503 时前端静默降级为纯文字」作为常态兜底（前端 `tts_service.dart` 已实现三层容错） |
| **R-09** | 越权读取任意用户数据 | `@app.get("/pet/state/{user_id}")`、`@app.get("/history/{user_id}")`（E-28） | 新端点路径中禁止出现 `user_id`，一律从 `X-User-Id` 注入（见 6.1）。这两个原端点不移植 |
| **R-10** | 宠物状态与好感度双体系冲突 | 音乐狗子 `_sessions` 内存字典 + 单一 `love: float`（E-27）；竹笌 `affinity` 表已有五维加密好感度（E-24） | 落库 + 语义收敛：互动写 `affinity`（`pet`→`intimacy`、`feed`→`trust`、`bark`→`familiarity`），`pet_state` 只存宠物专属字段（见 4.2.1 改造三） |
| **R-11** | 待移植文件全部严重超长 | `chatty_dog_pet.dart` 1097 行、`pet_studio_page.dart` 1088 行（E-20） | 按 4.1.1 落位表拆分，**单文件硬上限 300 行**。若拆分后仍有文件超限，不得放行 |
| **R-12** | 三处硬编码色值 + emoji 图标违反 P0 规则 | 移植代码 28 处 `Color(0x` + 16 处 emoji；竹笌存量 7 文件 emoji + 61 处 `Icons.*`（E-21、E-22） | 按 4.1.4 清单一次性清理，范围含竹笌存量债。加 CI 检查：`grep -rn "Icons\.\|CupertinoIcons\.\|Color(0x" lib/ --include=*.dart`（`app_theme.dart` 白名单）必须为 0 |
| **R-13** | 歌词库在 MySQL 生产环境静默丢数据 | `lyrics_store.py` 裸 `sqlite3.connect` vs `db.py` 支持 `DATABASE_URL` 切 MySQL（E-24、E-25） | 按选型 E 并入 `db.py`；不保留任何裸 `sqlite3` 调用 |

### 8.3 P2 登记与监控

| ID | 风险 | 证据 / 说明 | 处置 |
|---|---|---|---|
| R-14 | 第三方服务无 SLA、无配额可见性、成本不可预测 | 实测握手 13.7 s（无鉴权即被拒的请求）、生成 48.2 s；响应 `usage` 只给 `completion_tokens: 100`，无计费字段 | 后端记录每次调用的耗时与字节数到 `music_jobs`；加日调用上限（默认 200/日/实例）；失败明确提示「音乐服务繁忙」而不伪造 demo 数据 |
| R-15 | 生成音乐属 AIGC，需合规标识与内容过滤 | 竹笌已有 `content_moderation.py`，但音乐狗子的 `/generate` 未接 | `POST /music/generate` 入口对 `lyrics` + `prompt` 过内容过滤；产物在 UI 与导出文件中标注 AI 生成；`legal/` 文档补充 AIGC 条款 |
| R-16 | 不移植的 5-provider LLM failover 意味着 Agnes 单点 | 竹笌已锚定 Agnes 单供应商 | 登记为已知单点。`/chat/v2` 现有降级逻辑覆盖对话；歌词生成失败时明确报错，**不回落 `_demo_lyrics` 假数据**（音乐狗子原实现会静默返回模板歌词并标 `_demo`，这会让用户以为 AI 写得很差） |
| R-17 | `requirements.txt` 只有下界，`pip install -U` 可能引入破坏性变更 | 实测已装 FastAPI 0.141.1，而声明是 `>=0.110` | 按 4.6 收紧为区间锁定 |
| R-18 | 双 Provider 目录 + 空 `pages/home/` 的存量结构债 | `presentation/providers/` 与 `providers/app_providers_legacy.dart` 并存；`pages/home/` 空目录但 `/home` 复用 `ChatPage` | 本次不解决，登记入技术债清单。新代码一律只用 `presentation/providers/` |
| R-19 | 歌词加密后无法全文检索 | 见 7.2 取舍表 | 产品侧需确认「歌词库只按主题/风格/时间筛选」可接受。若不可接受，需追加 Phase 2 方案 |
| R-20 | 音频磁盘持续增长无自动回收 | 实测 0.46 MB / 30 秒（E-13） | MVP 不做自动清理，只在运维侧监控 `data/audio/` 体积；F 盘 790 GB 余量可支撑数年（E-29） |

### 8.4 明确的不可行结论

| 项 | 结论 | 依据 |
|---|---|---|
| 本地自托管音乐生成模型 | **MVP 不可行** | 开源音乐模型（ACE-Step 3.5B / YuE 7B 级）以 GPU 推理为设计前提，本项目后端跑在无 GPU 保障的 Windows 本机 venv。瓶颈是算力，不是磁盘（F 盘 790 GB 充足）。前置条件：独立 GPU 推理节点。届时只换 `music_provider` 实现，job 架构可复用 |
| 直接 `git merge zhuyu-frontend-backup` | **禁止** | 会把 957 MB 二进制永久并入主线（R-04） |
| 保留两套音频播放器 | **禁止** | Android 上双播放器实例争抢音频焦点（选型 D） |
| 保留 emoji 作情绪图标（`moodEmojis` 常量） | **禁止** | 违反 P0-1；改为 `moodIcon` 映射到 Lucide SVG |
| 前端直连 ACE Music | **禁止** | 密钥必然随 APK 泄露，且绕过内容过滤（选型 C） |
| 新增端点带 `user_id` 路径参数 | **禁止** | 越权读取（R-09） |

---

## 9. 落地顺序与放行门禁

### 9.1 阶段划分

| 阶段 | 内容 | 完成判据 |
|---|---|---|
| **Phase 0 安全止血** | 轮换 2 个泄露密钥；改为 `getenv` 无默认值；加 secret 扫描 CI | 源码内 `grep -rn "sk-\|c2fa5ed9" .` 为 0；未配置密钥时端点返回 503 |
| **Phase 1a 骨架** | 后端拆 router；`db.py` 加 4 张表；`AppIcon` 门面 + 34 个 SVG 落位；`pubspec.yaml` 加 `flutter_svg` | `main.py` ≤ 120 行；`flutter pub get` 后 `dependency_overrides` 未变；GLB 动画长跑回归通过 |
| **Phase 1b 图标统一** | 迁移全项目 82 处图标 + 36 处 emoji | `grep -rn "Icons\.\|CupertinoIcons\." lib/` 为 0；emoji 扫描为 0 |
| **Phase 1c 后端音乐链路** | `music_provider` / `lyrics_composer` / `job_queue` + 12 个新端点 | 用**非空 API Key** 启动后端，全端点签名联调通过；生成→落盘→回传 URL 端到端通过 |
| **Phase 2a 前端移植** | 按 4.1.1 落位表拆分移植 14 个文件；`setState`→Riverpod；`http`→Dio；播放器→`just_audio` | 无文件超 300 行；无 `package:http` 访问竹笌后端；无 `audioplayers` 依赖 |
| **Phase 2b 联调** | `/pet` `/pet/full` `/pet/library` 三条路由 + `/chat/v2` intent 事件 | 生成中有进度、可后台、失败可重试；48s 场景下 UI 全程可交互 |
| **Phase 3 TTS 决议后实施** | 按 R-08 裁决结果补齐语音 | `/tts` 返回真实 wav；503 时前端静默降级为纯文字 |

### 9.2 需项目总监裁决的事项

| 编号 | 事项 | 架构侧建议 | 待决点 |
|---|---|---|---|
| D-01 | TTS 实现选 MOSS-TTS-Nano ONNX 还是续下 IndexTTS 2.5 | 选 MOSS（轻、无 torch、可先跑起来），IndexTTS 降为 Phase 2 音色克隆 | 是否接受 MVP 阶段没有音色克隆 |
| D-02 | 图标迁移范围是否含竹笌存量 82 处 | 含。新旧混用视觉更糟 | 是否接受这部分工时 |
| D-03 | 歌词加密导致无全文检索 | 接受（加密优先） | 产品侧是否需要歌词内容搜索 |
| D-04 | 是否为新端点引入 `/api/v1/` 前缀 | 不引入，与 22 个存量端点保持一致 | 是否接受此规范偏离（ADR-006） |
| D-05 | 音乐生成第三方依赖的商务与合规 | 需确认 ACE Music 的服务条款、配额、计费与生成物版权归属 | 法务/商务确认 |

---

## 10. ADR 索引

| 编号 | 标题 | 状态 |
|---|---|---|
| ADR-001 | 图标方案锁定 flutter_svg 2.3.0 + Lucide SVG 自托管，禁用图标字体与 emoji | Accepted |
| ADR-002 | 状态管理统一 Riverpod 2.6.1，移植代码的 setState 全部改造 | Accepted |
| ADR-003 | 音乐生成采用「后端异步 job + 落盘 + 轮询」，不本地自托管、不前端直连 | Accepted |
| ADR-004 | 音频播放统一 just_audio 0.9.46，不引入 audioplayers | Accepted |
| ADR-005 | 歌词与作品持久化并入 db.py SQLAlchemy Core，废弃裸 sqlite3 | Accepted |
| ADR-006 | 新增端点不引入 `/api/v1/` 前缀，沿用端点级版本后缀（对通用规范的显式偏离） | Accepted |
| ADR-007 | 禁止 git merge 备份分支，只逐文件取文本源码 | Accepted |
| ADR-008 | 好感度体系统一为竹笌 affinity 五维，pet_state 只存宠物专属字段 | Accepted |
| ADR-009 | 不引入 flutter_animate，动画用 Flutter 内置 API | Accepted |
| ADR-010 | 不移植 5-provider LLM failover，歌词生成失败明确报错而非回落假数据 | Accepted |

---

## 11. 附：机器可读契约

完整 OpenAPI 3.0 规范见同目录 `openapi-music-pet.yaml`。前端据此生成 Dart 类型，后端据此实现，双方以该文件为唯一契约；任何变更须同步更新该文件并通知前后端。

# 竹笌 × 音乐狗子 合并重设计 · 规格契约 Spec（Phase 1.5）

| 项 | 值 |
|---|---|
| 文档类型 | 规格即契约（Spec as Contract） |
| 文档版本 | v1.0（Phase 1.5 冻结基线） |
| 编制 | 首席架构师（高见远） |
| 状态 | 待项目总监（大湾区靓仔）裁决冻结 |
| 下游约束 | 前端 Agent / 后端 Agent / 设计师均以此文件为唯一开发契约；任何变更须同步更新本文件与 `openapi-music-pet.yaml` 并通知前后端 |
| 源文档 | `prd.md`（PRD v1.0）、`architecture.md`（技术架构 v1.0）、`DESIGN.md`（UI/UX v1.0）、`design-tokens.json`、`openapi-music-pet.yaml` |
| 调研方式 | 全部结论基于实读源码 / 实测命令 / 实测网络请求（取证台账见 architecture.md §0，E-01~E-30） |

> 本 Spec 为 Phase 1 三文档的**合并且可执行化**产物。PRD 定义"做什么"，架构文档定义"怎么落地"，DESIGN 定义"长什么样"，OpenAPI 定义"接口契约"。本章节把它们收敛为单一事实源，下游不得各自解读。

---

## 1. 产品定义

**一句话**：竹笌是一款以「竹系少年感 3D 角色 + 语音优先陪伴」为基底的 AI 陪伴 App；本次合并把音乐狗子作为内置音乐模块接入，让用户在与 3D 角色（竹笌 / 狗子）对话陪伴的同时，能用自然语言一句话生成属于自己的原创歌曲，并让宠物随音乐节奏律动。

**目标用户**
- 主要画像：18–28 岁、爱用语音聊天的 Z 世代内容消费者；日常有「想有人陪聊 / 想写歌但零乐理」两类轻诉求，却不愿分别装两个 App。水平中等，习惯微信/抖音式交互，对"角色在场感"敏感。
- 次要画像：UGC 音乐爱好者与情绪记录者——想把心情写成歌词、把日常变成一首歌，并看到宠物对自己的好感随时间增长。
- 非目标画像：专业音乐制作人（需 DAW / 多轨混音）；纯工具型效率用户（无陪伴诉求）。

**核心问题（用户真实痛点，而非嘴上说的方案）**
- 用户嘴上说「我要一个会写歌的宠物」→ 真实需求是「在陪伴场景里，用最低门槛把情绪变成可分享的音乐作品，并获得宠物反馈的陪伴感」。
- 用户嘴上说「把两个 App 合并」→ 真实需求是「在一个连贯的语音陪伴空间里，聊天和创作不是割裂的两件事，而是同一个角色人格的延伸」。
- 现有错位：竹笌有成熟陪聊 / 3D 角色 / 记忆 / 好感度，但缺创作出口；音乐狗子有宠物对话 + 音乐生成，但它是独立分支、裸调后端、无签名、无持久化、密钥硬编码、体验割裂。合并解决「陪伴有温度但无表达出口，创作有出口但无陪伴温度」。

---

## 2. MVP 范围锁定

**MVP = 竹笌核心闭环 + 音乐狗子核心创作闭环**，二者共享同一角色人格与好感度体系。

### 2.1 必交付功能表

| 编号 | 功能 | 归属 | 验收摘要 |
|---|---|---|---|
| F-01 | 信纸式陪聊（3D 竹笌同屏 + 流式对话） | 竹笌既有 | 首字流式延迟 ≤1.5s；对话摘要写入记忆 |
| F-02 | 记忆系统（时间线式记忆流） | 竹笌既有 | `/settings/memory` 时间线可查，空状态有引导 |
| F-03 | 情绪系统（对话情绪芯片 + 角色情绪反馈） | 竹笌既有 | 每轮对话产出情绪并悬浮更新 |
| F-04 | 好感度五维（trust/intimacy/familiarity/total_interactions/streak_days） | 竹笌既有 | 宠物互动回写五维 |
| F-05 | 实时语音通话（LiveKit 全屏 + 波形） | 竹笌既有 | 挂断键暖红圆钮；不可用时降级 |
| F-06 | TTS 语音合成（返回 audio/wav） | 竹笌既有 | 微服务不可用时 `/tts` 返 503，前端静默降级纯文字 |
| F-07 | 宠物对话（狗子台词 + 情绪反应，纯文本无 emoji） | 音乐狗子新增 | `POST /pet/interact` 返台词 + mood + affinity_delta |
| F-08 | 歌词生成与展示（Suno 式时间线，mono 字阶） | 音乐狗子新增 | `POST /lyrics` → 201；失败 502 明确报错不回落假歌词 |
| F-09 | 音乐生成（自然语言 prompt + 歌词 → ACE Music 异步生成） | 音乐狗子新增 | `POST /music/generate` → 202 + job_id；轮询至 succeeded |
| F-10 | 宠物状态 / 好感（mood + loveMeter，写入五维 affinity） | 音乐狗子新增 | `pet_state` 落库 + 五维回写 |
| F-11 | 随音乐节奏律动（播放时狗子节拍律动 + 暖橙发光脉冲） | 音乐狗子新增 | 用 `--ember` 暖橙，单一 `just_audio` 实例 |

### 2.2 进 Backlog（非 MVP）

3D 角色页深度换装玩法、发现页竹林沉浸式社交、多宠物 / 多角色人格切换、音乐作品社交分享裂变、本地自托管音乐模型（需 GPU 节点，前置条件见架构文档选型 C4）。

### 2.3 RICE 排序（评分公式：`Score = (Reach × Impact × Confidence) / Effort`）

| 功能 | Reach | Impact | Conf | Effort | Score | MVP |
|---|---|---|---|---|---|---|
| 信纸式陪聊 | 10 | 3 | 100% | 8 | 3.75 | 是 |
| 歌词展示 / 歌词库 | 7 | 2 | 90% | 4 | 3.15 | 是 |
| 宠物状态 / 好感 | 7 | 1.5 | 90% | 3 | 3.15 | 是 |
| 记忆系统 | 7 | 2 | 100% | 4 | 3.50 | 是 |
| 情绪系统 | 7 | 1.5 | 100% | 3 | 3.50 | 是 |
| 好感度五维 | 7 | 1 | 100% | 3 | 2.33 | 是 |
| 实时语音通话 | 8 | 2 | 100% | 6 | 2.67 | 是 |
| TTS 语音合成 | 8 | 2 | 80% | 5 | 2.56 | 是（先修 IndexTTS） |
| 宠物对话 | 8 | 2 | 80% | 5 | 2.56 | 是 |
| 音乐生成 | 8 | 3 | 90% | 8 | 2.70 | 是 |
| 随音乐律动 | 7 | 1.5 | 80% | 4 | 2.10 | 是（含在模块内） |

---

## 3. 明确不做（Out-of-Scope）

| 编号 | 不做的事项 | 原因 |
|---|---|---|
| O-01 | 不另起独立音乐狗子 App / 不保留 `zhuyu-frontend-backup` 的 `frontend/` 独立工程 | 合并决策 D-01/D-02：竹笌为整体 App，音乐狗子仅作模块 |
| O-02 | 不本地部署音乐生成模型（ACE-Step / YuE 类） | 需 GPU 推理节点，本机无保障；C3 异步 job 架构已预留切换点 |
| O-03 | 不做前端直连 ACE Music / 不做同步代理 | 密钥必随 APK 泄露且绕过内容过滤；锁定 C3 后端异步代理 |
| O-04 | 不引入 `audioplayers`、`flutter_animate`、`lucide_icons_flutter`（字体包）、Bloc | 选型 D/F/A/B 已显式排除，避免双播放器争抢、未验证依赖、视觉语言混用 |
| O-05 | 不新建第二套好感度体系（弃用音乐狗子 `love: float`） | 写入竹笌五维 `affinity`，避免两套打架（D-11） |
| O-06 | 不保留裸 `sqlite3` 歌词库、不保留内存态 `_sessions` 宠物状态 | 生产切 MySQL 静默丢数据；落 `db.py` + `pet_state` 表 |
| O-07 | 不保留音乐狗子 5-provider 歌词 failover（groq/cerebras/gemini/ace/local） | 竹笌已锚定 Agnes 单一供应商，5 套密钥管理是净负债 |
| O-08 | 不做多角色人格市场 / 社交广场 / UGC 分享裂变（MVP） | 超出 MVP 范围，先验证「陪伴 + 创作」核心闭环留存 |
| O-09 | 不启用紫粉渐变、不启用 emoji 功能图标、不硬编码色值 | P0 红线，违反即退回 |
| O-10 | 不做 C 盘安装（音频 / 模型缓存 / 第三方缓存一律落 F 盘） | 受 C 盘禁装约束；`DATA_DIR`/`HF_HOME`/`MODELSCOPE_CACHE` 显式指向 F 盘 |

---

## 4. 技术架构（版本锚定）

### 4.1 版本锚定（全部实测，非声明值）

| 层 | 组件 | 锁定版本 | 取证 |
|---|---|---|---|
| 前端 | Flutter | **3.47.1**（stable, rev `6655482ec0`） | `flutter --version` |
| 前端 | Dart SDK | **3.13.1**（stable） | `dart --version` |
| 前端 | 依赖约束 | `sdk: ^3.12.2`（实测 3.13.1 落在区间内，无需改动） | `pubspec.yaml` |
| 后端 | Python（主后端 venv） | **3.13.14** | 探测 `F:/zhuyapp-backend/venv` |
| 后端 | FastAPI / Uvicorn / Pydantic | 0.141.1 / 0.52.1 / 2.13.4 | 探测 venv |
| 后端 | SQLAlchemy / PyMySQL / cryptography | 2.0.51 / 1.2.0 / 50.0.0 | 探测 venv |
| 后端 | 包管理 | uv / venv + 依赖区间锁定（见 §4.6） | 架构 §4.6 |
| 后端 | Python（TTS 微服务 venv） | 3.11.13（但 `torch`/`fastapi`/`indextts` 均 MISSING，R-08） | 架构 §1.3 |

> **版本歧义说明（需项目总监确认）**：本 Spec 任务书原文写「后端 Python 3.11.13 uv」，但已确认 `architecture.md`（实测 §1.3）记录主后端 venv 为 `Python 3.13.14`；`3.11.13` 实为 TTS 微服务 venv 版本（且依赖缺失）。本书锁定**主后端 = Python 3.13.14**（与确认文档一致），TTS venv = 3.11.13（待修复，R-08）。若总监确要主后端降级到 3.11.13，需回溯重测全部依赖兼容性。

### 4.2 锁定选型（全项目不得混用）

| 维度 | 锁定 | 显式排除 |
|---|---|---|
| 图标 | `flutter_svg` 2.3.0 + Lucide SVG 资产 + `AppIcon` 门面 | Material Icons 字体、Cupertino Icons、`lucide_icons_flutter`、emoji |
| 状态管理 | Riverpod 2.6.1 | `setState` 承载业务状态、Bloc、旧 Provider |
| 路由 | go_router 14.8.1 | `Navigator.push` 直调、自制 BottomNavigation |
| 后端 HTTP | Dio 5.11.0 + `SigningInterceptor` | `package:http` 访问竹笌后端 |
| 音频播放 | `just_audio` 0.9.46 | `audioplayers` |
| 动画 | Flutter 内置 `AnimationController` / `TweenAnimationBuilder` | `flutter_animate` |
| 音乐生成 | 后端异步 job 代理 ACE Music | 前端直连、同步代理、本地自托管 |
| 持久化（服务端） | `db.py` SQLAlchemy Core | 裸 `sqlite3`、内存字典 |
| TTS 契约 | `POST /tts` → `audio/wav` 二进制 | JSON + `audio_url` 二段式 |
| 设计令牌 | `AppTheme`（含新增 `pet*` 语义色） | `Color(0x...)` 字面量、`Colors.*` 直用 |

### 4.3 分层架构（目标形态）

```
表现层   lib/pages/**            go_router 声明式路由（唯一入口）
         lib/widgets/**          无状态展示组件 + AppIcon 图标门面
         （色/圆角/间距一律取 AppTheme 令牌；图标一律 AppIcon）
状态层   lib/presentation/providers/**   Riverpod Notifier / Provider
         （页面不持有业务状态，只 ref.watch）
领域层   lib/domain/entities/**          纯 Dart 实体，零 Flutter 导入
         lib/domain/repositories/**      抽象接口
数据层   lib/data/services/**            远程：Dio + SigningInterceptor
         lib/data/datasources/**         本地：sqflite / Hive
         lib/data/repositories/**        实现层，在线/离线合流
基础层   lib/core/{auth,router,security,services,sync,theme}
                              │  HTTPS + HMAC-SHA256 签名
                              ▼
FastAPI 0.141.1   main.py（仅装配：app / 中间件 / include_router）
   ├── routers/chat.py        /chat/v2  SSE + 意图解析
   ├── routers/memory.py      /memory/*
   ├── routers/affinity.py    /affinity
   ├── routers/tts.py         /tts  反代 127.0.0.1:8001
   ├── routers/pet.py         /pet/state  /pet/interact      【新增】
   ├── routers/lyrics.py      /lyrics  /lyrics/{id}          【新增】
   ├── routers/music.py       /music/generate  /music/jobs/* 【新增】
   └── routers/legal.py       /legal/*  /user/*
   服务层：agnes_client / emotion_engine / memory_store /
           affinity_store / content_moderation / encryption /
           music_provider.py【新增】/ lyrics_composer.py【新增】/ job_queue.py【新增】
   持久化：db.py（SQLAlchemy Core，SQLite 开发 / MySQL 生产）
        │                         │                        │
        ▼                         ▼                        ▼
  Agnes LLM API           ACE Music API            IndexTTS 微服务
  （对话/歌词）           （音乐生成 ~48s）        （127.0.0.1:8001）
```

### 4.4 音乐生成数据流（异步任务模式，为实测 48.2s 而设计）

```
App                         后端                          ACE Music
 │ POST /music/generate      │                              │
 │  {lyric_id|lyrics,        │  1. 内容过滤                 │
 │   prompt, duration}       │  2. 写 music_jobs(status=queued)
 │                           │  3. BackgroundTasks 派发      │
 │  202 {job_id,             │                              │
 │       poll_after_ms:5000} │  POST /v1/chat/completions    │
 │<──────────────────────────│                              │
 │ GET /music/jobs/{job_id}  │                              │  实测 ~48.2s
 │  （每 3s 轮询，退避 8s）  │                              │
 │  200 {status:"running",   │  200 + data:audio/mpeg;base64│
 │       progress:0.4}       │<─────────────────────────────│
 │                           │  4. 解 base64 → 落盘 F 盘     │
 │                           │     data/audio/<sha1>.mp3     │
 │                           │  5. 写 songs 表 + job=succeeded
 │  200 {status:"succeeded", │                              │
 │       song:{audio_url:    │                              │
 │       "/music/audio/x.mp3"}}                             │
 │<──────────────────────────│                              │
 │ just_audio.setUrl(...)    │                              │
```

参数（全部实测依据）：后端调用超时 180s；前端首次轮询延迟 5s；轮询间隔 3s 起、指数退避至 8s 上限；前端总放弃阈值 240s（放弃后 job 仍在服务端跑）；并发上限单用户 1 running job；去重 `sha1(lyrics + prompt + duration)`。

### 4.5 前端文件落位（移植拆分，单文件硬上限 300 行）

- `chatty_dog_pet.dart`（1097 行）拆 6 文件：`domain/entities/pet_state.dart`、`data/datasources/dog_bark_library.dart`、`widgets/pet/dog_painter.dart`、`widgets/pet/pet_speech_bubble.dart`、`widgets/pet/pet_love_meter.dart`、`widgets/pet/chatty_dog_pet.dart`。
- `pet_studio_page.dart`（1088 行）拆 8 文件：`pages/pet/pet_studio_page.dart`、`widgets/pet/pet_status_bar.dart`、`pages/pet/widgets/creation_studio.dart`、`pages/pet/widgets/lyrics_preview.dart`、`widgets/pet/song_player.dart`、`widgets/pet/pet_chat_bubble.dart`、`pages/pet/widgets/lyrics_library_view.dart`、`pages/pet/pet_fullscreen_page.dart`。
- 新增：`domain/entities/{lyrics,song,music_job}.dart`、`domain/repositories/music_repository.dart`、`data/services/pet_api_service.dart`（Dio）、`data/repositories/music_repository_impl.dart`、`presentation/providers/{pet_provider,music_provider}.dart`、`widgets/app_icon.dart`（图标唯一门面）。

### 4.6 后端依赖收紧（区间锁定）

```
fastapi>=0.141,<0.142   uvicorn[standard]>=0.52,<0.53   pydantic>=2.13,<3.0
httpx>=0.28,<0.29       sqlalchemy>=2.0.51,<2.1         pymysql>=1.2,<1.3
cryptography>=50.0,<51.0  python-dotenv>=1.0,<2.0        pyjwt>=2.8,<3.0
```

---

## 5. API 端点清单

**契约声明**：本章节端点与 `openapi-music-pet.yaml` 逐字一致，该 YAML 为唯一机器可读契约；前端据此生成 Dart 类型，后端据此实现。端点总数以 OpenAPI 为准 = **13 条路径**（任务书「约 8」为 openapi 成型前的估算，特此校正）。竹笌既有 22 个端点（含 `/chat/v2`、`/emotion`、`/memory/*`、`/affinity`、`/tts`、`/livekit/connect`、`/legal/*`、`/user/*`）全部复用，不在此重列。

### 5.1 通用约定

| 项 | 值 |
|---|---|
| Base | `{BackendConfig.baseUrl}`（前端 Hive 持久化，设置页可改） |
| 版本策略 | 不引入 `/api/v1/` 前缀，沿用端点级后缀（与 22 个存量端点一致）。ADR-006 已记录此规范偏离 |
| 认证 | 全部端点走 `auth.verify_request`（app 级 `dependencies`）。头：`X-Api-Key` / `X-Timestamp` / `X-Nonce` / `X-Signature` / `X-User-Id`。签名串 `METHOD\nPATH\nTIMESTAMP\nNONCE\nSHA256(BODY)`，HMAC-SHA256 |
| 用户标识 | 一律从 `X-User-Id` 头注入 `request.state.user_id`；路径中禁止出现 `user_id` |
| 错误体 | `{"detail": "<人类可读描述>"}` |
| 错误码 | 400 参数错 / 401 签名失败或过期或重放 / 403 内容违规 / 404 不存在 / 429 并发或频率超限 / 502 第三方失败 / 503 依赖未就绪 |

### 5.2 新增端点（pet 模块，13 条路径）

| 方法 | 路径 | 功能 | 请求 | 响应 |
|---|---|---|---|---|
| GET | `/pet/state` | 读当前用户宠物状态 | — | `200 {mood,total_barks,songs_created,last_song_title,affinity}` |
| POST | `/pet/interact` | 宠物互动（pet/feed/shake/bark） | `{action}` | `200 {dialogue,mood,affinity_delta,affinity}` / `400` |
| POST | `/lyrics` | 生成并保存歌词 | `{theme,style,mood,additional?,user_mood?}` | `201 {id,title,lyrics,note,theme,style,mood,pet_reaction,created_at}` / `403` / `502` |
| GET | `/lyrics` | 歌词列表（分页 + 筛选） | query `theme?` `style?` `limit=20` `offset=0` | `200 {items,total,limit,offset,has_more}` |
| GET | `/lyrics/{id}` | 歌词详情 | — | `200 {Lyrics}` / `404` |
| PATCH | `/lyrics/{id}` | 改标题 / 标签 | `{title?,tags?}` | `200 {Lyrics}` / `404` |
| DELETE | `/lyrics/{id}` | 软删除歌词 | — | `200 {ok,id}` / `404` |
| POST | `/music/generate` | 提交生成任务（异步） | `{lyric_id?,lyrics?,prompt,duration=30,language="zh"}` | `202 {job_id,status,poll_after_ms:5000}` / `400` / `403` / `429` / `503` |
| GET | `/music/jobs/{job_id}` | 查询任务 | — | `200 {job_id,status,progress,song?,error?,attempt,created_at,finished_at}` / `404` |
| DELETE | `/music/jobs/{job_id}` | 取消排队中任务 | — | `200 {ok,job_id,status:"cancelled"}` / `400` |
| GET | `/music/audio/{filename}` | 取音频文件 | — | `200 audio/mpeg` / `404` |
| GET | `/songs` | 作品列表 | query `limit=20` `offset=0` | `200 {items,total,limit,offset,has_more}` |
| DELETE | `/songs/{id}` | 软删除作品（无引用则删磁盘音频） | — | `200 {ok,id}` / `404` |

关键约束：
- `style` 枚举锁定 5 个：`民谣` / `流行` / `DJ电音` / `国风` / `说唱`；传入枚举外回退 `流行`。
- `MusicJobStatus`：`queued` / `running` / `succeeded` / `failed` / `cancelled`。succeeded 时 `song.audio_url = /music/audio/<sha1>.mp3`。
- `lyric_id` 与 `lyrics` 二者必填其一；同时给出以 `lyric_id` 为准。
- `action` 从 query 改为 body（签名串含 `SHA256(BODY)`，query 不参与签名，留篡改面）。
- 变更端点（3 个，存量）：`POST /chat/v2` SSE 新增 `event: intent`（剥离 `【CREATE_LYRICS】`/`【GENERATE_MUSIC】` 裸标签）；`GET /user/export` 追加 `lyrics`/`songs`；`DELETE /user/data` 追加 `lyrics`/`songs`/`music_jobs` 及磁盘音频。
- 不移植端点（4 个）：`POST /chat`（非流式）、`GET /llm/status`（泄露 has_key）、`GET /history/{user_id}`（路径越权）、`POST /tts/generate` 等（与 `/tts` 契约冲突）。

---

## 6. 数据库表清单

**既有表（复用，竹笌 `db.py`）**：`memories`、`affinity`、`kv`。其中 `memories.content` 与 `affinity.data` 走 `encryption.encrypt` 字段级加密。

**新增表（写入 `db.py`，`init()` 用 `create_all(checkfirst=True)` 幂等建表，无需迁移脚本）**：`pet_state`、`lyrics`、`music_jobs`、`songs`。（任务书点名 `pet_state`/`lyrics`，但 `music_jobs`/`songs` 为音乐端点契约必备，一并锁定。）

### 6.1 新增表 DDL

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

-- 歌词。lyrics_text 与 note 按 memories.content 同规格字段加密
CREATE TABLE lyrics (
    id           VARCHAR(36)  PRIMARY KEY,
    user_id      VARCHAR(128) NOT NULL DEFAULT 'default',
    title        VARCHAR(128) NOT NULL DEFAULT '',
    theme        VARCHAR(128) NOT NULL DEFAULT '',
    style        VARCHAR(32)  NOT NULL DEFAULT '流行',
    mood         VARCHAR(32)  NOT NULL DEFAULT 'happy',
    lyrics_text  TEXT         NOT NULL,   -- encryption.encrypt
    note         TEXT,                     -- encryption.encrypt
    tags         TEXT,                     -- JSON 数组字符串，兜底 '[]'
    created_at   VARCHAR(32)  NOT NULL,
    updated_at   VARCHAR(32)  NOT NULL,
    deleted_at   VARCHAR(32)
);

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
```

### 6.2 索引清单（新增）

| 表 | 索引 | 用途 |
|---|---|---|
| lyrics | `idx_lyrics_user_created (user_id, created_at DESC)` | 按用户时间倒序翻页 |
| lyrics | `idx_lyrics_user_style (user_id, style)` | 按风格筛选 |
| music_jobs | `idx_jobs_user_created (user_id, created_at DESC)` | 任务翻页 |
| music_jobs | `idx_jobs_status (status)` | 捞 running / 清理 stale |
| songs | `idx_songs_user_created (user_id, created_at DESC)` | 作品翻页 |
| songs | `idx_songs_sha1 (audio_sha1)` | 去重查询 |

设计取舍（已确认）：`lyrics_text` 加密 → 失去全文检索，MVP 仅按 `theme`/`style`/`时间` 筛选；主键 `VARCHAR(36)` UUID 便于离线先生成；时间字段 `VARCHAR(32)` ISO8601 与现状一致；软删除 `deleted_at` 置位；不建 `users` 表（沿用 `X-User-Id` 设备标识）。

### 6.3 存储变更

| 位置 | 变更 | 约束 |
|---|---|---|
| `F:/zhuyapp-backend/data/audio/` | 新建，存音乐 MP3 | 路径根取 `settings.DATA_DIR`，天然在 F 盘；`.gitignore` 内容为 `*` |
| `F:/zhuyapp-backend/models/` | 新建，存 TTS 权重 | 经 `MOSS_TTS_MODEL_DIR` 环境变量指向；`.gitignore` 排除 |
| `F:/zhuyapp/assets/icons/lucide/` | 新建，约 34 个 SVG | `pubspec.yaml` 的 `assets:` 需逐目录列出（本环境 Flutter 不递归子目录） |
| `.dockerignore` | 追加 `data/audio/`、`models/` | 防镜像膨胀 |
| 前端本地库 | 不新增 sqflite 表 | 歌词/作品以服务端为单一事实源；离线只读缓存放 Hive `songs_cache` box |

---

## 7. 页面清单（全量重设计 13 页）

> 路由以 `architecture.md` §4.1.2 为准：`/pet` 为模块主页（含 创作台 / 歌词库 / 宠物 三态），`/pet/full`、`/pet/library` 为独立路由。DESIGN.md 的 `/music` 即本处 `/pet` 模块。

| # | 路由 | 页面 | 设计稿 | 一句话设计方向 |
|---|---|---|---|---|
| 1 | `/splash` | 启动页 | DESIGN#1 | 竹笋破土生长微动画 + 品牌字 reveal，≤300ms 过渡，不堆标语 |
| 2 | `/home`（=`/chat`） | 首页·聊天陪伴 | DESIGN#2 | 信纸式对话 + 3D 竹笌同屏；下信纸气泡流、底部语音优先输入、情绪芯片悬浮 |
| 3 | `/pet` | 音乐狗子主页 | DESIGN#3 + #11-13 | 狗子居中 + 底部三态切换（创作台/歌词库/宠物），竹绿×暖橙声场，录音/生成用 `--ember` 脉冲 |
| 4 | `/pet/full` | 宠物全屏页 | arch§4.1.2 | PetAloneScreen + 空状态引导 |
| 5 | `/pet/library` | 歌词库独立页 | arch§4.1.2 | 歌词卡片列表，mono 时间轴，点击展开编辑 |
| 6 | `/discover` | 发现·竹林 | DESIGN#4 | 沉浸竹林背景（CustomPaint 竹柱）+ 左下吉祥物入口，去 tab、大留白 |
| 7 | `/avatar` | 3D 角色页 | DESIGN#5 | 全屏角色互动：表情/换装/背景，用 `--accent-soft` 面板 |
| 8 | `/voice` | 实时语音通话 | DESIGN#6 | LiveKit 全屏 + 实时波形（mono 标签时间轴），挂断键 `--danger` 暖红圆钮 |
| 9 | `/profile` | 我的 | DESIGN#7 | 统一竹系（弃用旧米棕）；头像 + 收藏/模块/设置分组（Linear 密度） |
| 10 | `/settings` | 设置 | DESIGN#8 | 分组列表（外观/账号/数据/关于），右侧 ChevronRight，切换用 `--accent` 开关 |
| 11 | `/settings/memory` | 记忆历史 | DESIGN#9 | 时间线式记忆流，空状态有引导文案 + 操作钮 |
| 12 | `/settings/modules` | 模块信息 | DESIGN#10 | 已启模块卡片（竹笌/狗子），`--accent-soft` 标识开启态 |
| 13 | `/pet` 宠物态（「宠物」三态） | 宠物状态视图 | DESIGN#13 | 狗子 mood（Lucide `Smile` 等）+ loveMeter 进度条用 `--sun`，去粉去 emoji（路由复用 `/pet`） |

**导航约束**：复用竹笌既有底部三段式（首页/发现/我的），音乐狗子入口挂在 `/discover` 竹林一角与 `/profile` 卡片；不新增 BottomNavigation，备份分支自制导航整份丢弃。

---

## 8. 设计 Token

**完整定义见 `design-tokens.json`**（本 Spec 仅摘录锁定项）。所有组件禁止硬编码色值，一律引用以下 Token；唯一例外 `#FFFFFF`/`#000000` 仅用于纯白描边 / 纯黑遮罩。

### 8.1 配色（竹绿 + 暖橙双主色系）

| Token | 浅色 | 深色 | 用途 |
|---|---|---|---|
| `--bg` | `#F1F6EE` 竹雾 | `#0E1512` 深竹黑 | 页面背景（深色为竹调深，非紫调 `#1A1A2E`） |
| `--surface` | `#FFFFFF` | `#16201B` | 卡片/容器 |
| `--surface-warm` | `#FBF4E9` 暖米 | `#1E1A14` 暖深 | 音乐狗子/我的页暖区 |
| `--surface-sunken` | `#E9F0E5` | `#0A0F0D` | 输入框/凹陷区 |
| `--fg` | `#1E2B1E` 竹墨 | `#E8F0E4` | 主文本 |
| `--fg-2` | `#44563F` | `#B6C4AE` | 次级文本 |
| `--muted` | `#6E7C68` | `#859384` | 辅助/说明 |
| `--border` | `#DDE6D8` | `#253029` | 默认 1px 边框 |
| `--accent` | `#7CB342` 竹绿 | `#8BD14F` 亮竹 | 品牌主色：按钮/图标/Logo/发送键 |
| `--accent-deep` | `#4E7C2A` 深竹 | `#5E9E2E` | 竹底文字、按下态 |
| `--accent-soft` | `#E8F3DE` | `#1C2A17` | 选中/高亮底（chip、active tab） |
| `--sun` | `#F2A33C` 暖金 | `#F4B454` | 音乐狗子能量色 + 用户气泡 |
| `--sun-soft` | `#FCEBD2` | `#2A2113` | 暖区底 |
| `--ember` | `#FF7A45` 暖珊瑚 | `#FF8A5C` | 音乐动作色（录音/生成/播放），暖橙非粉 |
| `--ember-soft` | `#FFE3D6` | `#2A1813` | 动作态底 |
| `--success` | `#4CAF50` | `#5FBF63` | 成功/在线 |
| `--warn` | `#E0A106` | `#E8AE1C` | 警告 |
| `--danger` | `#C1463B` | `#D96458` | 错误/挂断（暖红，非粉） |
| `--info` | `var(--accent)` | `var(--accent)` | 信息 |

### 8.2 图标（锁 Lucide）

- 库：`lucide`（`lucide.dev`，ISC 许可）。自托管于 `assets/icons/lucide/<kebab-case-name>.svg`。
- 门面：`lib/widgets/app_icon.dart` 暴露 `AppIcon(name: AppIcons.music, size: 24, color: ...)`；名称常量表 `lib/widgets/app_icons.dart`。
- 尺寸：行内 16px / 按钮内 20px / 导航 24px；描边 1.75（16px）/ 2（20–24px），`stroke-linecap: round`，`currentColor`。
- MVP 图标清单（约 34 个）：`house` `compass` `user` `message-circle` `mic` `phone` `settings` `chevron-left` `chevron-right` `x` `check` `plus` `trash-2` `pencil` `search` `music-4` `play` `pause` `square` `volume-2` `volume-x` `download` `share-2` `heart` `dog` `bone` `hand` `sparkles` `lightbulb` `library` `tag` `clock` `loader` `triangle-alert`。
- 迁移映射示例：旧 `Icons.music_note` → `Music`；旧 `Icons.pets` → `Dog`；旧 `Icons.arrow_back` → `ArrowLeft`；旧狗子/爱心/笑脸 emoji 字面量 → `Dog`/`Heart`/`Smile` 线图标。

### 8.3 字体

```css
--font-display: "Smiley Sans", "Inter", "Noto Sans SC", sans-serif; /* 少年系 punchy 短标题，稀疏使用 */
--font-body:    "Inter", "Noto Sans SC", sans-serif;                /* 正文/英文/数字 */
--font-mono:    "JetBrains Mono", "Space Mono", monospace;          /* 歌词时间轴/波形标签/技术态 */
```
字阶 8 级（xs12 / sm14 / base16 / md18 / lg20 / xl24 / 2xl32 / 3xl40，Hero 可到 48 用 display）；圆角上限 16px（`--radius-lg`）；间距 4px 网格；动效 ≤200ms（`--motion-base`），`prefers-reduced-motion` 关闭非必要动画。

---

## 9. 验收标准（EARS 格式）

**EARS-01（普遍型）** 系统应在每次用户完成一次陪聊对话后，将对话摘要写入记忆历史并刷新五维好感度。

**EARS-02（事件驱动）** 当用户在音乐狗子创作台提交「生成音乐」请求时，系统应在 1 秒内返回 `job_id` 与 `poll_after_ms`，且不在前端同步阻塞等待生成结果。

**EARS-03（状态驱动）** 当音乐生成任务处于 `running` 状态时，系统应在创作台展示波形骨架（而非转圈死等），并每 3 秒轮询一次任务状态，直至 `succeeded` 或 `failed`。

**EARS-04（ unwanted behavior）** 若 `ACE_MUSIC_API_KEY` 未配置或 ACE Music 上游失败，则系统应返回 HTTP 503（音乐生成）或 502（歌词生成），且不静默降级为模板假歌词 / 假音频。

**EARS-05（事件驱动 + unwanted）** 当宠物互动接口 `POST /pet/interact` 收到非法 `action` 时，系统应返回 HTTP 400 并给出可读错误；当收到合法 `action` 时，系统应返回狗子台词（纯文本、不含 emoji）、更新 mood 并回写五维好感度。

**EARS-06（状态驱动）** 当音乐作品播放进行中时，系统应让狗子宠物随播放进度产生节拍律动与暖橙发光脉冲（使用 `--ember` 暖橙，非粉色），且不得与 TTS 播报争抢音频焦点（单一 `just_audio` 实例）。

**EARS-07（普遍型 · 红线）** 系统应在所有功能界面使用 Lucide SVG 图标（经 `AppIcon` 门面），且全项目 `Icons.*` / `CupertinoIcons.*` / emoji 字面量出现次数应为 0。

**EARS-08（ unwanted · 红线）** 若界面需要使用强调渐变，则系统应使用竹绿单色或同色系深浅渐变；系统不得在任何页面渲染紫(`#7C3AED`)→粉(`#EC4899`)跨色相渐变，且深底应为竹调深 `#0E1512` 而非紫调 `#1A1A2E`。

**EARS-09（ unwanted · 红线）** 若页面处于空状态或引导态，则系统应展示具体可行动文案与操作按钮（如「3 分钟写下你的第一首歌」），且不得出现 "Welcome to" / "Lorem ipsum" / "赋能" 等模板占位文案。

**EARS-10（普遍型 · 安全）** 系统应在所有后端请求（含新增 13 个音乐端点）强制 HMAC-SHA256 签名鉴权；当签名失败、过期或重放时，系统应返回 HTTP 401，且用户标识仅从 `X-User-Id` 头注入，不得出现在 URL 路径中。

**EARS-11（状态驱动 · 持久化）** 当生产环境 `DATABASE_URL` 指向 MySQL 时，系统应将歌词与宠物状态写入该数据库（经 `db.py`），且不得静默落到本地 `sqlite3` 文件导致数据丢失。

---

## 10. 边界与约束

### 10.1 磁盘与算力（C 盘禁装）
- 音频 `/data/audio/`、模型 `F:/zhuyapp-backend/models/`、第三方缓存（`HF_HOME`/`MODELSCOPE_CACHE`/`TORCH_HOME`）一律显式指向 F 盘；**禁止任何产物落 C 盘**。
- F 盘余量 790 GB（实测），音频约 0.46MB/30s，按 1000 首/月 ≈ 460MB/月，可支撑数年。
- 本地自托管音乐模型（C4）MVP 不可行：开源模型需 GPU 推理，本机无保障，算力是瓶颈而非磁盘。

### 10.2 ACE 云端音乐（本机零新增模型）
- 音乐生成 100% 走云端 ACE Music，后端异步 job 代理；前端绝不直连、绝不同步代理。
- 密钥仅服务端 `os.getenv("ACE_MUSIC_API_KEY")` 且无默认值；未配置返 503，不静默降级。
- 上游返回 base64 data URI，后端解码落盘为 `/music/audio/<sha1>.mp3` 常规 HTTP 路径，绝不向客户端下发 `data:` scheme。

### 10.3 P0 绝对规则（违反即退回，全团队遵守）
1. **图标一律 Lucide SVG**，经 `AppIcon` 门面；全项目禁止 `Icons.*` / `CupertinoIcons.*` / emoji 字面量 / `IconData` 直接构造。emoji 仅允许出现在用户 UGC 文本。
2. **禁止紫粉渐变**：严禁 `#7C3AED→#EC4899` 及 Indigo→Pink 作主视觉；仅允许竹绿单色或同色系深浅渐变；深底必须为竹调深 `#0E1512`。
3. **禁止模板文案**：禁 "Welcome to" / "Get started" / "Seamless" / "Lorem ipsum" 及中文「赋能」「一站式」空话；空状态须具体可行动。
4. **禁止硬编码颜色**：全部引用 `AppTheme` / `design-tokens.json` 令牌；废弃 `Color(0x...)` / `Colors.*` 直用。
5. **禁止过度设计**：禁千篇一律居中 Hero（DESIGN_VARIANCE=5 强制左对齐/非对称留白）、侧条纹彩条、渐变文字、卡片 ≥24px 圆角、幽灵卡片（1px 边框 + blur≥16 阴影同元素）。
6. **组件 5 态必覆盖**：Default / Hover / Focus(`--focus-ring`) / Active / Disabled / Loading / Error(具体文案+重试) / Empty(引导+操作) / Success(短暂 toast)。

### 10.4 CI 门禁（落地即生效）
- `grep -rn "Icons\.\|CupertinoIcons\.\|Color(0x" lib/ --include=*.dart`（`app_theme.dart` 白名单）必须为 0。
- emoji 字面量扫描为 0（UGC 文本除外，靠上下文豁免）。
- 密钥扫描（`gitleaks` 或等价）阻断提交；源码内 `grep -rn "sk-\|c2fa5ed9" .` 为 0。
- 单文件 ≤300 行（待移植文件拆分后校验）。
- 新增 `flutter_svg` 后 `flutter pub get` 必须 diff 确认 `dependency_overrides` 段与 `pubspec.lock` 中 `model_viewer_plus` 解析路径未变。

---

## 11. 内嵌已知坑（从三文档提取，表格化）

> 完整风险寄存器 R-01~R-20 见 `architecture.md` §8。下表为 Spec 必须内嵌的硬约束级坑，按任务书点名的 4 项（密钥泄漏 / 3D 冲突 / 宠物无鉴权 / P0 合规债）为牵引，补齐其余 P0/P1 关键项。

| 编号 | 坑（现象） | 取证 | 影响 | 进入 Spec 的硬约束（处置） |
|---|---|---|---|---|
| K-01（R-01） | **ACE / AGNES 硬编码密钥已泄露且当前有效**（任务书 R1） | `backend/pet_api.py` 硬编码 ACE 默认值；`config.py:20` AGNES 明文写死；实测携 ACE 密钥返 HTTP 200 产真实音频（E-11） | 任何人可消耗额度并计费到本项目 | 1) 两密钥立即上游轮换；2) 全改 `os.getenv(...)` 无默认值，未配置返 503；3) 加密钥扫描 CI 阻断再次提交 |
| K-02（R-02） | 上游返回 base64 data URI 无法播放 | 响应 `audio_url.url` 以 `data:audio/mpeg;base64,` 开头（641KB），前端却用 `UrlSource` 播（E-13/E-14） | 「生成成功但点播放没声音」且不报错，最难排查 | 后端解 base64 → 落盘 → 回传常规 HTTP URL；前端严禁把 `data:` 交播放器 |
| K-03（R-03） | 48.2s 同步等待 + 前端无超时 | 实测 `time_total:48.2s`（E-12）；`http.Client()` 未设 timeout | 点生成后 UI 无反馈近 1 分钟，弱网挂到系统级超时 | 走异步 job + 轮询；所有前端网络调用强制 Dio `connectTimeout`/`receiveTimeout` |
| K-04（R-04） | 备份分支携带 957MB 二进制 | `git ls-tree` 合计 956.99MB，单文件 `qwen2.5-0.5b` 942MB（E-18）；`.git` 已 1.6GB | `git merge` 会把 blob 永久并入主线 | **严禁 `git merge`**；只允许 `git show <branch>:<path> > <target>` 逐文件取文本；模型权重走 `.gitignore` + 下载脚本 |
| K-05（R-05 / 任务书 R5） | **宠物端点原无鉴权**（裸调 http 绕过签名） | 后端 `FastAPI(dependencies=[Depends(auth.verify_request)])` 全局强制（E-08）；`PetApiService` 仅带 `Content-Type`（E-07） | 本地能跑、生产全 401 的「本地能跑线上全红」 | 改走 Dio + `SigningInterceptor`；`baseUrl` 取 `BackendConfig.instance.baseUrl`；废弃 `PET_API_URL` 编译期常量；集成测试用非空 Key 跑通全端点 |
| K-06（§4.3 / R-06 / 任务书 R3） | **两套 3D 方案冲突（误判）→ 狗子用 2D 贴图** | 竹笌用 `model_viewer_plus`(GLB) + Live2D(vendored)；音乐狗子狗是纯 `CustomPainter` 2D（E-04/05/06），零 3D 依赖 | 误判会导致无谓返工 | 实测结论：**不冲突**，狗子本就是 2D 矢量，零第三方渲染依赖；架构约束「同路由最多一个重型渲染视图」（Live2D/ModelViewer/全屏 CustomPainter 动画互斥），`/pet` 仅用 CustomPainter 天然满足 |
| K-07（R-09） | 越权读取任意用户数据 | 原 `@app.get("/pet/state/{user_id}")` / `/history/{user_id}`（E-28） | 任意人可读任意用户 | 新端点路径禁止 `user_id`，一律 `X-User-Id` 头注入；两原端点不移植 |
| K-08（R-10） | 宠物状态与好感度双体系冲突 | 音乐狗子内存字典 + 单一 `love:float`（E-27）；竹笌 `affinity` 五维加密（E-24） | 两套好感度打架 | 落库 `pet_state` + 语义收敛：互动写 `affinity`（`pet`→intimacy、`feed`→trust、`bark`→familiarity），不新建体系 |
| K-09（R-11） | 待移植文件全部严重超长 | `chatty_dog_pet.dart` 1097 行、`pet_studio_page.dart` 1088 行（E-20） | 单文件不可维护 | 按 §4.5 落位表拆分，**单文件硬上限 300 行**，超限不得放行 |
| K-10（R-12 / 任务书 R8） | **P0 合规债（emoji + 硬编码色）需 port 同时清洗** | 移植代码 28 处 `Color(0x` + 16 处 emoji；竹笌存量 7 文件 emoji + 61 处 `Icons.*`（E-21/E-22） | 新旧混用视觉更糟 | 按 §4.5 + DESIGN §6 清单一次性清理（范围含竹笌存量债）；加 CI 检查，违反即退回 |
| K-11（R-13） | 歌词库在 MySQL 生产环境静默丢数据 | `lyrics_store.py` 裸 `sqlite3.connect` vs `db.py` 支持 `DATABASE_URL` 切 MySQL（E-24/25） | 容器重建即丢失且无声 | 并入 `db.py`（选型 E），不保留任何裸 `sqlite3` 调用 |
| K-12（R-08） | 语音能力当前实际为零 | IndexTTS venv 缺 torch/fastapi/indextts；MOSS-TTS 权重是 LFS 指针（E-15/16/17） | 语音能力为 0 | **需项目总监裁决**（R-08）：补 MOSS-TTS-Nano ONNX（轻、无 torch）或续下 IndexTTS；`/tts` 返 503 时前端静默降级纯文字为常态兜底 |

---

## 12. 端到端验证步骤

> 验证前置：密钥已轮换并写入 `.env`（`ACE_MUSIC_API_KEY` / `AGNES_API_KEY`）；`DATA_DIR` 指向 F 盘；`flutter pub get` 后 `dependency_overrides` 未变；`db.py` 已 `create_all`。

**步骤 1 · build（前端）**
1. `cd F:/zhuyapp && flutter pub get` → 确认 `model_viewer_plus` 本地补丁解析路径未变。
2. `flutter analyze` → `Icons.*`/`CupertinoIcons.*`/`Color(0x` 扫描为 0；无文件超 300 行。
3. `flutter build apk`（或 `flutter run`）→ 启动进入 `/splash`，竹笋破土动画 ≤300ms 过渡到 `/home`。

**步骤 2 · 启动（后端）**
1. `cd F:/zhuyapp-backend && uvicorn main:app --reload` → `main.py` 装配 ≤120 行，`include_router` 挂载 8 个 router。
2. `GET /health` 免签返回 200；`GET /`（根）返回 200。
3. 用**非空 `ZHUYU_API_KEY`** 启动，确认全局签名中间件生效（无签名头访问任意端点应 401）。

**步骤 3 · 陪聊流（既有闭环）**
1. `/home` 输入文字/语音 → `POST /chat/v2` SSE 流式，首字 ≤1.5s。
2. 每轮 `POST /emotion` 产出情绪芯片；`/memory/*` 时间线可查；`GET /affinity` 五维增长。
3. 点 3D 竹笌 → `/avatar` 全屏；点麦克风 → `/voice`（不可用时降级）。

**步骤 4 · 音乐创作流（新增闭环）**
1. `/discover` 或 `/profile` 点狗子入口 → `/pet`，切「创作台」。
2. `POST /pet/interact {action:"pet"}` → 200 返台词（纯文本无 emoji）+ mood + affinity_delta；`GET /pet/state` 验证 `total_barks` 增长。
3. `POST /lyrics {theme,style:"民谣",mood}` → 201 返歌词；`GET /lyrics` 列表可见。
4. `POST /music/generate {lyric_id, prompt, duration:30}` → 202 返 `job_id` + `poll_after_ms:5000`。
5. 5s 后 `GET /music/jobs/{job_id}` 每 3s 轮询 → `running` 时创作台显示波形骨架 → `succeeded` 得 `audio_url:/music/audio/<sha1>.mp3`。
6. `just_audio` 播放 → 狗子随节奏律动 + `--ember` 暖橙脉冲；播放不抢 TTS 焦点。
7. 宠物状态/好感回写；`GET /songs` 我的作品可见；`/pet/library` 歌词库可查可编辑。
8. 重复相同参数 → `sha1` 命中直接返回既有 song（去重验证）。

**步骤 5 · 错误流（红线验证）**
1. 未配置 `ACE_MUSIC_API_KEY` → `POST /music/generate` 返 **503**（非假数据）。
2. ACE 上游失败 → 同样 503；歌词上游失败 → `POST /lyrics` 返 **502**（非模板假歌词）。
3. `POST /pet/interact {action:"fly"}` → **400** 可读错误。
4. 无签名头访问任意音乐端点 → **401**。
5. 单用户已 1 running job 时再提交 → **429**。
6. 任意页面空状态 → 具体引导文案 + 操作钮（无 "Welcome to" / "Lorem"）；全应用图标均为 Lucide（无 emoji、无紫粉渐变、无色值硬编码）。

---

## 13. 变更记录

| 版本 | 日期 | 变更 | 关联 |
|---|---|---|---|
| v1.0 | Phase 1.5 | 初始规格契约：合并 PRD/架构/DESIGN/Token/OpenAPI 为单一事实源 | 源文档均已确认 |
| — | — | **待确认项 1**：后端 Python 版本。任务书「3.11.13」与确认架构「主后端 3.13.14」冲突；本书锚定 3.13.14，TTS venv 3.11.13。请总监裁决是否需主后端降级 | §4.1 |
| — | — | **待确认项 2**：端点数量。任务书「约 8」/PRD「8」/架构头「12」/OpenAPI 实际「13 路径」；本书以 OpenAPI 13 路径为锁定契约 | §5.2 |
| — | — | **待确认项 3**：R-08 TTS 实现选型（MOSS-TTS-Nano ONNX vs IndexTTS 2.5），需总监裁决 | §11 K-12 |
| — | — | **待确认项 4**：是否为新端点引入 `/api/v1/` 前缀（本书沿用无前缀，ADR-006 已记录偏离） | §5.1 |

---

*本 Spec 为 Phase 1.5 冻结基线。任何偏离须走变更流程：更新本文件 + 同步 `openapi-music-pet.yaml` + 通知前端/后端 Agent + 项目总监裁决。下游开发以本文件与 OpenAPI 为准，不得各自解读。*

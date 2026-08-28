# 竹笌 × 音乐狗子 合并重设计 · 产品需求文档（PRD）

| 项 | 值 |
|---|---|
| 文档版本 | v1.0（Phase 1 MVP） |
| 编制 | 产品经理（许清楚） |
| 状态 | 待项目总监（大湾区靓仔）裁决冻结 |
| 基底仓库 | `F:/zhuyapp` @ `main`（竹笌整体 App） |
| 新增模块来源 | `zhuyapp` @ `zhuyu-frontend-backup` 的 `frontend/lib/modules/pet/`（音乐狗子） |
| 后端基底 | `F:/zhuyapp-backend`（FastAPI，全局签名鉴权） |
| 关联文档 | `竹笌x音乐狗子-合并重设计-技术架构文档.md`、`openapi-music-pet.yaml`、`phase1/DESIGN.md`、`phase1/design-tokens.json` |
| 调研方式 | 全部结论基于实读源码 / 实测命令 / 实测网络请求，无一条来自推测 |

---

## 1. 一句话产品定义、目标用户、核心问题

**产品定义（一句话）**：竹笌是一款以「竹系少年感 3D 角色 + 语音优先陪伴」为基底的 AI 陪伴 App；本次合并把音乐狗子作为内置音乐模块接入，让用户在与 3D 角色（竹笌 / 狗子）对话陪伴的同时，能用自然语言一句话生成属于自己的原创歌曲，并让宠物随音乐节奏律动。

**目标用户**

- 主要画像：18–28 岁、爱用语音聊天的 Z 世代内容消费者；日常有「想有人陪聊 / 想写歌但零乐理」两类轻诉求，却不愿分别装两个 App。技术水平中等，习惯微信/抖音式交互，对"角色在场感"敏感。
- 次要画像：UGC 音乐爱好者与情绪记录者——他们想把心情写成歌词、把日常变成一首歌，并看到宠物对自己的"好感"随时间增长。
- 非目标画像：专业音乐制作人（需要 DAW/多轨混音，非本产品定位）；纯工具型效率用户（无陪伴诉求）。

**核心问题（用户真实痛点，而非用户嘴上说的方案）**

- 用户嘴上说「我要一个会写歌的宠物」→ 真实需求是「在陪伴场景里，用最低门槛把情绪变成可分享的音乐作品，并获得宠物反馈的陪伴感」。
- 用户嘴上说「把两个 App 合并」→ 真实需求是「在一个连贯的语音陪伴空间里，聊天和创作不是割裂的两件事，而是同一个角色人格的延伸」。
- 现有拆点：竹笌有成熟的语音陪聊 / 3D 角色 / 记忆 / 好感度，但缺创作出口；音乐狗子有宠物对话 + 音乐生成，但它是独立分支、裸调后端、无签名、无持久化、密钥硬编码、体验割裂。两者合并要解决的是「陪伴有温度但无表达出口，创作有出口但无陪伴温度」的错位。

---

## 2. 已确认合并决策

以下决策为本次合并的硬前提，研发团队不得擅自推翻：

| 编号 | 决策项 | 结论 | 理由（取证） |
|---|---|---|---|
| D-01 | 整体 App 归属 | **竹笌 = 整体 App**（基底 `F:/zhuyapp` @ `main`） | 竹笌是完整可运行 App（10 条路由、Riverpod、go_router、设计令牌齐全）；音乐狗子是 `frontend/lib/modules/pet/` 下的功能子集（E-01、E-02） |
| D-02 | 音乐狗子定位 | **音乐狗子 = 竹笌内的新增音乐模块**，非独立 App | 作为 `/music`（`/pet` 等）路由寄生在竹笌导航内，复用竹笌底部三段式（首页/发现/我的），不新增 BottomNavigation（架构文档 4.1.2） |
| D-03 | 基底选择 | **以竹笌为基底**，音乐狗子代码按规则移植 | 竹笌后端鉴权、状态管理、设计令牌更完整；音乐狗子侧的 `package:http` 裸调、内存态宠物、裸 sqlite 均为待整改债（E-07、E-27、E-25） |
| D-04 | 设计策略 | **全量重设计**，统一到竹系视觉母体 | 旧音乐狗子纯橙 `#FFF8F0` 体系并入 `surface-warm` + `--sun`/`--ember`；两套视觉语言同屏会割裂（DESIGN.md 第 0 章） |
| D-05 | 后端整合 | **后端一并整合**：复用竹笌 FastAPI 后端，音乐端点新增 8 个，不另起服务 | 竹笌后端已 22 端点 + 全局签名；音乐狗子 `backend/` 957MB 二进制（Qwen2.5-0.5B + MOSS-TTS LFS 指针）非音乐模型，且密钥硬编码（E-10~E-18） |
| D-06 | 音乐生成方式 | **走云端 ACE Music**（后端异步 job 代理），不本地部署模型 | 实测 48.2s 第三方生成；前端直连必泄露密钥；本地自托管需 GPU，本机无保障（架构文档选型 C） |
| D-07 | 图标方案 | 锁定 `flutter_svg` + Lucide SVG 资产 + `AppIcon` 门面，**全项目 82 处统一迁移** | 竹笌 61 处 `Icons.*` + 移植 21 处，混用比原状更糟（架构文档选型 A） |
| D-08 | 状态管理 | 锁定 Riverpod，移植代码 10 处 `setState` 迁入 Notifier | 宠物情绪需跨页（聊天页与宠物页）共享（架构文档选型 B） |
| D-09 | 音频播放 | 锁定 `just_audio`，废弃 `audioplayers` | 避免 Android 双播放器实例争抢音频焦点（架构文档选型 D） |
| D-10 | 持久化 | 歌词/作品并入 `db.py`（SQLAlchemy Core），废裸 sqlite；宠物状态落 `pet_state` 表 | 生产切 MySQL 时裸 sqlite 静默丢数据（E-25，架构文档选型 E） |
| D-11 | 好感度体系 | **不新建**：音乐狗子宠物互动写入竹笌既有五维 `affinity` | 避免两套好感度打架；`pet`→intimacy、`feed`→trust 等映射（架构文档 4.2.1 改造三） |

---

## 3. 合并后功能清单（RICE 排序）

评分公式：`Score = (Reach × Impact × Confidence) / Effort`。Reach 1–10（每季度受影响用户比例）；Impact 0.25/0.5/1/2/3；Confidence 50%/80%/100%；Effort 1–10（人月）。

### 3.1 竹笌既有能力（合并后保留并强化）

| 功能 | Reach | Impact | Conf | Effort | Score | MVP |
|---|---|---|---|---|---|---|
| 信纸式陪聊（3D 竹笌同屏 + 流式对话） | 10 | 3 | 100% | 8 | 3.75 | 是 |
| 记忆系统（时间线式记忆流，`/memory-history`） | 7 | 2 | 100% | 4 | 3.50 | 是 |
| 情绪系统（对话情绪芯片 + 角色情绪反馈） | 7 | 1.5 | 100% | 3 | 3.50 | 是 |
| 好感度五维（trust/intimacy/familiarity/...） | 7 | 1 | 100% | 3 | 2.33 | 是 |
| 实时语音通话（LiveKit 全屏角色 + 波形） | 8 | 2 | 100% | 6 | 2.67 | 是 |
| TTS 语音合成（`/tts` → `audio/wav`） | 8 | 2 | 80% | 5 | 2.56 | 是（需先修 IndexTTS 微服务） |
| 3D 角色页（`/avatar` 表情/换装/背景） | 6 | 1 | 100% | 5 | 1.20 | 否（强化项） |

### 3.2 音乐狗子新增模块功能点

| 功能 | Reach | Impact | Conf | Effort | Score | MVP |
|---|---|---|---|---|---|---|
| 宠物对话（狗子台词 + 情绪反应，纯文本无 emoji） | 8 | 2 | 80% | 5 | 2.56 | 是 |
| 歌词展示 / 歌词库（Suno 式时间线，mono 字阶） | 7 | 2 | 90% | 4 | 3.15 | 是 |
| 音乐生成（自然语言 prompt + 歌词 → ACE Music 异步生成） | 8 | 3 | 90% | 8 | 2.70 | 是 |
| 宠物状态 / 好感（mood + loveMeter，写入五维 affinity） | 7 | 1.5 | 90% | 3 | 3.15 | 是 |
| 随音乐节奏律动（播放时狗子节拍律动 + 暖橙发光脉冲） | 7 | 1.5 | 80% | 4 | 2.10 | 是（轻量，含在模块内） |

### 3.3 MVP 范围（Phase 1 必交付）

**MVP = 竹笌核心闭环 + 音乐狗子核心创作闭环**，二者共享同一角色人格与好感度体系：

1. 竹笌陪聊（3D 角色同屏 + 流式对话 + 记忆 + 情绪 + 好感度）
2. TTS / 语音通话（需先修复 IndexTTS 微服务，否则 503 静默降级为纯文字）
3. 音乐狗子：宠物对话 → 歌词生成与展示 → 音乐生成（异步 job）→ 播放 → 宠物状态/好感回写

**进 Backlog（非 MVP）**：3D 角色页深度换装玩法、发现页竹林沉浸式社交、多宠物/多角色人格切换、音乐作品社交分享裂变、本地自托管音乐模型（需 GPU 节点，前置条件见架构文档选型 C4）。

---

## 4. 信息架构（页面 / 模块划分）

### 4.1 顶层导航（竹笌既有三段式，音乐狗子作为模块入口嵌入）

```
竹笌 App
├── 底部 TabBar（≤4 项，不新增）
│   ├── 首页 / 聊天陪伴   → /home（= /chat，信纸式对话 + 3D 竹笌同屏）
│   ├── 发现 · 竹林       → /discover（沉浸竹林背景 + 左下吉祥物入口 + 狗子入口卡片）
│   └── 我的             → /profile（头像 + 收藏/模块/设置分组）
│
├── 一级页面（既有）
│   ├── /avatar          3D 角色页（表情/换装/背景，--accent-soft 面板）
│   ├── /voice           实时语音通话（LiveKit 全屏 + 实时波形，挂断键暖红圆钮）
│   ├── /settings        设置（外观/账号/数据/关于）
│   ├── /settings/memory 记忆历史（时间线式，空状态有引导文案）
│   ├── /settings/modules 模块信息（竹笌/狗子开启态）
│   ├── /legal           法律
│   └── /info            信息
│
└── 音乐狗子模块（新增，3 条路由）
    ├── /pet  (/music)   音乐狗子主页：狗子 3D 宠物居中 + 底部三态切换
    │                    ├── 创作台（左 prompt 输入 + 右生成结果，快捷语 chip 暖色）
    │                    ├── 歌词库（歌词卡片列表，mono 时间轴，点击展开编辑）
    │                    └── 宠物（狗子 mood + loveMeter 进度条暖色，去粉去 emoji）
    ├── /pet/full        宠物全屏页（_PetAloneScreen + 空状态引导）
    └── /pet/library     歌词库独立页
```

### 4.2 模块内信息架构原则

- **角色即导航**：3D 竹笌（聊天陪伴）与 3D 狗子（音乐）是两大活体入口，不是装饰；点击狗子进 `/pet`，点击竹笌进全屏 `/avatar`。
- **单一视觉母体**：所有页面共用竹绿主色 + 暖色点缀，禁止第二套独立配色。
- **不新增 BottomNavigation**：音乐狗子入口挂在 `/discover` 竹林一角与 `/profile` 卡片，复用竹笌既有三段式，备份分支自制导航整份丢弃。

### 4.3 目录划分（前端，合并后）

```
lib/
├── core/         (auth/router/theme/security/services/sync)  —— 既有，承载签名与令牌
├── domain/       entities: lyrics.dart / song.dart / music_job.dart + repositories
├── data/         services: pet_api_service.dart(Dio) / repositories: music_repository_impl.dart
├── presentation/ providers: pet_provider.dart / music_provider.dart（含 job 轮询）
├── pages/
│   ├── chat/ home/ voice/ avatar/ discover/ profile/ settings/  —— 既有，全量重设计
│   └── pet/     pet_studio_page.dart / pet_fullscreen_page.dart / pet 子组件
└── widgets/      app_icon.dart（图标唯一门面）/ pet/ 系列组件
```

---

## 5. Out-of-Scope（明确不做 & 原因）

| 编号 | 不做的事项 | 原因 |
|---|---|---|
| O-01 | 不另起独立音乐狗子 App / 不保留 `zhuyu-frontend-backup` 的 `frontend/` 独立工程 | 合并决策 D-01/D-02：竹笌为整体 App，音乐狗子仅作模块 |
| O-02 | 不本地部署音乐生成模型（ACE-Step / YuE 类） | 需 GPU 推理节点，本机无保障；C3 异步 job 架构已预留切换点（架构文档选型 C4） |
| O-03 | 不做前端直连 ACE Music / 不做同步代理 | 密钥必随 APK 泄露且绕过内容过滤；锁定 C3 后端异步代理（架构文档选型 C） |
| O-04 | 不引入 `audioplayers`、`flutter_animate`、`lucide_icons_flutter`（字体包）、Bloc | 选型 D/F/A/B 已显式排除，避免双播放器争抢、未验证依赖、视觉语言混用 |
| O-05 | 不新建第二套好感度体系（弃用音乐狗子 `love: float`） | 写入竹笌五维 `affinity`，避免两套打架（D-11） |
| O-06 | 不保留裸 `sqlite3` 歌词库、不保留内存态 `_sessions` 宠物状态 | 生产切 MySQL 静默丢数据；落 `db.py` + `pet_state` 表（选型 E） |
| O-07 | 不保留音乐狗子 5-provider 歌词 failover（groq/cerebras/gemini/ace/local） | 竹笌已锚定 Agnes 单一供应商，5 套密钥管理是净负债 |
| O-08 | 不做多角色人格市场 / 社交广场 / UGC 分享裂变（MVP） | 超出 MVP 范围，进 Backlog；先验证「陪伴+创作」核心闭环留存 |
| O-09 | 不启用紫粉渐变、不启用 emoji 功能图标、不硬编码色值 | P0 红线（见第 9 章），违反即退回 |
| O-10 | 不做 C 盘安装（音频/模型缓存/第三方缓存一律落 F 盘） | 受 C 盘禁装约束；`DATA_DIR`/`HF_HOME`/`MODELSCOPE_CACHE` 显式指向 F 盘（E-29、E-30） |

---

## 6. 关键用户流程

### 6.1 竹笌陪聊流（既有，合并后保留）

```
[启动] → /splash（竹笋破土微动画，300ms 内过渡）
   ↓
[/home 聊天陪伴] 信纸式对话 + 3D 竹笌同屏
   ↓ 用户输入（语音优先 / 文字）
[ASR] speech_to_text → [LLM /chat/v2 流式 SSE]
   ↓
[情绪识别] POST /emotion → 情绪芯片悬浮更新
   ↓
[TTS 播报] POST /tts → just_audio 播放 audio/wav
   ↓ （若失败：503 静默降级为纯文字，不卡死）
[记忆写入] /memory/* → 时间线沉淀
   ↓
[好感度更新] POST /affinity → 五维成长
   ↓
[可选] 点 3D 竹笌 → /avatar 全屏互动；或点 麦克风图标 → /voice 实时通话
```

### 6.2 音乐狗子音乐创作流（新增核心闭环）

```
[/discover 或 /profile] 点狗子入口卡片
   ↓
[/pet 音乐狗子主页] 狗子 3D 宠物居中
   ↓ 切到「创作台」三态之一
[宠物对话] POST /pet/interact（action: pet/feed/shake/bark）
   ↓ 返回狗子台词（纯文本）+ mood + affinity_delta
[歌词生成] POST /lyrics（theme/style/mood，style∈民谣/流行/DJ电音/国风/说唱）
   ↓ 201 创建成功（若 LLM 上游失败 → 502 明确报错，不回落模板假歌词）
[音乐生成] POST /music/generate（lyric_id 或 lyrics + prompt + duration）
   ↓ 202 立即返回 job_id（首次轮询建议 5s 后）
[轮询] GET /music/jobs/{job_id} 每 3s，指数退避至 8s，总放弃阈值 240s
   ↓ succeeded → 返回 Song（audio_url 为 /music/audio/<sha1>.mp3 常规路径）
[播放] just_audio 播放（同时 狗子随节奏律动 + 暖橙发光脉冲）
   ↓
[宠物状态/好感] pet_state 落库（mood/total_barks/songs_created）+ 写入五维 affinity
   ↓
[查看作品] GET /songs 我的作品；可进「歌词库」查看/编辑歌词
```

**关键体验约束**：音乐生成 48s 级耗时，**绝不同步阻塞**；轮询期间播放器显示波形骨架（非转圈死等）；放弃轮询后 job 仍在后端完成，用户可在「我的作品」看到结果。

---

## 7. 后端整合方案要点

**总原则**：复用竹笌 FastAPI 后端（`F:/zhuyapp-backend`，全局 `auth.verify_request` 签名鉴权），音乐端点以新增方式并入，不复用既有端点。

### 7.1 三项结构性改造

1. **`main.py` 拆 router**：现状单文件 22 端点 600+ 行，再加 8 个音乐端点必失控。按资源分包 `routers/{chat,memory,affinity,tts,pet,lyrics,music,legal}.py`，`main.py` 收缩为纯装配（≤120 行）。
2. **歌词库并入 `db.py`**：废 `lyrics_store.py` 裸 `sqlite3`；改用 SQLAlchemy Core Table 声明，复用 SQLite/MySQL 双兼容与 `pool_pre_ping` 重连；歌词正文加密存储（复用 `encryption.encrypt`），不支持全文检索，仅按 theme/style/时间筛选。
3. **宠物状态落库**：内存 `_sessions` 字典 → `pet_state` 表（`mood`/`total_barks`/`songs_created`/`last_song_title`）；好感度写入既有 `affinity` 五维，不新建体系。

### 7.2 三个新增服务模块

| 模块 | 职责 | 关键约束 |
|---|---|---|
| `music_provider.py` | ACE Music 客户端：构造 `<prompt>...</prompt><lyrics>...</lyrics>` 载荷、解 base64 data URI 落盘、算 sha1 去重 | 密钥**必须** `os.getenv("ACE_MUSIC_API_KEY")` 且无默认值；未配置时 `/music/generate` 返回 503，不静默降级假数据 |
| `lyrics_composer.py` | 歌词生成：移植 5 种风格模板（含 bpm/乐器/结构）+ `build_lyrics_prompt`，LLM 改走竹笌既有 `agnes_client` | 不移植 5-provider failover；单一供应商 |
| `job_queue.py` | 异步任务表驱动：`enqueue`/`mark_running`/`mark_succeeded`/`mark_failed`/`reap_stale` | MVP 用 FastAPI `BackgroundTasks` + `music_jobs` 表，不引入 Celery/Redis |

### 7.3 音乐生成接入要点（云端 ACE Music）

- 实测上游生成 30s 歌曲 ≈ 48.2s、响应 ≈ 641KB；返回的是 base64 data URI，**服务端解码落盘为 `/music/audio/<sha1>.mp3` 常规 HTTP 路径**，绝不向客户端下发 data scheme（播放器无法可靠播放）。
- 去重：`sha1(lyrics + prompt + duration)` 命中已有作品直接返回。
- 并发：单用户同时 1 个 running job；日调用上限防刷第三方额度。
- 音频落盘：`DATA_DIR/audio/`，天然落 F 盘（约 0.46MB/30s，按 1000 首/月 ≈ 460MB/月，F 盘余量 790GB 可支撑数年）；MVP 不做自动清理，仅 `GET /music/quota` 暴露占用量。

### 7.4 签名与鉴权（上线阻断级）

- 竹笌后端全局强制签名（canonical = `METHOD\nPATH\nTS\nNONCE\nSHA256(BODY)`）。
- 音乐狗子旧 `PetApiService` 用裸 `http.Client()` 只带 `Content-Type`，生产环境必 401。改造：复用 `client_auth.dart` 的 `SigningInterceptor`，注入同源 Dio 实例，`baseUrl` 取 `BackendConfig.instance.baseUrl`；废弃 `PET_API_URL` 编译期常量。
- 用户标识一律从 `X-User-Id` 头注入 `request.state.user_id`，路径中禁止出现 `user_id`（旧 `/pet/state/{user_id}` 改造为 `/pet/state`）。

### 7.5 TTS 前置修复（Phase 1 阻断项）

竹笌 IndexTTS 微服务实测未就绪（`torch`/`fastapi`/`indextts` 全部 MISSING，venv 同步中断在 torch 下载）。**必须先修复 IndexTTS 微服务**，否则语音能力为 0；修复前 `/tts` 返回 503，前端静默降级为纯文字。

---

## 8. 竞品 / 参照差异（语音陪聊 + 音乐创作类）

> 以下对标来自 DESIGN.md 设计寄存器与产品定位，属定位陈述而非精确市占数据；如需精确数据，后续补一轮联网竞品调研。

| 维度 | 对标对象 | 我们借鉴什么 | 我们与它的差异（护城河） |
|---|---|---|---|
| 语音陪伴 | Replika | 沉浸式单屏、情绪芯片、打字动画、在场感 | 我们叠加「竹系 3D 角色 + 音乐创作出口」，陪伴不止聊天，还能共创作品 |
| 语音陪伴 | Character.AI | 角色人格 + 记忆连续性 + 情绪徽章 | 我们用五维好感度成长体系 + 宠物（狗子）第二人格，且人格可延伸到音乐创作 |
| 音乐创作 | Suno | 左侧创作面板、prompt→生成→编辑 一行流 | 我们创作发生在「宠物陪伴场景」内，歌词由狗子情绪驱动，作品反哺好感度 |
| 音乐创作（声场） | Udio | 深色工作室、波形元素、发光脉冲 | 我们将其霓虹粉 `#E30B5D` 替换为竹绿/暖橙能量，**规避紫粉渐变** |
| 结构/设置 | Linear / Notion | 列表密度、聚焦态、空状态、设置分组 | 指导「我的/设置/记忆历史」信息架构，做到可信赖而非模板 |

**明确不对标**：Character.AI 的纯文字头像（我们要 3D 在场）、Candy AI 的艳俗动漫风（过度情色化、廉价感）、Udio 的霓虹粉（P0 紫粉渐变红线）。

**我们的差异化定位（一句话）**：市面上的 AI 陪伴 App 大多「只能聊不能创」，AI 音乐 App 大多「只能创没有陪」。竹笌 × 音乐狗子把二者合进同一个角色人格——**你聊出来的情绪，变成狗子陪你写的一首歌；你写的歌，又让狗子更懂你**。这是「陪伴即创作、创作即陪伴」的闭环，竞品目前是割裂的。

---

## 9. P0 设计约束（违反 = 退回）

以下三条为本项目红线，由项目总监（大湾区靓仔）制定，全团队（产品/设计/架构/前端）共同遵守。

### 9.1 图标一律用文字描述，绝不用 emoji 字符

- **文档层（本 PRD）**：所有功能图标以文字描述，例如「音符图标」「狗子图标」「爱心图标」「麦克风图标」「设置图标」「暂停图标」。文档内**不出现任何 emoji 字符**。
- **实现层**：锁定 Lucide SVG 资产（自托管于 `assets/icons/lucide/`，如 `music-4.svg`、`dog.svg`、`heart.svg`），经 `AppIcon` 门面统一访问；**全项目禁止 `Icons.*` / `CupertinoIcons.*` / emoji 字面量 / `IconData` 直接构造**。
- **存量清理**：竹笌 61 处 `Icons.*` + 移植 21 处 + 音乐狗子 emoji（旧代码中的狗子 / 爱心 / 笑脸 等 emoji 字面量）全量迁移为 Lucide；`moodEmojis` 常量表整段删除，改为 `mood` → SVG 资产名映射。`analysis_options.yaml` 加 CI 规则，grep `Icons\.|CupertinoIcons\.` 必须为 0。
- **例外**：emoji 仅允许出现在用户 UGC 文本（用户自己发的消息），绝不作 UI 图标。

### 9.2 禁止紫粉渐变方案

- **严禁**任何 `紫(#7C3AED) → 粉(#EC4899)` 及 `Indigo → Pink` 渐变作主视觉。
- 旧音乐狗子纯橙体系、旧竹笌深底 `#1A1A2E`（带紫调 navy-purple）**必须改竹调深 `#0E1512`**。
- **替代方案**：竹绿单色（`--accent #7CB342`）+ 暖橙能量色（`--ember #FF7A45`，暖橙非粉）；仅允许同色系深浅渐变，禁止跨色相（尤其紫→粉）渐变。
- 语义色全部非粉系：成功绿、警告金、错误暖红 `#C1463B`（非粉）、信息=竹绿。

### 9.3 禁止 Lorem / Welcome 之类空洞占位

- **禁止** "Welcome to" / "Get started" / "Seamless" 等 AI 模板味英文，中文禁止「赋能」「一站式」等空话。
- **禁止** "Lorem ipsum" 及任何占位假文；所有文案必须具体、可行动。
- **正确示例**：空状态写「3 分钟写下你的第一首歌，狗子陪你一起」+ 操作按钮；启动页写「竹笋破土」微动画 + 品牌字 reveal，不堆标语；引导文案指向真实界面动作（如「点竹笌进入全屏」）。

### 9.4 配套硬约束（来自 DESIGN.md 第 6 章反模式清单）

- 禁止硬编码颜色：全部引用设计令牌（`AppTheme` 对齐 `design-tokens.json`），废弃 `Color(0x...)` / `Colors.*` 直用。
- 禁止千篇一律 Hero 堆砌（`DESIGN_VARIANCE=5` 强制左对齐/非对称留白，禁用居中 Hero）。
- 禁止侧条纹边框强调（禁 `border-left>1px` 彩条，hover 时 `--border`→`--accent`）。
- 禁止渐变文字（`background-clip:text`）、过度圆角（卡片 ≥24px）、幽灵卡片（1px 边框 + blur≥16 阴影同元素）。
- 组件 5 态必覆盖：Default / Hover / Focus(`--focus-ring`) / Active / Disabled / Loading / Error(具体文案+重试) / Empty(引导+操作) / Success(短暂 toast)。

**设计令牌基线（摘录，完整见 `phase1/design-tokens.json`）**：
- 表面层：竹雾 `--bg #F1F6EE` / 深竹黑 `#0E1512`；暖米 `--surface-warm #FBF4E9`。
- 强调色：竹绿 `--accent #7CB342`；深竹 `--accent-deep #4E7C2A`；暖金 `--sun #F2A33C`（音乐狗子能量色）；暖橙 `--ember #FF7A45`（音乐动作色，暖橙非粉）。
- 字体：`--font-display "Smiley Sans"`（少年系短标题）/ `--font-body "Inter, Noto Sans SC"` / `--font-mono "JetBrains Mono"`（歌词时间轴/波形标签）。
- 圆角上限 16px；间距 4px 网格；动效 ≤200ms，且 `@media (prefers-reduced-motion: reduce)` 关闭非必要动画。

---

## 10. 验收标准（EARS 格式）

> EARS = Easy Approach to Requirements Syntax。以下为 Phase 1 关键验收，覆盖既有竹笌核心与音乐狗子新增闭环。

**EARS-01（普遍型）** 系统应在每次用户完成一次陪聊对话后，将对话摘要写入记忆历史并刷新五维好感度。

**EARS-02（事件驱动）** 当用户在音乐狗子创作台提交「生成音乐」请求时，系统应在 1 秒内返回 `job_id` 与 `poll_after_ms`，且不在前端同步阻塞等待生成结果。

**EARS-03（状态驱动）** 当音乐生成任务处于 `running` 状态时，系统应在创作台展示波形骨架（而非转圈死等），并每 3 秒轮询一次任务状态，直至 `succeeded` 或 `failed`。

**EARS-04（ unwanted behavior）** 若 `ACE_MUSIC_API_KEY` 未配置或 ACE Music 上游失败，则系统应返回 HTTP 503（音乐生成）或 502（歌词生成），且**不**静默降级为模板假歌词 / 假音频。

**EARS-05（事件驱动 +  unwanted）** 当宠物互动接口 `POST /pet/interact` 收到非法 `action` 时，系统应返回 HTTP 400 并给出可读错误；当收到合法 `action` 时，系统应返回狗子台词（纯文本、不含 emoji）、更新 mood 并回写五维好感度。

**EARS-06（状态驱动）** 当音乐作品播放进行中时，系统应让狗子宠物随播放进度产生节拍律动与暖橙发光脉冲（使用 `--ember` 暖橙，非粉色），且不得与 TTS 播报争抢音频焦点（单一 `just_audio` 实例）。

**EARS-07（普遍型 · 红线）** 系统应在所有功能界面使用 Lucide SVG 图标（经 `AppIcon` 门面），且全项目 `Icons.*` / `CupertinoIcons.*` / emoji 字面量出现次数应为 0。

**EARS-08（ unwanted · 红线）** 若界面需要使用强调渐变，则系统应使用竹绿单色或同色系深浅渐变；系统**不得**在任何页面渲染紫(`#7C3AED`)→粉(`#EC4899`)跨色相渐变，且深底应为竹调深 `#0E1512` 而非紫调 `#1A1A2E`。

**EARS-09（ unwanted · 红线）** 若页面处于空状态或引导态，则系统应展示具体可行动文案与操作按钮（如「3 分钟写下你的第一首歌」），且**不得**出现 "Welcome to" / "Lorem ipsum" / "赋能" 等模板占位文案。

**EARS-10（普遍型 · 安全）** 系统应在所有后端请求（含新增 8 个音乐端点）强制 HMAC-SHA256 签名鉴权；当签名失败、过期或重放时，系统应返回 HTTP 401，且用户标识仅从 `X-User-Id` 头注入，不得出现在 URL 路径中。

**EARS-11（状态驱动 · 持久化）** 当生产环境 `DATABASE_URL` 指向 MySQL 时，系统应将歌词与宠物状态写入该数据库（经 `db.py`），且**不得**静默落到本地 `sqlite3` 文件导致数据丢失。

---

## 附录 A：非功能需求（PRD 必含）

| 类别 | 要求 | 优先级 |
|---|---|---|
| 性能 | 首屏（/splash→/home）≤300ms 过渡；陪聊首字流式延迟 ≤1.5s；API p95 ≤500ms（签名校验在内） | P0 |
| 可用性 | 竹笌后端无单点故障；TTS 微服务不可用时 `/tts` 返回 503、前端静默降级纯文字，核心陪聊不中断 | P1 |
| 安全 | HTTPS + 全局 HMAC-SHA256 签名 + 输入校验 + 速率限制（单用户 1 running job、日上限）；密钥仅服务端 env，无硬编码默认值 | P0 |
| 兼容性 | Flutter 3.47.1 / Dart 3.13.1；Android/iOS 最新 2 大版本；微信内置浏览器不做主 target | P0 |
| 可访问性 | 正文对比度 ≥4.5:1；图标按钮带 `aria-label`/tooltip；键盘可达；遵循 `prefers-reduced-motion` | P2 |
| 数据合规 | 歌词/记忆正文加密存储（`encryption.encrypt`）；用户 `user_id` 不出现在 URL；软删除置 `deleted_at` | P0 |
| 存储约束 | 音频/模型/第三方缓存一律落 F 盘（`DATA_DIR`/`HF_HOME`/`MODELSCOPE_CACHE` 显式指向），C 盘禁装 | P0 |
| 数据埋点 | 见附录 B | P1 |

## 附录 B：数据埋点方案（MVP 必埋）

| 事件类别 | 必埋事件 | 说明 |
|---|---|---|
| 获客 | `app_launch`、`sign_up_complete` | 新用户从哪来、注册转化率 |
| 激活 | `first_chat_complete`、`first_song_created` | 首个核心动作：完成一次陪聊 / 生成第一首歌 |
| 留存 | `session_start`、`session_duration`、`pet_interact` | DAU/MAU、陪伴频次、宠物互动频次 |
| 转化 | `music_generate_click`、`music_generate_complete`、`tts_play` | 创作漏斗与语音使用 |
| 异常 | `error_occurred`、`music_job_failed`、`tts_503` | 前端错误 + 任务失败 + TTS 降级 |

**埋点实现要求**：前端轻量 `trackEvent()` 封装（不采集隐私，不上报 IP / 不存原始输入）；事件命名 `{对象}_{动作}`（如 `song_created`、`pet_interacted`）；每个事件附带 `user_id`(哈希) / `timestamp` / `device` / `version`。

---

*文档结束。下一步：项目总监裁决冻结 → 架构师落地 `openapi-music-pet.yaml` 8 端点 + 前端 `/pet` 三路由迁移 → 设计师按 `design-tokens.json` 冻结令牌 → 前端 Agent 按 DESIGN.md 第 8 章实现提示执行。*

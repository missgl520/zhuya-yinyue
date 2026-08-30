# 竹笌 × 音乐狗子 合并重设计 · 实施计划与任务拆解

| 项 | 值 |
|---|---|
| 文档版本 | v1.0 |
| 编制 | 基于 PRD/Spec/Architecture/Design/design-tokens/OpenAPI 六份文档 + 现有代码实读 |
| 基底 | `F:/zhuyapp` @ `main`（前端）+ `F:/zhuyapp-backend`（后端） |
| 目标 | Phase 1 MVP：竹笌核心闭环 + 音乐狗子核心创作闭环 |
| 预估总工作量 | 约 180-220 人时（含联调测试） |

---

## 0. 实施策略总览

### 0.1 阶段划分原则

1. **基础设施先行**：后端 router 拆分、db 扩展、前端设计令牌/图标基础设施必须先于业务模块
2. **阻断项优先**：IndexTTS 修复、后端鉴权复用确认是高优先级前置
3. **前后端并行**：Phase 1（后端基建）与 Phase 3（前端基建）可并行；Phase 2（后端业务）与 Phase 4（前端音乐模块）可并行
4. **每阶段可验收**：每个阶段结束都有可独立验证的产出，不做"半成品串联"

### 0.2 阶段依赖图

```
Phase 0（前置准备）
    │
    ├──→ Phase 1（后端基建）──→ Phase 2（后端业务）──┐
    │                                                    │
    └──→ Phase 3（前端基建）──→ Phase 4（前端音乐模块）─┤
                                                         │
                                            Phase 5（联调测试验收）
```

### 0.3 关键里程碑

| 里程碑 | 产出 | 验收标志 |
|---|---|---|
| M0 | 环境就绪 + 阻断项修复 | IndexTTS 可生成音频；设计令牌/图标基础设施可用 |
| M1 | 后端基建完成 | main.py ≤120行；9个router包；4张新表就位 |
| M2 | 后端业务完成 | 8个新端点全部可调用；OpenAPI契约通过 |
| M3 | 前端基建完成 | 82处图标迁移；硬编码色值清零；13页面重设计 |
| M4 | 前端音乐模块完成 | /pet三路由可用；创作闭环端到端跑通 |
| M5 | 联调验收完成 | EARS-01~11全部通过；P0红线零违规 |

---

## Phase 0：前置准备与阻断项修复

> **目标**：修复阻断项，搭建前后端共享的基础设施，为后续阶段扫清障碍。
> **预估**：20-25 人时
> **并行度**：全串行（每项都是后续依赖）

### P0-01：环境与依赖确认

| 项 | 内容 |
|---|---|
| 任务 | 确认前后端开发环境完整可用，记录版本基线 |
| 涉及 | `F:/zhuyapp/pubspec.yaml`、`F:/zhuyapp-backend/requirements.txt`、`.env` |
| 验收 | `flutter doctor` 无致命错误；后端 `uvicorn main:app` 可启动；模拟器可运行APP |
| 预估 | 2h |

**具体步骤**：
1. 记录 Flutter 3.47.1 / Dart 3.13.1 版本基线
2. 确认后端 venv 依赖完整（fastapi/uvicorn/sqlalchemy/cryptography/httpx/pydantic）
3. 确认 `.env` 配置（ZHUYU_API_KEY、DATABASE_URL、LIVEKIT_*）
4. 确认模拟器 zhuyu_emu 可启动且APP可安装运行
5. 记录当前 git HEAD commit 作为基线

### P0-02：IndexTTS 微服务修复（阻断项）

| 项 | 内容 |
|---|---|
| 任务 | 修复本地 IndexTTS 2.5 微服务，使 `/tts` 端点可正常返回音频 |
| 涉及 | `F:/zhuyapp-backend/tts_service/index-tts/`、`main.py:_start_tts_service` |
| 依赖 | P0-01 |
| 验收 | `POST /tts` 返回 200 + audio/wav；前端 TTS 可播放；微服务自动拉起正常 |
| 预估 | 8-12h |

**具体步骤**：
1. 检查 `tts_service/index-tts/.venv` 状态，确认 torch/fastapi/indextts 缺失情况
2. 重新同步 venv 依赖（使用国内镜像 `hf-mirror.com` 加速模型下载）
3. 验证 IndexTTS 引擎可加载 checkpoint
4. 测试微服务 8001 端口可响应
5. 验证主后端自动拉起逻辑（`_start_tts_service`）正常
6. 端到端测试：前端发送消息 → 后端 `/tts` → 音频播放
7. 降级验证：`ZHUYU_NO_TTS=1` 时 `/tts` 返回 503，前端静默降级

**风险**：torch 下载体积大（~2GB），网络不稳定可能超时；IndexTTS 模型权重可能需要重新下载。

### P0-03：前端设计令牌基础设施落地

| 项 | 内容 |
|---|---|
| 任务 | 基于 `design-tokens.json` 重构 `AppTheme`，新增 sun/ember/accentDeep 等字段，废弃 coral/mint/darkBg(navy) |
| 涉及 | `lib/core/theme/app_theme.dart`、`lib/presentation/providers/app_providers.dart` |
| 依赖 | P0-01 |
| 验收 | AppTheme 字段与 design-tokens.json 一一对应；浅/深主题切换正常；旧字段引用编译报错（强制迁移） |
| 预估 | 4h |

**具体步骤**：
1. 读取 `design-tokens.json` 全部 24 色 + 字体 + 间距 + 圆角 + 阴影 + 动效令牌
2. 重构 `AppTheme` 类，字段命名对齐令牌（bg/surface/surfaceWarm/fg/muted/accent/accentDeep/sun/ember/danger 等）
3. 浅色主题：bg `#F1F6EE`、surface `#FFFFFF`、accent `#7CB342`
4. 深色主题：bg `#0E1512`（竹调深，替换旧 `#1A1A2E`）、surface `#16201B`、accent `#8BD14F`
5. 新增 `sun`（暖金 `#F2A33C`）、`ember`（暖橙 `#FF7A45`）、`accentDeep`（深竹 `#4E7C2A`）字段
6. 废弃 `coral`、`mint`、`darkBg`（navy紫调）字段，删除或标记 deprecated
7. `themeProvider` 保持不变，确认浅/深切换正常
8. 圆角上限 16px 写入注释规范

### P0-04：前端图标基础设施搭建

| 项 | 内容 |
|---|---|
| 任务 | 引入 `lucide_icons` 包，创建 `AppIcon` 门面类，准备全量迁移基础设施 |
| 涉及 | `pubspec.yaml`、`lib/widgets/app_icon.dart`（新建）、`assets/icons/lucide/`（新建） |
| 依赖 | P0-01 |
| 验收 | `lucide_icons` 可正常 import；`AppIcon` 门面可返回正确图标；新增图标统一走门面 |
| 预估 | 3h |

**具体步骤**：
1. `pubspec.yaml` 添加 `lucide_icons: ^latest`，执行 `flutter pub get`
2. 创建 `lib/widgets/app_icon.dart`，定义 `AppIcon` 门面类
3. 门面类封装：尺寸（16/20/24px）、描边宽度（1.75/2）、颜色（currentColor）、语义（aria-label/tooltip）
4. 预定义常用图标映射：arrowLeft/music/library/dog/heart/settings/chevronRight/smile/mic/play/pause 等
5. 确认 `assets/icons/lucide/` 目录预留（如需自托管 SVG）
6. `analysis_options.yaml` 新增 lint 规则：禁止 `Icons.` 和 `CupertinoIcons.` 直接使用（grep 必须为 0）

---

## Phase 1：后端基础设施重构

> **目标**：将单文件 main.py 拆分为模块化 router 架构，扩展数据库 schema，为新增业务模块提供基础设施。
> **预估**：25-30 人时
> **依赖**：Phase 0
> **并行**：可与 Phase 3（前端基建）并行

### P1-01：main.py 拆 router（结构性改造一）

| 项 | 内容 |
|---|---|
| 任务 | 将 main.py 中 22 个端点按资源拆分为 9 个 router 包，main.py 收缩为纯装配（≤120行） |
| 涉及 | `main.py`、新建 `routers/` 目录（chat.py/memory.py/affinity.py/tts.py/pet.py/lyrics.py/music.py/legal.py/health.py） |
| 依赖 | P0-01 |
| 验收 | main.py ≤120行；所有原有端点行为不变；全局签名鉴权仍生效；`/health` `/docs` 正常 |
| 预估 | 8h |

**具体步骤**：
1. 创建 `routers/__init__.py`
2. 按资源拆分：
   - `routers/health.py` — `/` `/health`
   - `routers/chat.py` — `/chat/v2` `/emotion` `/persona` `/wake-word`
   - `routers/memory.py` — `/memory/*` 全部 7 个端点
   - `routers/affinity.py` — `/affinity`
   - `routers/tts.py` — `/tts`
   - `routers/legal.py` — `/legal/privacy` `/legal/terms`
   - `routers/user.py` — `/user/export` `/user/data`
   - `routers/pet.py` — 预留（Phase 2 填充）
   - `routers/lyrics.py` — 预留（Phase 2 填充）
   - `routers/music.py` — 预留（Phase 2 填充）
3. 每个 router 使用 `APIRouter(prefix=..., tags=[...])`，依赖 `Depends(auth.verify_request)`
4. main.py 改为：创建 app → 配置 CORS → `include_router()` 逐个注册 → 启动事件（TTS微服务拉起）
5. 全局依赖 `auth.verify_request` 保持在 app 级别，router 不再重复声明
6. 回归测试：逐个调用原有 22 端点，确认行为与拆分前一致
7. 确认 OpenAPI 文档（`/docs`）正常生成

### P1-02：db.py 扩展（结构性改造二+三）

| 项 | 内容 |
|---|---|
| 任务 | 新增 4 张表：pet_state、lyrics、music_jobs、songs；歌词正文加密存储；宠物状态落库 |
| 涉及 | `db.py`、`encryption.py`（复用） |
| 依赖 | P1-01 |
| 验收 | 4 张表在 SQLite/MySQL 均可创建；CRUD 操作正常；歌词正文加密落盘、出参解密；宠物状态持久化 |
| 预估 | 8h |

**具体步骤**：

1. **pet_state 表**：
   ```
   user_id VARCHAR(128) PK
   mood VARCHAR(32) DEFAULT 'happy'
   total_barks INTEGER DEFAULT 0
   songs_created INTEGER DEFAULT 0
   last_song_title VARCHAR(64) NULLABLE
   updated_at VARCHAR(32)
   ```

2. **lyrics 表**：
   ```
   id VARCHAR(36) PK (UUID)
   user_id VARCHAR(128) INDEX
   title VARCHAR(128)
   lyrics TEXT (加密存储，复用 encryption.encrypt)
   note TEXT
   tags TEXT (JSON数组)
   theme VARCHAR(128)
   style VARCHAR(32) (民谣/流行/DJ电音/国风/说唱)
   mood VARCHAR(32)
   pet_reaction TEXT
   created_at VARCHAR(32)
   updated_at VARCHAR(32)
   deleted_at VARCHAR(32) NULLABLE (软删除)
   ```

3. **music_jobs 表**：
   ```
   job_id VARCHAR(36) PK
   user_id VARCHAR(128) INDEX
   status VARCHAR(16) (queued/running/succeeded/failed/cancelled)
   progress FLOAT DEFAULT 0
   prompt TEXT
   lyric_id VARCHAR(36) NULLABLE
   lyrics TEXT NULLABLE
   duration INTEGER DEFAULT 30
   language VARCHAR(2) DEFAULT 'zh'
   song_id VARCHAR(36) NULLABLE
   error VARCHAR(255) NULLABLE
   attempt INTEGER DEFAULT 0
   created_at VARCHAR(32)
   finished_at VARCHAR(32) NULLABLE
   ```

4. **songs 表**：
   ```
   id VARCHAR(36) PK
   user_id VARCHAR(128) INDEX
   title VARCHAR(128)
   audio_filename VARCHAR(64) (sha1.mp3)
   duration_sec INTEGER
   audio_bytes INTEGER
   lyric_id VARCHAR(36) NULLABLE
   job_id VARCHAR(36) NULLABLE
   prompt TEXT NULLABLE
   created_at VARCHAR(32)
   deleted_at VARCHAR(32) NULLABLE
   ```

5. 使用 SQLAlchemy Core Table 声明，保持与现有 memories/affinity/kv 表风格一致
6. 复用 `encryption.encrypt/decrypt` 处理 lyrics 正文
7. 所有表包含 `user_id` 索引，确保多用户隔离
8. 软删除使用 `deleted_at` 字段，查询默认过滤 `deleted_at IS NULL`
9. 编写建表迁移逻辑（启动时自动 `CREATE TABLE IF NOT EXISTS`）
10. 验证 SQLite 和 MySQL 双兼容（`pool_pre_ping` 重连）

### P1-03：配置与鉴权复用确认

| 项 | 内容 |
|---|---|
| 任务 | 确认新增模块可复用现有配置和鉴权体系，新增必要环境变量 |
| 涉及 | `config.py`、`auth.py`、`.env.example` |
| 依赖 | P1-01 |
| 验收 | ACE_MUSIC_API_KEY 等新环境变量可读取；全局签名鉴权覆盖新端点；用户标识从 X-User-Id 注入 |
| 预估 | 3h |

**具体步骤**：
1. `config.py` 新增：
   - `ACE_MUSIC_API_KEY`（无默认值，未配置时音乐生成返回 503）
   - `ACE_MUSIC_API_URL`（默认 ACE Music 官方端点）
   - `MUSIC_AUDIO_DIR`（默认 `DATA_DIR/audio`）
   - `MUSIC_MAX_DURATION`（默认 120 秒）
   - `MUSIC_DAILY_LIMIT`（默认 20 首/天/用户）
   - `MUSIC_CONCURRENT_JOBS`（默认 1）
2. 确认 `auth.verify_request` 对新增 router 自动生效（app 级依赖）
3. 确认 `request.state.user_id` 在所有新端点中可访问
4. 更新 `.env.example` 文档，说明新增环境变量
5. 确认公开路径白名单（`/legal/*` `/health` `/`）不影响新端点

### P1-04：后端模块化验证

| 项 | 内容 |
|---|---|
| 任务 | 全面回归测试后端拆分后的所有端点，确认无行为变化 |
| 涉及 | 全部 router |
| 依赖 | P1-01, P1-02, P1-03 |
| 验收 | 原有 22 端点全部通过；4 张新表可 CRUD；OpenAPI 文档完整 |
| 预估 | 4h |

---

## Phase 2：后端业务模块开发

> **目标**：实现 8 个新增端点和 3 个新增服务模块，完成音乐狗子后端业务闭环。
> **预估**：40-50 人时
> **依赖**：Phase 1
> **并行**：可与 Phase 4（前端音乐模块）并行（前端可先基于 OpenAPI 契约 mock）

### P2-01：宠物模块（/pet/state + /pet/interact）

| 项 | 内容 |
|---|---|
| 任务 | 实现宠物状态读取和互动接口，互动回写五维好感度 |
| 涉及 | `routers/pet.py`、`pet_state` 表、`affinity_store.py`（复用） |
| 依赖 | P1-02 |
| 验收 | GET /pet/state 返回宠物状态+好感度；POST /pet/interact 四种 action 均返回台词+mood+affinity_delta；非法 action 返回 400 |
| 预估 | 6h |

**具体步骤**：

1. **GET /pet/state**：
   - 从 `request.state.user_id` 获取用户
   - 查询 pet_state 表，不存在则创建默认记录（mood=happy, total_barks=0, songs_created=0）
   - 关联查询 affinity 表，组装 PetState 响应
   - 返回 200 + PetState JSON

2. **POST /pet/interact**：
   - 校验 action ∈ {pet, feed, shake, bark}，非法返回 400
   - 根据 action 计算好感度增量：
     - pet → intimacy +1.0
     - feed → trust +1.0
     - shake → familiarity +0.5
     - bark → familiarity +0.5, total_barks +1
   - 更新 pet_state 表（mood 随机变化、total_barks 累加）
   - 调用 `affinity_store.bump_after_chat()` 或直接更新 affinity 表
   - 生成狗子台词（纯文本，不含 emoji，基于 action 和 mood）
   - 返回 200 + PetInteractResponse（dialogue/mood/affinity_delta/affinity）

3. 台词生成规则：
   - pet：亲昵回应（如"蹭蹭你的手"）
   - feed：开心回应（如"好吃！尾巴摇起来了"）
   - shake：困惑/兴奋回应
   - bark：活力回应
   - 所有台词纯文本，禁止 emoji

4. mood 状态机：happy/excited/sleepy/hungry/confused/angry 六态

### P2-02：歌词生成模块（lyrics_composer.py + /lyrics）

| 项 | 内容 |
|---|---|
| 任务 | 实现歌词生成服务和歌词 CRUD 端点，5 种风格模板，LLM 走 Agnes |
| 涉及 | `lyrics_composer.py`（新建）、`routers/lyrics.py`、`lyrics` 表、`agnes_client.py`（复用） |
| 依赖 | P1-02, P1-03 |
| 验收 | POST /lyrics 生成并保存歌词（201）；GET /lyrics 列表筛选；GET/PATCH/DELETE /lyrics/{id} 正常；LLM 上游失败返回 502（不回落模板假歌词） |
| 预估 | 10h |

**具体步骤**：

1. **lyrics_composer.py**：
   - 定义 5 种风格模板（民谣/流行/DJ电音/国风/说唱），每种包含：bpm 范围、推荐乐器、结构模板（主歌/副歌/桥段）、语言风格
   - `build_lyrics_prompt(theme, style, mood, additional, user_mood)`：构建 Agnes 提示词
   - 提示词包含：风格要求、结构要求、字数要求、情绪基调、禁止 emoji
   - 调用 `agnes_client.stream()` 或非流式接口生成歌词
   - 解析返回，提取 title 和 lyrics 正文
   - 生成 pet_reaction（狗子对歌词的反应文案）

2. **POST /lyrics**：
   - 校验 theme/style/mood 必填
   - style 枚举外的值回落为"流行"
   - 内容前置过滤（复用 content_moderation），命中返回 403
   - 调用 lyrics_composer 生成
   - LLM 上游失败 → 返回 502（明确报错，不回落模板假歌词）
   - 生成 UUID 作为 id，加密 lyrics 正文，落库 lyrics 表
   - 返回 201 + Lyrics JSON（出参已解密）

3. **GET /lyrics**：
   - 支持 theme/style 筛选 + limit/offset 分页
   - 按 created_at 倒序
   - 歌词正文加密存储，因此不支持全文检索，仅按 theme/style/时间筛选
   - 返回 200 + LyricsPage（items/total/limit/offset/has_more）

4. **GET /lyrics/{id}**：
   - 校验归属（user_id 匹配），不匹配返回 404
   - 返回 200 + Lyrics（解密后）

5. **PATCH /lyrics/{id}**：
   - 仅允许修改 title 和 tags（最多 10 个，每个 ≤32 字符）
   - 至少一个字段
   - 返回 200 + 更新后的 Lyrics

6. **DELETE /lyrics/{id}**：
   - 软删除（置 deleted_at），不物理删除
   - 返回 200 + OkResponse

### P2-03：音乐生成模块（music_provider.py + job_queue.py + /music/*）

| 项 | 内容 |
|---|---|
| 任务 | 实现 ACE Music 客户端、异步任务队列、音乐生成/查询/取消/音频端点 |
| 涉及 | `music_provider.py`（新建）、`job_queue.py`（新建）、`routers/music.py`、`music_jobs`/`songs` 表、`DATA_DIR/audio/` |
| 依赖 | P1-02, P1-03, P2-02 |
| 验收 | POST /music/generate 返回 202+job_id；GET /music/jobs/{job_id} 可轮询；成功后 audio_url 可播放；sha1 去重生效；未配置 API Key 返回 503；并发/日上限返回 429 |
| 预估 | 16h |

**具体步骤**：

1. **music_provider.py**：
   - `generate(prompt, lyrics, duration, language)`：构造 ACE Music 请求载荷 `<prompt>...</prompt><lyrics>...</lyrics>`
   - 调用 ACE Music API（`ACE_MUSIC_API_URL`），密钥从 `os.getenv("ACE_MUSIC_API_KEY")` 读取，无默认值
   - 解析响应：上游返回 base64 data URI，服务端解码为 mp3 二进制
   - 计算 `sha1(lyrics + prompt + duration)` 作为文件名
   - 落盘到 `MUSIC_AUDIO_DIR/<sha1>.mp3`
   - 去重：sha1 命中已有文件直接返回，不重复调用上游
   - 异常处理：上游失败抛出明确异常，不静默降级

2. **job_queue.py**：
   - `enqueue(user_id, prompt, lyric_id, lyrics, duration, language)`：创建 music_jobs 记录（status=queued），返回 job_id
   - `mark_running(job_id)`：状态更新为 running
   - `mark_succeeded(job_id, song_id)`：状态更新为 succeeded，记录 song_id
   - `mark_failed(job_id, error)`：状态更新为 failed，记录错误
   - `reap_stale()`：清理超时任务（running 超过 300s 标记为 failed）
   - 并发控制：单用户同时最多 1 个 running job
   - 日调用上限：单用户每天最多 MUSIC_DAILY_LIMIT 首

3. **POST /music/generate**：
   - 校验 lyric_id 与 lyrics 至少一个（同时给出以 lyric_id 为准）
   - 校验 duration ∈ [10, 120]
   - 内容过滤（复用 content_moderation），命中返回 403
   - 并发检查：用户已有 running job → 返回 429
   - 日上限检查：已达上限 → 返回 429
   - API Key 检查：未配置 ACE_MUSIC_API_KEY → 返回 503
   - sha1 去重：命中已有作品 → 直接返回既有 song（不走异步）
   - 入队：创建 job（status=queued），通过 FastAPI BackgroundTasks 异步执行
   - 返回 202 + MusicJobAccepted（job_id/status/poll_after_ms=5000）

4. **异步执行逻辑（BackgroundTasks）**：
   - mark_running
   - 调用 music_provider.generate
   - 成功：创建 songs 记录，mark_succeeded
   - 失败：mark_failed，记录错误
   - 更新 pet_state.songs_created +1

5. **GET /music/jobs/{job_id}**：
   - 校验归属，不匹配返回 404
   - 返回 200 + MusicJob（job_id/status/progress/song/error/attempt/created_at/finished_at）
   - status=succeeded 时 song 字段包含完整 Song 信息

6. **DELETE /music/jobs/{job_id}**：
   - 仅 queued 状态可取消
   - running/终态返回 400
   - 返回 200 + OkResponse

7. **GET /music/audio/{filename}**：
   - filename 格式校验：`^[0-9a-f]{40}\.mp3$`
   - 从 MUSIC_AUDIO_DIR 读取文件
   - 返回 200 + audio/mpeg 二进制流
   - 文件不存在返回 404

### P2-04：作品模块（/songs）

| 项 | 内容 |
|---|---|
| 任务 | 实现作品列表和删除端点 |
| 涉及 | `routers/music.py`（songs 部分）、`songs` 表 |
| 依赖 | P2-03 |
| 验收 | GET /songs 分页列表；DELETE /songs/{id} 软删除+清理无引用音频 |
| 预估 | 4h |

**具体步骤**：

1. **GET /songs**：
   - 按 user_id 过滤，created_at 倒序
   - limit/offset 分页
   - 返回 200 + SongPage

2. **DELETE /songs/{id}**：
   - 校验归属
   - 软删除 songs 记录（置 deleted_at）
   - 检查 audio_filename 是否被其他 songs 记录引用，无引用则删除磁盘文件
   - 返回 200 + OkResponse

### P2-05：后端 OpenAPI 契约验证

| 项 | 内容 |
|---|---|
| 任务 | 对照 openapi-music-pet.yaml 验证全部 8 个新端点的请求/响应契约 |
| 涉及 | 全部新端点 |
| 依赖 | P2-01~P2-04 |
| 验收 | 所有端点的路径、方法、请求体、响应状态码、响应体结构与 OpenAPI 契约一致 |
| 预估 | 4h |

---

## Phase 3：前端基础设施重构

> **目标**：完成设计令牌全量对齐、图标全量迁移、P0 红线整改，为现有页面重设计和音乐模块开发提供统一基础设施。
> **预估**：35-40 人时
> **依赖**：Phase 0（P0-03, P0-04）
> **并行**：可与 Phase 1（后端基建）并行

### P3-01：图标全量迁移（82处）

| 项 | 内容 |
|---|---|
| 任务 | 将全项目 61 处 `Icons.*` + 21 处 emoji 图标 + 音乐狗子 emoji 全部迁移为 Lucide SVG，经 AppIcon 门面访问 |
| 涉及 | 全部 dart 文件、`lib/widgets/app_icon.dart` |
| 依赖 | P0-04 |
| 验收 | `grep -r "Icons\.\|CupertinoIcons\." lib/` 结果为 0；UI 图标显示正常；emoji 仅出现在用户 UGC 文本 |
| 预估 | 12h |

**具体步骤**：

1. 建立迁移映射表（基于 DESIGN.md §3）：
   | 旧 | 新 Lucide |
   |---|---|
   | Icons.arrow_back | ArrowLeft |
   | Icons.music_note | Music |
   | Icons.library_music | Library |
   | Icons.pets | Dog |
   | Icons.chevron_right | ChevronRight |
   | Icons.settings | Settings |
   | Icons.search | Search |
   | Icons.close | X |
   | Icons.mic | Mic |
   | Icons.mic_off | MicOff |
   | Icons.call_end | PhoneOff |
   | Icons.send | Send |
   | Icons.image | Image |
   | Icons.camera | Camera |
   | Icons.history | History |
   | Icons.privacy_tip | ShieldCheck |
   | Icons.description | FileText |
   | Icons.info | Info |
   | Icons.refresh | RefreshCw |
   | Icons.error_outline | AlertCircle |
   | Icons.eco | Leaf |
   | 🐕 (emoji) | Dog |
   | 💕 (emoji) | Heart |
   | 😄 (emoji) | Smile |
   | 🔥 (emoji) | Flame |
   | 🌱 (emoji) | Sprout |

2. 逐文件迁移，优先迁移核心页面：
   - `chat_page.dart`（顶栏/输入区/语音按钮）
   - `menu_panel.dart`（关系横幅/菜单项）
   - `settings_sheet.dart`（设置项图标）
   - `voice_call_page.dart`（通话控制按钮）
   - `memory_history_page.dart`（搜索/空状态）
   - `profile_page.dart`（功能列表）
   - `discover_page.dart`（返回按钮）
   - `avatar_fullscreen_page.dart`（返回按钮）
   - `legal_page.dart`（AppBar）
   - `info_modules_page.dart`（卡片图标）
   - `splash_page.dart`（同意卡图标）

3. 情绪 emoji 特殊处理：
   - `moodEmojis` 常量表整段删除
   - 改为 `mood` → Lucide 图标名映射（happy→Smile, sad→Frown, angry→Angry 等）
   - 情绪显示使用 `--sun` 色点 + 文字标签，不用 emoji

4. 迁移后运行 `flutter analyze`，确认无编译错误
5. 运行 grep 验证：`grep -rn "Icons\.\|CupertinoIcons\." lib/` 必须为 0
6. `analysis_options.yaml` lint 规则生效，CI 可拦截违规

### P3-02：硬编码色值清零

| 项 | 内容 |
|---|---|
| 任务 | 将全项目 `Color(0xFF...)` / `Colors.*` 硬编码色值全部替换为 AppTheme 令牌引用 |
| 涉及 | 全部 dart 文件、`lib/core/theme/app_theme.dart` |
| 依赖 | P0-03 |
| 验收 | `grep -r "Color(0x\|Colors\." lib/` 结果为 0（白/黑描边遮罩除外）；UI 颜色与设计令牌一致 |
| 预估 | 10h |

**具体步骤**：

1. 建立色值映射表（基于 design-tokens.json）：
   | 旧硬编码 | 新令牌 |
   |---|---|
   | Color(0xFFEDF7F0) | AppTheme.bg |
   | Color(0xFFF5EFE5) | AppTheme.surfaceWarm |
   | Color(0xFF3D2914) | AppTheme.fg |
   | Color(0xFF3D6B1E) | AppTheme.accentDeep |
   | Color(0xFF1A1A2E) | AppTheme.bg（深色，竹调深 #0E1512） |
   | Colors.pink | AppTheme.sun（好感度用暖金） |
   | Colors.orange | AppTheme.sun / AppTheme.ember |
   | Colors.grey[*] | AppTheme.muted / AppTheme.meta / AppTheme.fg2 |
   | Colors.white | AppTheme.surface |
   | Colors.black | （仅遮罩，保留） |

2. 逐文件替换，重点文件：
   - `app_theme.dart`（自身重构，新增字段）
   - `chat_page.dart`（背景/气泡/按钮）
   - `menu_panel.dart`（横幅/进度条/标签）
   - `settings_sheet.dart`（卡片/开关/文字）
   - `profile_page.dart`（背景/卡片/文字）
   - `discover_page.dart`（背景/竹子/文字）
   - `voice_call_page.dart`（背景/按钮/文字）
   - `splash_page.dart`（背景/Logo/文字）
   - `memory_history_page.dart`（卡片/文字）
   - `info_modules_page.dart`（卡片/文字）
   - `live2d_controller.dart`（如有色值）

3. 特殊处理：
   - `#FFFFFF`/`#000000` 仅用于纯白描边/纯黑遮罩，可保留
   - 渐变色必须使用同色系深浅（竹绿系），禁止紫→粉跨色相
   - 语义色（成功/警告/错误/信息）使用 AppTheme.success/warn/danger/info

4. 替换后运行 `flutter analyze`，确认无编译错误
5. 运行 grep 验证硬编码清零
6. 视觉对比：浅色/深色模式下截图对比，确认颜色正确

### P3-03：P0 红线整改

| 项 | 内容 |
|---|---|
| 任务 | 整改 DESIGN.md §6 列出的 9 项 P0 反模式 |
| 涉及 | 全部 dart 文件 |
| 依赖 | P3-01, P3-02 |
| 验收 | 9 项反模式零违规；AI 模板味文案清零；紫粉渐变清零；过度圆角清零 |
| 预估 | 6h |

**具体步骤**：

1. **反模式① emoji 作功能图标**：P3-01 已完成，验证 grep 为 0

2. **反模式② 紫粉渐变主视觉**：
   - 搜索全项目 `#7C3AED` `#EC4899` `purple` `pink` `indigo` 渐变
   - 旧 `#1A1A2E` 深底（带紫调 navy-purple）→ 改为 `#0E1512` 竹调深
   - 所有渐变更改为竹绿单色或同色系深浅渐变
   - 验证：无紫→粉跨色相渐变

3. **反模式③ 硬编码颜色**：P3-02 已完成，验证 grep 为 0

4. **反模式④ AI 模板味文案**：
   - 搜索 "Welcome to" "Get started" "Seamless" "赋能" "一站式"
   - 替换为具体可行动文案：
     - 空状态："3 分钟写下你的第一首歌，狗子陪你一起" + 操作按钮
     - 启动页：竹笋破土微动画 + 品牌字 reveal，不堆标语
     - 引导文案指向真实界面动作

5. **反模式⑤ 千篇一律 Hero 堆砌**：
   - 检查是否有"大标题+副标题+居中CTA+抽象图形"布局
   - 改为左对齐/非对称留白（DESIGN_VARIANCE=5）
   - 角色同屏、真实界面元素替代抽象图形

6. **反模式⑥ 侧条纹边框强调**：
   - 搜索 `border-left` >1px 彩条
   - 改为 hover 时 `--border`→`--accent`

7. **反模式⑦ 渐变文字**：
   - 搜索 `background-clip:text` / ShaderMask 文字渐变
   - 改为纯色 + 字重/字号强调

8. **反模式⑧ 过度圆角**：
   - 搜索卡片圆角 ≥24px
   - 改为上限 16px（`--radius-lg`）

9. **反模式⑨ 幽灵卡片**：
   - 搜索 `1px 边框 + blur≥16 阴影` 同元素
   - 二选一：要么边框，要么阴影

### P3-04：现有页面重设计（13个页面）

| 项 | 内容 |
|---|---|
| 任务 | 按 DESIGN.md §4 页面清单，对 13 个现有页面进行全量重设计 |
| 涉及 | `lib/pages/` 全部页面 |
| 依赖 | P3-01, P3-02, P3-03 |
| 验收 | 13 个页面均符合设计令牌；组件 5 态覆盖；空状态有引导+操作；无 P0 违规 |
| 预估 | 12h |

**页面清单与重设计要点**：

| # | 路由 | 页面 | 重设计要点 |
|---|---|---|---|
| 1 | `/splash` | 启动页 | 竹笋破土生长微动画 + 品牌字 reveal，300ms 内过渡，不堆标语 |
| 2 | `/home` | 聊天陪伴 | 信纸式对话 + 3D 竹笌同屏，情绪芯片悬浮，底部语音优先输入 |
| 3 | `/discover` | 发现·竹林 | 沉浸竹林背景 + 左下吉祥物入口，去 tab、大留白 |
| 4 | `/avatar` | 3D 角色页 | 全屏角色互动，表情/换装/背景切换，`--accent-soft` 面板 |
| 5 | `/voice` | 实时语音通话 | LiveKit 全屏角色 + 实时波形（mono 标签时间轴），挂断键 `--danger` 暖红圆钮 |
| 6 | `/profile` | 我的 | 统一竹系（弃用旧米棕），头像 + 收藏/模块/设置清晰分组（Linear 密度） |
| 7 | `/settings` | 设置 | 分组列表（外观/账号/数据/关于），右侧 ChevronRight，切换用 `--accent` 开关 |
| 8 | `/settings/memory` | 记忆历史 | 时间线式记忆流，空状态有引导文案 + 操作钮 |
| 9 | `/settings/modules` | 模块信息 | 已启模块卡片（竹笌/狗子），`--accent-soft` 标识开启态 |
| 10 | `/legal` | 法律文档 | Markdown 渲染，可读文本，保持现有结构 |
| 11 | `/info` | 信息模块 | 个人信息收集/第三方共享/版本介绍，卡片式布局 |
| 12 | `/memory-history` | 记忆历史（独立） | 与 /settings/memory 合并或保持一致 |
| 13 | 菜单面板 | MenuPanel | 关系横幅重设计，菜单项 Lucide 图标 |

**每个页面必须覆盖的组件 5 态**：
- Default / Hover / Focus(`--focus-ring`) / Active / Disabled
- Loading（骨架/Spinner）/ Error（具体文案+重试）/ Empty（引导+操作）/ Success（短暂 toast）

---

## Phase 4：前端音乐模块开发

> **目标**：实现 /pet 三路由和音乐狗子核心创作闭环 UI，与后端 8 端点联调。
> **预估**：35-40 人时
> **依赖**：Phase 3（前端基建）、Phase 2（后端业务，可基于 OpenAPI 契约 mock 先行）
> **并行**：可与 Phase 2 后端业务并行开发

### P4-01：音乐模块状态管理与服务层

| 项 | 内容 |
|---|---|
| 任务 | 创建音乐模块的 Riverpod providers 和 API 服务层，对接后端 8 端点 |
| 涉及 | `lib/presentation/providers/pet_provider.dart`（新建）、`lib/presentation/providers/music_provider.dart`（新建）、`lib/data/services/pet_api_service.dart`（新建/改造） |
| 依赖 | P3-01, P3-02 |
| 验收 | 8 个端点均可通过服务层调用；签名鉴权自动附加；状态管理响应式更新 |
| 预估 | 8h |

**具体步骤**：

1. **pet_api_service.dart**（改造旧裸 http 调用）：
   - 废弃 `package:http` 裸调，改用 Dio + `SigningInterceptor`
   - `baseUrl` 取 `BackendConfig.instance.baseUrl`
   - 废弃 `PET_API_URL` 编译期常量
   - 方法：
     - `getPetState()` → GET /pet/state
     - `interactPet(action)` → POST /pet/interact
     - `createLyrics(request)` → POST /lyrics
     - `listLyrics({theme, style, limit, offset})` → GET /lyrics
     - `getLyrics(id)` → GET /lyrics/{id}
     - `patchLyrics(id, {title, tags})` → PATCH /lyrics/{id}
     - `deleteLyrics(id)` → DELETE /lyrics/{id}
     - `generateMusic(request)` → POST /music/generate
     - `getMusicJob(jobId)` → GET /music/jobs/{job_id}
     - `cancelMusicJob(jobId)` → DELETE /music/jobs/{job_id}
     - `listSongs({limit, offset})` → GET /songs
     - `deleteSong(id)` → DELETE /songs/{id}

2. **pet_provider.dart**（Riverpod）：
   - `petStateProvider`（StateNotifier）：宠物状态（mood/total_barks/songs_created/affinity）
   - `petInteract(action)`：调用互动接口，更新状态，显示狗子台词
   - 好感度变更同步到全局 affinity 状态

3. **music_provider.dart**（Riverpod）：
   - `lyricsListProvider`（FutureProvider）：歌词列表
   - `currentLyricsProvider`（StateProvider）：当前选中歌词
   - `musicJobProvider`（StateNotifier）：音乐生成任务状态（queued/running/succeeded/failed）
   - `generateMusic(lyricId, prompt, duration)`：提交生成任务，启动轮询
   - `pollJob(jobId)`：每 3 秒轮询，指数退避至 8 秒，总放弃阈值 240 秒
   - `songsListProvider`（FutureProvider）：作品列表
   - 轮询期间显示波形骨架（非转圈死等）
   - 放弃轮询后 job 仍在后端完成，用户可在"我的作品"看到结果

### P4-02：/pet 音乐狗子主页（三态切换）

| 项 | 内容 |
|---|---|
| 任务 | 实现音乐狗子主页，狗子 3D 宠物居中 + 底部三态切换（创作台/歌词库/宠物） |
| 涉及 | `lib/pages/pet/pet_studio_page.dart`（新建）、`lib/widgets/pet/`（新建组件目录） |
| 依赖 | P4-01 |
| 验收 | 三态切换流畅；创作台可输入 prompt 并生成歌词/音乐；歌词库可浏览；宠物状态可互动 |
| 预估 | 12h |

**具体步骤**：

1. **页面结构**：
   - 顶部：狗子 3D 宠物（居中，占屏幕上半部分）
   - 中部：狗子台词气泡（互动时显示）
   - 底部：三态切换 TabBar（创作台/歌词库/宠物）
   - 各态内容区（可滑动切换或点击切换）

2. **创作台（左 prompt 输入 + 右生成结果）**：
   - prompt 输入框（音乐风格描述，≤500字）
   - 歌词生成：theme/style/mood 选择器（5种风格 Chip）
   - 快捷语 chip（用 `--sun-soft` 暖底）：如"写一首关于夏天的歌"
   - 生成歌词按钮 → 调用 POST /lyrics
   - 生成音乐按钮 → 调用 POST /music/generate（需先有歌词或直接输入 lyrics）
   - 生成中：波形骨架屏（非转圈）
   - 生成结果：歌词展示 + 音乐播放控件
   - duration 选择器（10-120秒，默认30）

3. **歌词库（Suno 式时间线）**：
   - 歌词卡片列表（mono 字体时间轴）
   - 每张卡片：title/style/mood/created_at + 歌词预览
   - 点击展开编辑（title/tags）
   - 筛选：style 筛选 Chip
   - 分页加载
   - 空状态："3 分钟写下你的第一首歌，狗子陪你一起" + 创作台跳转按钮

4. **宠物状态（mood + loveMeter）**：
   - 狗子 mood 显示（Lucide 图标 + 文字，去 emoji）
   - loveMeter 进度条（用 `--sun` 暖金，去粉）
   - 五维好感度详情（trust/intimacy/familiarity 等）
   - 互动按钮：pet/feed/shake/bark（Lucide 图标）
   - 统计：total_barks、songs_created、连续互动天数
   - 互动后显示狗子台词气泡 + mood 变化动画

5. **狗子 3D 宠物**：
   - 复用 VrmAvatarView 或创建狗子专用 3D 视图
   - 播放音乐时随节奏律动 + 暖橙发光脉冲（`--ember`）
   - 互动时触发动作动画

### P4-03：/pet/full 宠物全屏页

| 项 | 内容 |
|---|---|
| 任务 | 实现宠物独立全屏互动页 |
| 涉及 | `lib/pages/pet/pet_fullscreen_page.dart`（新建） |
| 依赖 | P4-02 |
| 验收 | 全屏宠物可互动；空状态有引导；返回正常 |
| 预估 | 4h |

**具体步骤**：
1. 狗子 3D 宠物占满全屏
2. 互动按钮浮层（pet/feed/shake/bark）
3. 狗子台词气泡
4. mood/loveMeter 悬浮显示
5. 空状态引导（首次进入提示"摸摸狗子开始互动"）
6. 返回按钮（左上角，半透明圆形）

### P4-04：/pet/library 歌词库独立页

| 项 | 内容 |
|---|---|
| 任务 | 实现歌词库独立浏览页（从 /pet 歌词库态跳转） |
| 涉及 | `lib/pages/pet/pet_library_page.dart`（新建） |
| 依赖 | P4-02 |
| 验收 | 歌词列表完整；筛选/搜索/编辑/删除可用；空状态有引导 |
| 预估 | 4h |

**具体步骤**：
1. AppBar：标题"歌词库" + 搜索按钮
2. 筛选栏：style 筛选 Chip（全部/民谣/流行/DJ电音/国风/说唱）
3. 歌词卡片列表（Suno 式时间线，mono 字体）
4. 点击卡片 → 歌词详情页（展开完整歌词 + 编辑/删除/生成音乐）
5. 搜索模式：AppBar 切换为搜索框
6. 分页加载（下拉刷新 + 上拉加载更多）
7. 空状态：引导文案 + 创作台跳转按钮
8. 删除确认（软删除，可撤销 toast）

### P4-05：音乐播放与律动效果

| 项 | 内容 |
|---|---|
| 任务 | 实现音乐播放控件和宠物随音乐节奏律动效果 |
| 涉及 | `lib/core/services/tts_service.dart`（复用 just_audio）、`lib/widgets/pet/music_player.dart`（新建） |
| 依赖 | P4-02 |
| 验收 | 音乐可播放/暂停/进度拖动；播放时宠物律动 + 暖橙发光脉冲；不与 TTS 争抢音频焦点（单一 just_audio 实例） |
| 预估 | 6h |

**具体步骤**：

1. **音乐播放控件**：
   - 复用 `just_audio`（全局单例，避免与 TTS 双播放器争抢音频焦点）
   - 播放/暂停按钮（Lucide Play/Pause 图标）
   - 进度条（可拖动）
   - 时间显示（当前/总时长，mono 字体）
   - 音频来源：`/music/audio/<sha1>.mp3`（常规 HTTP 路径，非 data URI）

2. **宠物律动效果**：
   - 播放时狗子随播放进度产生节拍律动
   - 暖橙发光脉冲（`--ember` 色，非粉色）
   - 律动频率与音乐 BPM 关联（或固定 120BPM 节拍）
   - 暂停时律动停止

3. **音频焦点管理**：
   - 单一 `just_audio` 实例管理 TTS 和音乐播放
   - 音乐播放时暂停 TTS，TTS 播放时暂停音乐
   - 通话时（LiveKit）暂停所有播放

### P4-06：音乐模块端到端验证

| 项 | 内容 |
|---|---|
| 任务 | 完整走通音乐创作闭环：宠物互动 → 歌词生成 → 音乐生成 → 播放 → 好感回写 |
| 涉及 | 全部音乐模块 |
| 依赖 | P4-01~P4-05 |
| 验收 | 闭环端到端跑通；异常场景（API未配置/上游失败/并发限制）有正确错误提示 |
| 预估 | 4h |

---

## Phase 5：联调、测试与验收

> **目标**：前后端联调，全面测试，EARS 验收标准核对，P0 红线零违规，交付 Phase 1 MVP。
> **预估**：25-30 人时
> **依赖**：Phase 2（后端业务）、Phase 4（前端音乐模块）

### P5-01：前后端联调

| 项 | 内容 |
|---|---|
| 任务 | 前端与后端 8 个新端点联调，确认请求/响应/错误处理全部正常 |
| 涉及 | 前后端全部新功能 |
| 依赖 | P2-05, P4-06 |
| 验收 | 8 端点全部联调通过；签名鉴权正常；多用户隔离正常；错误状态正确显示 |
| 预估 | 8h |

**具体步骤**：
1. 启动后端（uvicorn）+ 前端（flutter run）
2. 逐个联调 8 个新端点：
   - GET /pet/state — 首次/已有状态
   - POST /pet/interact — 四种 action + 非法 action
   - POST /lyrics — 正常生成 + 内容过滤 + LLM失败(502)
   - GET /lyrics — 列表 + 筛选 + 分页
   - GET/PATCH/DELETE /lyrics/{id} — 详情/修改/软删除
   - POST /music/generate — 正常 + 去重 + 并发限制(429) + 日上限 + API未配置(503)
   - GET /music/jobs/{job_id} — 轮询 queued→running→succeeded/failed
   - DELETE /music/jobs/{job_id} — 取消排队任务
   - GET /music/audio/{filename} — 音频播放
   - GET /songs — 作品列表
   - DELETE /songs/{id} — 软删除+清理音频
3. 验证签名鉴权：错误签名/过期时间戳/重放 nonce 均返回 401
4. 验证多用户隔离：不同 user_id 数据互不干扰
5. 验证端到端闭环：互动→歌词→音乐→播放→好感回写

### P5-02：EARS 验收标准核对

| 项 | 内容 |
|---|---|
| 任务 | 逐条核对 PRD §10 的 11 条 EARS 验收标准 |
| 涉及 | 全部功能 |
| 依赖 | P5-01 |
| 验收 | EARS-01~11 全部通过；不通过项记录并修复 |
| 预估 | 6h |

**EARS 核对清单**：

| 编号 | 验收标准 | 验证方法 |
|---|---|---|
| EARS-01 | 每次陪聊对话后写入记忆历史并刷新五维好感度 | 发送消息 → 检查 /memory/today + /affinity |
| EARS-02 | 提交音乐生成 1 秒内返回 job_id + poll_after_ms，不同步阻塞 | 计时 POST /music/generate 响应时间 |
| EARS-03 | running 状态显示波形骨架，每 3 秒轮询直至终态 | 观察生成中 UI + 网络请求间隔 |
| EARS-04 | ACE Key 未配置/上游失败返回 503/502，不静默降级假数据 | 模拟未配置 Key + 模拟上游失败 |
| EARS-05 | 非法 action 返回 400；合法 action 返回纯文本台词+mood+affinity | 测试四种 action + 非法 action |
| EARS-06 | 播放中宠物节拍律动+暖橙发光脉冲，不与 TTS 争抢焦点 | 播放音乐 → 观察律动 → 触发 TTS → 确认焦点切换 |
| EARS-07 | 全项目使用 Lucide SVG 图标，Icons.*/emoji 出现次数为 0 | grep 验证 |
| EARS-08 | 无紫→粉跨色相渐变；深底为竹调深 #0E1512 | 视觉检查 + grep 验证 |
| EARS-09 | 空状态/引导态有具体可行动文案，无 Welcome to/Lorem/赋能 | grep + 视觉检查 |
| EARS-10 | 所有请求强制 HMAC 签名；签名失败返回 401；user_id 仅从头注入 | 测试签名失败 + 检查 URL 无 user_id |
| EARS-11 | MySQL 环境下歌词/宠物状态写入 db.py，不静默落本地 sqlite | 配置 MySQL → 验证数据写入 |

### P5-03：性能验证

| 项 | 内容 |
|---|---|
| 任务 | 验证 PRD 附录 A 的非功能性能要求 |
| 涉及 | 前后端 |
| 依赖 | P5-01 |
| 验收 | 首屏过渡 ≤300ms；首字流式延迟 ≤1.5s；API p95 ≤500ms |
| 预估 | 4h |

**具体步骤**：
1. 首屏过渡计时：/splash → /home 过渡时间 ≤300ms
2. 首字流式延迟：发送消息 → 第一个 text token 到达 ≤1.5s
3. API p95：抽样 20 次非流式接口调用，p95 ≤500ms（含签名校验）
4. 音乐生成轮询：确认轮询间隔 3s→8s 指数退避
5. 包体积：确认 APK 体积未显著膨胀（lucide_icons 按需引入）

### P5-04：合规与安全检查

| 项 | 内容 |
|---|---|
| 任务 | 验证数据合规、安全措施、PIPL 用户权利 |
| 涉及 | 前后端 |
| 依赖 | P5-01 |
| 验收 | 歌词/记忆加密存储；用户权利接口可用；AI 内容标识正常；C 盘禁装约束 |
| 预估 | 4h |

**具体步骤**：
1. 数据加密：验证 lyrics 正文加密落盘、出参解密
2. 用户权利：GET /user/export 导出全部数据；DELETE /user/data 删除全部数据
3. AI 内容标识：/chat/v2 起始 meta 事件包含 ai_generated:true
4. 内容过滤：违规输入返回 blocked 事件
5. C 盘禁装：验证 DATA_DIR/HF_HOME/MODELSCOPE_CACHE 均指向 F 盘
6. 音频落盘：验证音乐文件落 F 盘 DATA_DIR/audio/

### P5-05：最终验收与交付

| 项 | 内容 |
|---|---|
| 任务 | 全面回归测试，更新文档，交付 Phase 1 MVP |
| 涉及 | 全部 |
| 依赖 | P5-01~P5-04 |
| 验收 | 全部验收通过；文档更新；Release APK 可构建；无 P0 违规 |
| 预估 | 4h |

**具体步骤**：
1. 全量回归测试：原有 22 端点 + 新增 8 端点 + 13 页面 + 3 新路由
2. 更新技术文档：竹笌APP技术文档.md（新增音乐模块章节）
3. 更新 README.md
4. 构建 Release APK：`flutter build apk --release`（含 dart-define）
5. 模拟器安装验证
6. Git 提交 + 标签（phase1-mvp）
7. 交付清单整理

---

## 附录 A：任务依赖矩阵

| 任务 | 依赖 | 可并行 |
|---|---|---|
| P0-01 环境确认 | - | - |
| P0-02 IndexTTS修复 | P0-01 | - |
| P0-03 设计令牌落地 | P0-01 | 与 P0-04 并行 |
| P0-04 图标基础设施 | P0-01 | 与 P0-03 并行 |
| P1-01 main.py拆router | P0-01 | 与 Phase 3 并行 |
| P1-02 db.py扩展 | P1-01 | - |
| P1-03 配置鉴权确认 | P1-01 | 与 P1-02 并行 |
| P1-04 后端模块化验证 | P1-01~03 | - |
| P2-01 宠物模块 | P1-02 | 与 P2-02 部分并行 |
| P2-02 歌词模块 | P1-02, P1-03 | 与 P2-01 并行 |
| P2-03 音乐生成模块 | P1-02, P1-03, P2-02 | - |
| P2-04 作品模块 | P2-03 | - |
| P2-05 OpenAPI契约验证 | P2-01~04 | - |
| P3-01 图标全量迁移 | P0-04 | 与 Phase 1 并行 |
| P3-02 硬编码色值清零 | P0-03 | 与 P3-01 部分并行 |
| P3-03 P0红线整改 | P3-01, P3-02 | - |
| P3-04 现有页面重设计 | P3-01~03 | - |
| P4-01 状态管理服务层 | P3-01, P3-02 | 与 Phase 2 并行（mock） |
| P4-02 /pet主页三态 | P4-01 | - |
| P4-03 /pet/full全屏 | P4-02 | - |
| P4-04 /pet/library | P4-02 | 与 P4-03 并行 |
| P4-05 播放律动效果 | P4-02 | 与 P4-03/04 并行 |
| P4-06 端到端验证 | P4-01~05 | - |
| P5-01 前后端联调 | P2-05, P4-06 | - |
| P5-02 EARS验收 | P5-01 | 与 P5-03/04 并行 |
| P5-03 性能验证 | P5-01 | 与 P5-02/04 并行 |
| P5-04 合规安全检查 | P5-01 | 与 P5-02/03 并行 |
| P5-05 最终验收交付 | P5-01~04 | - |

---

## 附录 B：风险登记册

| 风险 | 概率 | 影响 | 缓解措施 |
|---|---|---|---|
| IndexTTS torch 下载超时/失败 | 高 | 高（阻断语音能力） | 使用国内镜像；预留备用 TTS（MiniMax在线）；降级方案已就绪 |
| ACE Music API Key 获取延迟 | 中 | 高（阻断音乐生成） | Phase 2 可先基于 mock 开发；Key 到位后切换 |
| 图标迁移遗漏导致 UI 异常 | 中 | 中 | grep CI 拦截；逐页面视觉验证 |
| 硬编码色值遗漏导致视觉不一致 | 中 | 中 | grep CI 拦截；浅/深色模式截图对比 |
| 后端拆 router 引入回归 | 中 | 高 | 全面回归测试 22 端点；逐端点对比 |
| 音乐生成上游不稳定 | 中 | 中 | 异步 job 架构；失败可重试；日上限保护 |
| 前后端联调契约不一致 | 中 | 中 | OpenAPI 契约先行；前端基于契约 mock 开发 |
| 包体积膨胀（lucide_icons） | 低 | 低 | 按需引入；tree shaking 验证 |
| MySQL 兼容性问题 | 低 | 中 | SQLAlchemy Core 双兼容；pool_pre_ping 重连 |

---

## 附录 C：交付物清单

| 交付物 | 位置 | 阶段 |
|---|---|---|
| 后端模块化代码 | `F:/zhuyapp-backend/routers/` | Phase 1 |
| 后端业务模块 | `F:/zhuyapp-backend/{music_provider,lyrics_composer,job_queue}.py` | Phase 2 |
| 前端设计令牌 | `lib/core/theme/app_theme.dart` | Phase 0/3 |
| 前端图标门面 | `lib/widgets/app_icon.dart` | Phase 0/3 |
| 前端音乐模块 | `lib/pages/pet/`、`lib/widgets/pet/` | Phase 4 |
| 前端状态管理 | `lib/presentation/providers/{pet,music}_provider.dart` | Phase 4 |
| 更新后的技术文档 | `docs/竹笌APP技术文档.md` | Phase 5 |
| Release APK | `build/app/outputs/flutter-apk/app-release.apk` | Phase 5 |
| Git 标签 | `phase1-mvp` | Phase 5 |

---

*本文档基于 phase1 六份设计文档 + 现有代码实读状态编制。任务粒度按 1-4 小时可验证单元拆分，每个任务都有明确的验收标准。实施过程中如遇阻塞或需求变更，应及时更新本文档并通知相关方。*

# 竹笌后端（ZhuyApp Backend）

「竹笌」是一款 2D 虚拟角色语音陪聊 App 的**后端服务**，与前端仓库
[`idiot-dog`（Flutter）](https://github.com/missgl520/idiot-dog) 配套。
后端负责：流式对话（SSE）、长期记忆、好感度、情绪识别、角色切换、语音通话令牌。

> 原开发文档里写的后端仓库 `missgl520/zhuyapp-backend` 已不存在，本目录是
> 依据前端源码逐接口补齐的最小可用后端实现（契约 100% 对齐）。

## 接口契约（与前端对齐）

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/health` | 健康检查，返回 200 |
| GET | `/` | 服务信息（agnes 是否开启、当前 persona） |
| POST | `/wake-word` | 同步唤醒词 `{word}` |
| POST | `/persona` | 切换角色 `{persona: gentle/playful/wise}` |
| POST | `/emotion` | 情绪识别 `{text}` → `{emotion,confidence,scores}` |
| POST | `/chat/v2` | **SSE 流式对话**：`text` / `emotion` / `affinity` / `done` 事件 |
| GET | `/memory/today` | 今日记忆 `{memories:[...]}` |
| GET | `/memory/search` | 搜索记忆，返回 `{count, results, memories}` |
| GET | `/memory/summaries` | 每日摘要 `{summaries:[...]}` |
| POST | `/memory` | 存储一条记忆（兜底） |
| POST | `/memory/clear` | 清空全部记忆 |
| DELETE | `/memory?category=` | 清空某分类 |
| GET | `/affinity` | 好感度 `{trust,intimacy,familiarity,total_interactions,streak_days}` |
| GET | `/livekit/connect` | 语音通话连接信息 `{livekit_url, token}` |
| GET | `/legal/privacy` | 隐私政策（Markdown，公开） |
| GET | `/legal/terms` | 用户协议（Markdown，公开） |
| GET | `/user/export` | 导出当前用户全部个人数据（访问/可携带权） |
| DELETE | `/user/data` | 删除当前用户全部个人数据（删除权） |
| PUT | `/memory/{id}` | 更正某条本人记忆内容（更正权） |

### `/chat/v2` SSE 事件格式

```
event: text
data: {"text": "你"}

event: emotion
data: {"emotion": "happy", "confidence": 0.9}

event: affinity
data: {"trust": 30.5, "intimacy": 20.8, "familiarity": 5.3, "total_interactions": 1, "streak_days": 1}

event: done
data: {}
```

## 运行

```bash
# 1. 安装依赖（建议虚拟环境）
python -m venv venv
source venv/Scripts/activate        # Windows
pip install -r requirements.txt

# 2. 配置环境变量
cp .env.example .env
#   编辑 .env：填入 AGNES_API_KEY（可选，留空走 mock 演示）

# 3. 启动
uvicorn main:app --host 0.0.0.0 --port 8000
```

启动后接口示例：

```bash
curl http://localhost:8000/health
curl -N -X POST http://localhost:8000/chat/v2 \
  -H 'Content-Type: application/json' \
  -d '{"message":"你好呀","history":[],"temperature":0.8,"max_tokens":500}'
```

## 两种模式

- **真实对话（推荐）**：在 `.env` 填入 `AGNES_API_KEY`（国内版见
  `apihub.agnes-ai.cn`），`/chat/v2` 会直连 Agnes 大模型流式生成回复。
  Agnes 异常时自动降级为演示回复，App 不中断。可选 `AGNES_USE_CN`（默认 true）、
  `AGNES_MODEL`（默认 agnes-2.0-flash）。
- **Mock 演示模式**：不填 key 也能跑通完整对话流程（演示角色化回复），
  便于本地联调与演示，无需任何外部账号。

### 接入真实 Agnes（让对话变真）

```bash
# .env
AGNES_API_KEY=你的_agnes_key
AGNES_USE_CN=true            # 国内版（默认）；国际版填 false
AGNES_MODEL=agnes-2.0-flash
```

重启后端后 `/chat/v2` 即走真实大模型（`/` 返回的 `agnes_enabled` 变为 true）。
真实模式下，`/chat/v2` 会把该用户**近期长期记忆**注入 system prompt，
使竹笌跨会话记得你（见下节）。

### 接入真实 LiveKit（语音通话）

```bash
# .env
LIVEKIT_URL=wss://你的.livekit.server
LIVEKIT_API_KEY=你的_api_key
LIVEKIT_API_SECRET=你的_api_secret
```

填齐三件套后，`GET /livekit/connect` 返回 `available:true` 与有效 JWT
令牌（HS256，含 `room`/`roomJoin`/`canPublish`/`canSubscribe` 授权），
前端据此连入语音房。缺任意一项则返回 `available:false`（语音通话降级关闭），
不影响其他功能。

## 已增强能力（v1.2）

- **对话长期记忆注入**：`/chat/v2` 在生成回复前自动拉取该用户近期记忆
  （最近 12 条 + 今日摘要），注入 system prompt。竹笌因而**跨会话记得用户**
  （例如记得你说过的事、偏好）。mock 模式下注入不影响兜底文本；真实 Agnes
  模式下直接生效。后端日志会打印 `[memory] user=xxx injected N memories`。
- **情绪识别优化**：`/chat/v2` 的 `emotion` 事件改为识别**用户输入**（而非
  竹笌回复），并给 `happy/sad/angry` 等强情绪词加权、并列时优先，避免被
  回复里常见的问句词（curious）反超。独立 `POST /emotion` 接口同样生效。
- **记忆检索增强**：`/memory/search` 支持 `category` 可选过滤，结果按
  相关性（命中词数 + 重要性 + 时间新近）降序排序。前端不传 `category` 时兼容。
- **记忆摘要增强**：`/memory/summaries` 解密记忆内容并聚合为每日规则摘要
  （修复了此前直接返回密文的 bug），返回 `summary` 字段供前端展示。

## 前端对接

前端默认后端地址是穿透域名 `loca.lt`/`trycloudflare.com`（每次重启会变）。
本地联调时把 App 的「后端地址」改成你后端可达地址，例如：

- 模拟器：`http://10.0.2.2:8000`
- 真机（同一局域网）：`http://<你的内网IP>:8000`
- 或部署后改用固定域名

在 `F:\zhuyapp\lib\core\config.dart` 中也可修改 `_defaultBaseUrl` 的硬编码默认值。

## 安全与合规（v1.1）

为通过生成式 AI 服务安全评估与《个人信息保护法》要求，后端已加入：

- **接口签名鉴权**：除公开路径（`/health`、`/docs`、`/legal/*` 等）外，所有请求须携带
  `X-Api-Key` / `X-Timestamp` / `X-Nonce` / `X-Signature` / `X-User-Id` 头。
  签名为 `HMAC-SHA256(API_KEY, "METHOD\nPATH\nTIMESTAMP\nNONCE\nSHA256(BODY)")`，
  含时间戳容差与 nonce 重放防护。详见 `auth.py`。
- **多用户数据隔离**：记忆与好感度均按 `user_id` 存于统一加密库（SQLite/MySQL），读写均按 `user_id` 过滤，互不混存。
- **AI 内容标识**：`/chat/v2` 在流式起始下发 `meta` 事件标注 `ai_generated:true`。
- **违规内容前置过滤**：用户输入命中高危词时在 `chat/v2` 返回 `blocked` 事件（MVP，生产建议接入专业内容安全服务）。
- **用户权利接口**：`/user/export`、`/user/data`、`PUT /memory/{id}`。
- **静态加密（at-rest）**：个人数据落盘加密。`memory_store` 的 `content` 字段、
  `affinity_store` 的 JSON 文件均以 `cryptography.Fernet` 对称加密存储；
  密钥优先取环境变量 `ZHUYU_ENC_KEY`，否则首次运行在 `data/.enc_key` 自动生成
  （已 gitignore）。因密文无法 `LIKE` 检索，`/memory/search` 改为内存解密后过滤，
  对单用户个人数据量完全可接受。详见 `encryption.py`。
- **密钥管理**：建议生产显式设置 `ZHUYU_ENC_KEY`（base64 32 字节 Fernet key）；
  若使用本地自动生成密钥，迁移服务器时务必一并带走 `data/.enc_key`，否则旧数据无法解密。

### 生产部署必做

1. 设置强随机 `ZHUYU_API_KEY`，前端构建用
   `--dart-define=ZHUYU_API_KEY=<相同值>` 同步。
2. 设置 `ALLOWED_ORIGINS` 为具体域名（不要用 `*`）。
3. 在 `legal/` 目录填写正式的《隐私政策》《用户协议》（已是模板，含 `【请填写…】` 占位）；
   上线前在 `.env` 设置 `OPERATOR_NAME`、`PRIVACY_CONTACT_EMAIL`、`SERVICE_CONTACT_EMAIL`，
   后端 `/legal/*` 接口返回时自动替换占位（见 `config.py` 与 `main.py:_read_legal`）。
4. 完成算法备案与安全评估（向网信办）、国际版数据出境标准合同等法定程序。

## 目录结构

```
zhuyapp-backend/
├── main.py            # FastAPI 应用与全部路由
├── config.py          # 配置（读 .env）
├── auth.py            # 接口签名鉴权（API Key + 请求签名）
├── encryption.py      # 静态加密（at-rest，Fernet）
├── content_moderation.py # 违规内容前置过滤（MVP）
├── agnes_client.py    # Agnes 流式对话 + mock 兜底
├── emotion_engine.py  # 规则情绪识别
├── affinity_store.py  # 好感度持久化（按 user_id 加密表）
├── memory_store.py    # 记忆持久化（SQLite/MySQL，按 user_id 隔离）
├── livekit_token.py   # LiveKit 令牌生成
├── requirements.txt
├── .env.example
├── legal/             # 隐私政策 / 用户协议（Markdown）
└── data/              # 运行时生成（zhuyu.db / .enc_key / state.json / server.log）
```

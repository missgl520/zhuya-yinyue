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

- **真实对话（推荐）**：在 `.env` 填入 `AGNES_API_KEY`，`/chat/v2` 会直连
  Agnes 大模型流式生成回复。Agnes 异常时自动降级为演示回复，App 不中断。
- **Mock 演示模式**：不填 key 也能跑通完整对话流程（演示角色化回复），
  便于本地联调与演示，无需任何外部账号。

## 前端对接

前端默认后端地址是穿透域名 `loca.lt`/`trycloudflare.com`（每次重启会变）。
本地联调时把 App 的「后端地址」改成你后端可达地址，例如：

- 模拟器：`http://10.0.2.2:8000`
- 真机（同一局域网）：`http://<你的内网IP>:8000`
- 或部署后改用固定域名

在 `F:\zhuyapp\lib\core\config.dart` 中也可修改 `_defaultBaseUrl` 的硬编码默认值。

## 目录结构

```
zhuyapp-backend/
├── main.py            # FastAPI 应用与全部路由
├── config.py          # 配置（读 .env）
├── agnes_client.py    # Agnes 流式对话 + mock 兜底
├── emotion_engine.py  # 规则情绪识别
├── affinity_store.py  # 好感度持久化（JSON）
├── memory_store.py    # 记忆持久化（SQLite）
├── livekit_token.py   # LiveKit 令牌生成
├── requirements.txt
├── .env.example
└── data/              # 运行时生成（affinity.json / zhuyu_memory.db / state.json）
```

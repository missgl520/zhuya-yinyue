# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 竹笌后端离线冒烟测试
#
# 设计目标：不依赖外网 / 不依赖真实大模型，可在 CI 或本地秒级跑通。
#   - ZHUYU_API_KEY=""   -> 开发模式，跳过请求签名
#   - AGNES_API_KEY=""   -> 强制 mock 演示模式，离线可跑
#
# 运行方式（在后端仓库根目录）：
#   python -m pytest tests/ -q
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import os

os.environ["ZHUYU_API_KEY"] = ""  # 开发模式：跳过签名校验
os.environ["AGNES_API_KEY"] = ""  # 强制 mock 模式：不连外网大模型

import asyncio

import main  # noqa: E402  (import 前已设好 env)
from agnes_client import build_mock_reply, mock_stream  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

client = TestClient(main.app)


# ── 基础健康 ──
def test_root_ok():
    r = client.get("/")
    assert r.status_code == 200
    body = r.json()
    assert body["service"] == "zhuyapp-backend"
    assert "agnes_enabled" in body


def test_health_ok():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


# ── 流式对话（mock 模式）──
def test_chat_v2_streams_text():
    r = client.post("/chat/v2", json={"message": "你好"})
    assert r.status_code == 200
    ct = r.headers.get("content-type", "")
    assert "text/event-stream" in ct
    assert "event: meta" in r.text  # 生成式 AI 标识
    assert "event: text" in r.text  # 真实产出文本片段


# ── 情绪识别 ──
def test_emotion_endpoint():
    r = client.post("/emotion", json={"text": "我今天很开心"})
    assert r.status_code == 200
    body = r.json()
    assert isinstance(body, dict)
    assert body.get("label") or body.get("emotion") or body.get("category")


# ── 角色 / 唤醒词设置 ──
def test_persona_set_and_get():
    r = client.post("/persona", json={"persona": "wise"})
    assert r.status_code == 200
    assert r.json().get("ok") is True
    r2 = client.get("/")
    assert r2.json().get("persona") == "wise"
    # 还原为默认，避免影响其他测试
    client.post("/persona", json={"persona": "gentle"})


# ── mock 文本生成单元 ──
def test_mock_reply_contains_message():
    out = build_mock_reply("测试一下")
    assert "测试一下" in out


def test_mock_stream_yields_text():
    async def collect():
        return "".join([t async for t in mock_stream("hi")])

    txt = asyncio.run(collect())
    assert "hi" in txt

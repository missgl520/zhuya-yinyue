# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 竹笌后端主程序（main.py）
#
# FastAPI 应用，与前端 F:\zhuyapp 的接口契约完全对齐。
# 运行：uvicorn main:app --host 0.0.0.0 --port 8000
#
# 接口总览：
#   GET  /health                 健康检查
#   POST /wake-word              同步唤醒词
#   POST /persona                切换情感角色(gentle/playful/wise)
#   POST /emotion                情绪识别 {text} -> {emotion,confidence,scores}
#   POST /chat/v2  (SSE)         流式对话：text / emotion / affinity / done 事件
#   GET  /memory/today           今日记忆
#   GET  /memory/search          搜索记忆(同时返回 memories + results + count)
#   GET  /memory/summaries       每日摘要
#   POST /memory                 存储一条记忆(兜底)
#   POST /memory/clear           清空记忆
#   DELETE /memory               清空某分类
#   GET  /affinity               好感度
#   GET  /livekit/connect        获取语音通话连接信息
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import json
import os

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse

import affinity_store
import agnes_client
import emotion_engine
import livekit_token
import memory_store
from config import settings

app = FastAPI(title="竹笌后端 (ZhuyApp Backend)", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# 初始化存储
memory_store.init()
os.makedirs(settings.DATA_DIR, exist_ok=True)
STATE_FILE = os.path.join(settings.DATA_DIR, "state.json")


# ── 运行时状态（persona / wake_word）──
def load_state() -> dict:
    try:
        with open(STATE_FILE, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {"persona": settings.PERSONA_DEFAULT,
                "wake_word": settings.WAKE_WORD_DEFAULT}


def save_state(state: dict) -> None:
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


def sse(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


# ════════════════════════════════════════════════════════
# 健康检查 & 基础配置
# ════════════════════════════════════════════════════════

@app.get("/")
def root():
    state = load_state()
    return {
        "service": "zhuyapp-backend",
        "status": "ok",
        "agnes_enabled": settings.has_agnes,
        "persona": state.get("persona", settings.PERSONA_DEFAULT),
        "wake_word": state.get("wake_word", settings.WAKE_WORD_DEFAULT),
    }


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/wake-word")
async def wake_word(request: Request):
    body = await request.json()
    word = (body.get("word") or "").strip()
    if not word:
        return JSONResponse({"ok": False, "error": "word 不能为空"}, status_code=400)
    state = load_state()
    state["wake_word"] = word
    save_state(state)
    return {"ok": True, "wake_word": word}


@app.post("/persona")
async def set_persona(request: Request):
    body = await request.json()
    persona = body.get("persona")
    if persona not in ("gentle", "playful", "wise"):
        return JSONResponse(
            {"ok": False, "error": "persona 必须是 gentle/playful/wise"},
            status_code=400,
        )
    state = load_state()
    state["persona"] = persona
    save_state(state)
    return {"ok": True, "persona": persona}


@app.post("/emotion")
async def emotion(request: Request):
    body = await request.json()
    text = body.get("text", "")
    return emotion_engine.detect_emotion(text)


# ════════════════════════════════════════════════════════
# 流式对话（SSE）
# ════════════════════════════════════════════════════════

@app.post("/chat/v2")
async def chat_v2(request: Request):
    body = await request.json()
    message = (body.get("message") or "").strip()
    history = body.get("history", []) or []
    system_prompt = body.get("system_prompt")
    temperature = float(body.get("temperature", 0.8))
    max_tokens = int(body.get("max_tokens", 500))

    state = load_state()
    persona = state.get("persona", settings.PERSONA_DEFAULT)

    async def event_gen():
        full_text = ""
        try:
            if settings.has_agnes:
                msgs = []
                if system_prompt:
                    msgs.append({"role": "system", "content": system_prompt})
                for h in history:
                    msgs.append({
                        "role": h.get("role", "user"),
                        "content": h.get("content", ""),
                    })
                msgs.append({"role": "user", "content": message})
                async for tok in agnes_client.stream_agnes(msgs, temperature, max_tokens):
                    full_text += tok
                    yield sse("text", {"text": tok})
            else:
                async for tok in agnes_client.mock_stream(message, persona):
                    full_text += tok
                    yield sse("text", {"text": tok})
        except Exception:
            # Agnes 失败则降级到 mock，保证 App 仍有回复
            async for tok in agnes_client.mock_stream(message, persona):
                full_text += tok
                yield sse("text", {"text": tok})

        # 情绪识别
        emo = emotion_engine.detect_emotion(full_text)
        yield sse("emotion", emo)

        # 持久化记忆：用户消息 + 竹笌回复
        if message:
            memory_store.store("user", message, category="user_memory")
        if full_text:
            memory_store.store("assistant", "竹笌：" + full_text, category="chat_memory")

        # 好感度更新
        aff = affinity_store.bump_after_chat()
        yield sse("affinity", aff)

        yield sse("done", {})

    return StreamingResponse(
        event_gen(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


# ════════════════════════════════════════════════════════
# 记忆接口
# ════════════════════════════════════════════════════════

@app.get("/memory/today")
def memory_today():
    return {"memories": memory_store.get_today()}


@app.get("/memory/search")
def memory_search(q: str = "", mode: str = "keyword", limit: int = 20):
    mems = memory_store.search(q, limit) if q else []
    results = [{"content": m["content"], "category": m["category"]} for m in mems]
    # 同时满足两个前端调用方：BackendService 读 memories，MemoryService 读 results+count
    return {"count": len(mems), "results": results, "memories": mems}


@app.get("/memory/summaries")
def memory_summaries():
    return {"summaries": memory_store.summaries()}


@app.post("/memory")
async def memory_store_one(request: Request):
    body = await request.json()
    role = body.get("role", "user")
    content = body.get("content", "")
    category = body.get("category", "chat_memory")
    if not content:
        return JSONResponse({"ok": False, "error": "content 不能为空"}, status_code=400)
    mid = memory_store.store(role, content, category)
    return {"ok": True, "id": mid}


@app.post("/memory/clear")
def memory_clear():
    memory_store.clear_all()
    return {"ok": True}


@app.delete("/memory")
def memory_delete_category(category: str = ""):
    if category:
        memory_store.clear_category(category)
    else:
        memory_store.clear_all()
    return {"ok": True}


# ════════════════════════════════════════════════════════
# 好感度
# ════════════════════════════════════════════════════════

@app.get("/affinity")
def affinity():
    return affinity_store.load()


# ════════════════════════════════════════════════════════
# LiveKit 语音通话连接信息
# ════════════════════════════════════════════════════════

@app.get("/livekit/connect")
def livekit_connect(room: str = "zhuyapp-voice", user_id: str = ""):
    token = livekit_token.generate_token(room, user_id)
    if token is None:
        return {"available": False,
                "message": "LiveKit 未配置（请在 .env 设置 LIVEKIT_URL/API_KEY/API_SECRET）"}
    return {"available": True, "livekit_url": settings.LIVEKIT_URL, "token": token}

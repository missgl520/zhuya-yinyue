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

import datetime
import json
import os

from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, PlainTextResponse, StreamingResponse

import affinity_store
import agnes_client
import auth
import content_moderation
import db
import encryption
import emotion_engine
import livekit_token
import memory_store
from config import BASE_DIR, settings
from sqlalchemy import text

app = FastAPI(
    title="竹笌后端 (ZhuyApp Backend)",
    version="1.1.0",
    # 全路由统一签名鉴权（公开路径在 auth.verify_request 内白名单放行）
    dependencies=[Depends(auth.verify_request)],
)


def _cors_origins() -> list:
    # 生产【必须】通过环境变量 ALLOWED_ORIGINS 指定具体域名（逗号分隔）；
    # 未配置时不使用通配符 "*"，仅放行常见本地来源（移动端不受 CORS 限制）。
    if settings.ALLOWED_ORIGINS:
        return settings.ALLOWED_ORIGINS
    return [
        "http://localhost", "http://127.0.0.1",
        "http://localhost:3000", "http://localhost:8080", "http://localhost:5000",
        "https://chilly-sloths-jump.loca.lt",
    ]


app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins(),
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    allow_credentials=False,
)

# 法律文本目录（隐私政策 / 用户协议）
LEGAL_DIR = os.path.join(BASE_DIR, "legal")

# 初始化存储（统一 SQLite：memories / affinity / kv）
db.init()


# ── 运行时状态（persona / wake_word），持久化到数据库 kv 表（值加密）──
def load_state() -> dict:
    with db.conn() as c:
        rows = c.execute(
            text("SELECT `key`, value FROM kv WHERE `key` IN ('persona', 'wake_word')")
        ).fetchall()
    stored = {r.key: encryption.decrypt(r.value) for r in rows}
    return {
        "persona": stored.get("persona", settings.PERSONA_DEFAULT),
        "wake_word": stored.get("wake_word", settings.WAKE_WORD_DEFAULT),
    }


def save_state(state: dict) -> None:
    with db.conn() as c:
        is_mysql = c.dialect.name == "mysql"
        for k in ("persona", "wake_word"):
            if k not in state:
                continue
            if is_mysql:
                c.execute(
                    text(
                        "INSERT INTO kv(`key`, value) VALUES (:k, :v) "
                        "ON DUPLICATE KEY UPDATE value = :v"
                    ),
                    {"k": k, "v": encryption.encrypt(str(state[k]))},
                )
            else:
                # SQLite 不支持 ON DUPLICATE KEY UPDATE，用 INSERT OR REPLACE
                c.execute(
                    text(
                        "INSERT OR REPLACE INTO kv(`key`, value) VALUES (:k, :v)"
                    ),
                    {"k": k, "v": encryption.encrypt(str(state[k]))},
                )
        c.commit()


def sse(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


# ── 角色默认系统提示（前端未传 system_prompt 时使用）──
_PERSONA_PROMPTS = {
    "gentle": "你是竹笌，一位温柔体贴的 2D 虚拟陪伴角色。你说话轻声细语、善于倾听，会记得和用户的点滴。",
    "playful": "你是竹笌，一位俏皮阳光的 2D 虚拟陪伴角色。你活泼爱用语气词，喜欢逗用户开心，也会认真记住用户说的事。",
    "wise": "你是竹笌，一位沉稳睿智的 2D 虚拟陪伴角色。你说话不紧不慢、有见地，会结合与用户的过往给出真诚的建议。",
}


def _build_memory_context(user_id: str) -> str:
    """拉取该用户近期记忆，格式化为系统提示上下文，让角色跨会话记得用户。"""
    try:
        mems = memory_store.search(q="", limit=12, user_id=user_id)
    except Exception:
        return ""
    if not mems:
        return ""
    lines = []
    for m in mems[:10]:
        role_label = "用户" if m.get("category") == "user_memory" else "竹笌"
        lines.append(f"- {role_label}：{m['content'][:80]}")
    return "\n".join(lines)


def _compose_system_prompt(persona: str, frontend_prompt: str, memory_ctx: str) -> str:
    """合成最终 system prompt：角色设定 + 长期记忆上下文。"""
    base = frontend_prompt or _PERSONA_PROMPTS.get(persona, _PERSONA_PROMPTS["gentle"])
    if memory_ctx:
        base += "\n\n【你与用户的过往记忆（请自然融入对话，不要生硬提及）】\n" + memory_ctx
    return base


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

    # 多用户隔离：从签名中间件注入的 user_id 取用户标识
    user_id = getattr(request.state, "user_id", "default")

    state = load_state()
    persona = state.get("persona", settings.PERSONA_DEFAULT)

    async def event_gen():
        # ── 违法内容前置过滤（用户输入）──
        blocked, reason = content_moderation.moderate(message)
        if blocked:
            yield sse("blocked", {"reason": reason})
            yield sse("done", {})
            return

        # 生成式 AI 内容标识（暂行办法第九条）
        yield sse("meta", {
            "ai_generated": True,
            "service": "竹笌",
            "notice": "本内容为人工智能生成",
        })

        full_text = ""
        try:
            # 拉取长期记忆，注入对话上下文（让竹笌跨会话记得用户）
            memory_ctx = _build_memory_context(user_id)
            sys_prompt = _compose_system_prompt(persona, system_prompt or "", memory_ctx)
            if memory_ctx:
                print(
                    f"[memory] user={user_id} injected "
                    f"{memory_ctx.count(chr(10)) + 1} memories",
                    flush=True,
                )

            if settings.has_agnes:
                msgs = []
                if sys_prompt:
                    msgs.append({"role": "system", "content": sys_prompt})
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

        # 情绪识别：基于【用户输入】识别，更准确驱动角色表情
        # （对竹笌自身回复识别会偏，因为兜底回复常含「吗？」等问句词）
        emo = emotion_engine.detect_emotion(message or full_text)
        yield sse("emotion", emo)

        # 持久化记忆：用户消息 + 竹笌回复（按 user_id 隔离）
        if message:
            memory_store.store("user", message, category="user_memory", user_id=user_id)
        if full_text:
            memory_store.store(
                "assistant", "竹笌：" + full_text, category="chat_memory", user_id=user_id
            )

        # 好感度更新（按 user_id 隔离）
        aff = affinity_store.bump_after_chat(user_id)
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
def memory_today(request: Request):
    user_id = getattr(request.state, "user_id", "default")
    return {"memories": memory_store.get_today(user_id)}


@app.get("/memory/search")
def memory_search(request: Request, q: str = "", mode: str = "keyword",
                  category: str = "", limit: int = 20):
    user_id = getattr(request.state, "user_id", "default")
    mems = memory_store.search(q=q, category=category, limit=limit, user_id=user_id)
    results = [{"content": m["content"], "category": m["category"]} for m in mems]
    # 同时满足两个前端调用方：BackendService 读 memories，MemoryService 读 results+count
    return {"count": len(mems), "results": results, "memories": mems}


@app.get("/memory/summaries")
def memory_summaries(request: Request):
    user_id = getattr(request.state, "user_id", "default")
    return {"summaries": memory_store.summaries(user_id)}


@app.post("/memory")
async def memory_store_one(request: Request):
    user_id = getattr(request.state, "user_id", "default")
    body = await request.json()
    role = body.get("role", "user")
    content = body.get("content", "")
    category = body.get("category", "chat_memory")
    if not content:
        return JSONResponse({"ok": False, "error": "content 不能为空"}, status_code=400)
    mid = memory_store.store(role, content, category, user_id=user_id)
    return {"ok": True, "id": mid}


@app.put("/memory/{mem_id}")
async def memory_update(mem_id: int, request: Request):
    """用户更正其个人记忆内容（PIPL 更正权）。仅允许修改本人记录。"""
    user_id = getattr(request.state, "user_id", "default")
    body = await request.json()
    content = (body.get("content") or "").strip()
    if not content:
        return JSONResponse({"ok": False, "error": "content 不能为空"}, status_code=400)
    ok = memory_store.update_content(mem_id, content, user_id)
    if not ok:
        return JSONResponse(
            {"ok": False, "error": "记录不存在或不属于该用户"}, status_code=404
        )
    return {"ok": True}


@app.post("/memory/clear")
def memory_clear(request: Request):
    user_id = getattr(request.state, "user_id", "default")
    memory_store.clear_all(user_id)
    return {"ok": True}


@app.delete("/memory")
def memory_delete_category(request: Request, category: str = ""):
    user_id = getattr(request.state, "user_id", "default")
    if category:
        memory_store.clear_category(category, user_id)
    else:
        memory_store.clear_all(user_id)
    return {"ok": True}


# ════════════════════════════════════════════════════════
# 好感度
# ════════════════════════════════════════════════════════

@app.get("/affinity")
def affinity(request: Request):
    user_id = getattr(request.state, "user_id", "default")
    return affinity_store.load(user_id)


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


# ════════════════════════════════════════════════════════
# 法律文本 & 用户数据权利（PIPL）
# ════════════════════════════════════════════════════════

def _read_legal(filename: str) -> str:
    path = os.path.join(LEGAL_DIR, filename)
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except FileNotFoundError:
        return f"# {filename} 未找到\n请先在 legal/ 目录放置对应文档。"

    # 将文档模板中的占位标记替换为运营方配置（来源：.env → config.py）
    return (
        text.replace("【请填写运营主体名称】", settings.OPERATOR_NAME)
        .replace("【请填写隐私联系邮箱】", settings.PRIVACY_CONTACT_EMAIL)
        .replace("【请填写服务联系邮箱】", settings.SERVICE_CONTACT_EMAIL)
    )


@app.get("/legal/privacy", include_in_schema=True)
def legal_privacy():
    """隐私政策（Markdown）。"""
    return PlainTextResponse(
        _read_legal("privacy_policy.md"),
        media_type="text/markdown; charset=utf-8",
    )


@app.get("/legal/terms", include_in_schema=True)
def legal_terms():
    """用户协议（Markdown）。"""
    return PlainTextResponse(
        _read_legal("terms_of_service.md"),
        media_type="text/markdown; charset=utf-8",
    )


@app.get("/user/export")
def user_export(request: Request):
    """导出该用户全部个人数据（访问 / 可携带权）。"""
    user_id = getattr(request.state, "user_id", "default")
    return {
        "user_id": user_id,
        "memories": memory_store.export_all(user_id),
        "affinity": affinity_store.load(user_id),
        "exported_at": datetime.datetime.now().isoformat(timespec="seconds"),
    }


@app.delete("/user/data")
def user_data_delete(request: Request):
    """删除该用户全部个人数据（删除权）。"""
    user_id = getattr(request.state, "user_id", "default")
    memory_store.clear_all(user_id)
    affinity_store.reset(user_id)
    return {"ok": True, "user_id": user_id}

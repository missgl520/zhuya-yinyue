# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 流式对话路由（SSE）
# POST /chat/v2   流式对话：text / emotion / affinity / meta / blocked / done 事件
#
# 包含角色设定、指令遵循约束、长期记忆注入、Agnes 流式生成、
# 情绪识别、记忆持久化、好感度更新等完整对话逻辑。
# 从 main.py 拆分而来。
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import json

from fastapi import APIRouter, Request
from fastapi.responses import StreamingResponse

import affinity_store
import agnes_client
import content_moderation
import emotion_engine
import memory_store
from app_state import load_state
from config import settings

router = APIRouter(tags=["chat"])


def sse(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


# 角色默认系统提示（前端未传 system_prompt 时使用）
_PERSONA_PROMPTS = {
    "gentle": "你是竹笌，一位温柔体贴的 2D 虚拟陪伴角色。你轻声细语、真诚回应，语气自然不刻意。",
    "playful": "你是竹笌，一位俏皮阳光的 2D 虚拟陪伴角色。你活泼爱用语气词，喜欢逗用户开心。",
    "wise": "你是竹笌，一位沉稳睿智的 2D 虚拟陪伴角色。你说话有见地，会给出真诚建议。",
}

# 指令遵循约束：让模型在保持角色的同时，真正响应"背诗/算数/翻译/写作"等明确任务
_INSTRUCTION_GUARD = (
    "\n\n【指令遵循】当用户提出具体、明确的需求（如背诵诗词文章、解答问题、计算、"
    "翻译、写作、编程、解释概念等）时，请优先完成该需求，再用你的一贯语气自然衔接，"
    "不要回避或仅用陪伴话术带过。保持角色语气，但务必响应用户的真实意图。"
)


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
    """合成最终 system prompt：角色设定 + 指令遵循约束 + 长期记忆上下文。"""
    base = frontend_prompt or _PERSONA_PROMPTS.get(persona, _PERSONA_PROMPTS["gentle"])
    base += _INSTRUCTION_GUARD
    if memory_ctx:
        base += (
            "\n\n【你与用户的过往记忆（请自然融入对话，不要生硬提及）】\n" + memory_ctx
        )
    return base


@router.post("/chat/v2")
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
        # 违法内容前置过滤（用户输入）
        blocked, reason = content_moderation.moderate(message)
        if blocked:
            yield sse("blocked", {"reason": reason})
            yield sse("done", {})
            return

        # 生成式 AI 内容标识（暂行办法第九条）
        yield sse(
            "meta",
            {
                "ai_generated": True,
                "service": "竹笌",
                "notice": "本内容为人工智能生成",
            },
        )

        full_text = ""
        try:
            # 拉取长期记忆，注入对话上下文
            memory_ctx = _build_memory_context(user_id)
            sys_prompt = _compose_system_prompt(
                persona, system_prompt or "", memory_ctx
            )
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
                    msgs.append(
                        {
                            "role": h.get("role", "user"),
                            "content": h.get("content", ""),
                        }
                    )
                msgs.append({"role": "user", "content": message})
                async for tok in agnes_client.stream_agnes(
                    msgs, temperature, max_tokens
                ):
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

        # 情绪识别：基于用户输入识别，更准确驱动角色表情
        emo = emotion_engine.detect_emotion(message or full_text)
        yield sse("emotion", emo)

        # 持久化记忆：用户消息 + 竹笌回复（按 user_id 隔离）
        if message:
            memory_store.store("user", message, category="user_memory", user_id=user_id)
        if full_text:
            memory_store.store(
                "assistant",
                "竹笌：" + full_text,
                category="chat_memory",
                user_id=user_id,
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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Agnes 聊天客户端（agnes_client.py）
#
# 直连 Agnes /chat/completions（OpenAI 兼容，支持 SSE 流式）。
# 当没有 AGNES_API_KEY 时，调用方应使用 mock_stream 生成演示回复，
# 保证 App 在没有外部大模型的情况下也能完整跑通对话。
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import asyncio
import json
import re

import httpx

from config import settings

_PERSONA_INTRO = {
    "gentle": "（温柔地）",
    "playful": "（俏皮地）",
    "wise": "（沉稳地）",
}


async def stream_agnes(messages: list, temperature: float = 0.8,
                       max_tokens: int = 500):
    """异步流式产出文本片段。无 key 或请求失败会抛异常，由调用方兜底。"""
    if not settings.has_agnes:
        raise RuntimeError("AGNES_API_KEY 未配置")

    payload = {
        "model": settings.AGNES_MODEL,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
        "stream": True,
    }
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {settings.AGNES_API_KEY}",
    }
    async with httpx.AsyncClient(timeout=60) as client:
        async with client.stream(
            "POST", settings.agnes_base_url, json=payload, headers=headers
        ) as resp:
            if resp.status_code != 200:
                body = await resp.aread()
                raise RuntimeError(f"Agnes 错误 {resp.status_code}: {body[:200]}")
            buffer = ""
            async for chunk in resp.aiter_text():
                buffer += chunk
                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()
                    if not line.startswith("data:"):
                        continue
                    data = line[5:].strip()
                    if data == "[DONE]":
                        return
                    try:
                        obj = json.loads(data)
                        delta = obj["choices"][0]["delta"].get("content")
                        if delta:
                            yield delta
                    except Exception:
                        continue


def build_mock_reply(message: str, persona: str = "gentle") -> str:
    intro = _PERSONA_INTRO.get(persona, "")
    return (
        f"{intro}我听到你说了「{message}」，一直在认真听呢。"
        "能这样陪你聊聊天，对我来说是很珍贵的事。"
        "你愿意再多跟我说说吗？无论是开心还是烦恼，我都想听。"
    )


def _tokenize(text: str):
    # 按标点/词切分，模拟自然打字效果
    return re.findall(r"[^，。！？、\s]+[，。！？、]?|\s+", text) or [text]


async def mock_stream(message: str, persona: str = "gentle"):
    """演示模式：产出角色化的兜底回复，逐片段流式返回。"""
    reply = build_mock_reply(message, persona)
    for tok in _tokenize(reply):
        yield tok
        await asyncio.sleep(0.02)

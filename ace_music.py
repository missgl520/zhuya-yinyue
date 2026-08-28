# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ACE Music 真实音乐生成客户端（ace_music.py）
#
# 从旧 pet_api.py 恢复的真实契约：
#   POST https://api.acemusic.ai/v1/chat/completions
#   Authorization: Bearer {ACE_MUSIC_API_KEY}
#   Body: {"messages":[{"role":"user","content":...}],
#          "audio_config":{"vocal_language":..., "duration":...},
#          "stream": False}
#   Resp: choices[0].message.audio[0].audio_url.url  → 真实音频地址
#
# 安全：密钥仅读 settings.ACE_MUSIC_API_KEY（来自 .env），绝不写死。
# 降级：is_configured() 为 False 时，music.py 走 Mock 占位，保证流程可用。
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import httpx

import config

ACE_BASE_URL = config.settings.ACE_MUSIC_BASE_URL


def is_configured() -> bool:
    """是否已配置可用的 ACE Music 密钥。"""
    return config.settings.has_ace_music


def _build_payload(prompt: str, lyrics: str, duration: int, language: str) -> dict:
    content = f"<prompt>{prompt}</prompt>\n<lyrics>{lyrics}</lyrics>" if lyrics else (prompt or "")
    return {
        "messages": [{"role": "user", "content": content}],
        "audio_config": {"vocal_language": language, "duration": duration},
        "stream": False,
    }


def _extract_audio_url(data: dict) -> str | None:
    """从 ACE 响应中提取首个真实音频地址。"""
    try:
        msg = data["choices"][0]["message"]
    except (KeyError, IndexError, TypeError):
        return None
    audios = msg.get("audio") or []
    if not audios:
        return None
    return (audios[0].get("audio_url") or {}).get("url")


async def generate(prompt: str, lyrics: str, duration: int = 180, language: str = "zh") -> bytes:
    """调用 ACE Music 生成音乐，返回音频字节。

    未配置密钥时抛 RuntimeError；网络/解析失败抛 RuntimeError（由调用方降级 Mock）。
    """
    api_key = config.settings.ACE_MUSIC_API_KEY
    if not api_key:
        raise RuntimeError("ACE_MUSIC_API_KEY 未配置")

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    async with httpx.AsyncClient(timeout=300.0) as client:
        resp = await client.post(ACE_BASE_URL, headers=headers, json=_build_payload(prompt, lyrics, duration, language))
        if resp.status_code != 200:
            raise RuntimeError(f"ACE Music 生成失败: HTTP {resp.status_code} {resp.text[:200]}")
        try:
            data = resp.json()
        except Exception as e:
            raise RuntimeError(f"ACE Music 响应非 JSON: {e}") from e

        remote_url = _extract_audio_url(data)
        if not remote_url:
            raise RuntimeError("ACE Music 未返回音频地址")

        # 下载真实音频字节
        dl = await client.get(remote_url)
        if dl.status_code != 200:
            raise RuntimeError(f"ACE Music 音频下载失败: HTTP {dl.status_code}")
        return dl.content

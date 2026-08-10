# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LiveKit 令牌生成（livekit_token.py）
#
# 根据配置的 LIVEKIT_URL / API_KEY / API_SECRET 生成加入房间的
# 访问令牌（JWT）。未配置时返回 None，由接口层返回 available:false。
# 前端 livekit_service.dart 只读 livekit_url 与 token 两个字段。
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import time

import jwt

from config import settings


def generate_token(room: str, user_id: str = "", ttl: int = 3600):
    if not (settings.LIVEKIT_API_KEY and settings.LIVEKIT_API_SECRET
            and settings.LIVEKIT_URL):
        return None

    now = int(time.time())
    identity = user_id or f"user-{now}"
    grants = {
        "identity": identity,
        "name": identity,
        "video": {
            "room": room,
            "roomJoin": True,
            "canPublish": True,
            "canSubscribe": True,
        },
    }
    payload = {
        "iss": settings.LIVEKIT_API_KEY,
        "sub": settings.LIVEKIT_API_KEY,
        "nbf": now,
        "iat": now,
        "exp": now + ttl,
        "grants": grants,
    }
    token = jwt.encode(payload, settings.LIVEKIT_API_SECRET, algorithm="HS256")
    return token

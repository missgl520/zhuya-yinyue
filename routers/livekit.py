# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LiveKit 语音通话路由
# GET /livekit/connect   获取语音通话连接信息（room / token / url）
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

from fastapi import APIRouter

import livekit_token
from config import settings

router = APIRouter(prefix="/livekit", tags=["livekit"])


@router.get("/connect")
def livekit_connect(room: str = "zhuyapp-voice", user_id: str = ""):
    token = livekit_token.generate_token(room, user_id)
    if token is None:
        return {
            "available": False,
            "message": "LiveKit 未配置（请在 .env 设置 LIVEKIT_URL/API_KEY/API_SECRET）",
        }
    return {"available": True, "livekit_url": settings.LIVEKIT_URL, "token": token}

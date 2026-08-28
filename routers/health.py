# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 健康检查 & 服务信息路由
# GET  /         服务信息（含 persona / wake_word / agnes_enabled）
# GET  /health   健康检查
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

from fastapi import APIRouter

from app_state import load_state
from config import settings

router = APIRouter(tags=["health"])


@router.get("/")
def root():
    state = load_state()
    return {
        "service": "zhuyapp-backend",
        "status": "ok",
        "agnes_enabled": settings.has_agnes,
        "persona": state.get("persona", settings.PERSONA_DEFAULT),
        "wake_word": state.get("wake_word", settings.WAKE_WORD_DEFAULT),
    }


@router.get("/health")
def health():
    return {"status": "ok"}

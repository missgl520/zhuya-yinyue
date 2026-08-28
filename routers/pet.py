# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 音乐狗子路由
# GET  /pet/state     获取宠物当前状态
# POST /pet/interact  执行交互（feed/play/pet/talk/sleep）
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

import pet_state_store

router = APIRouter(prefix="/pet", tags=["pet"])

_VALID_ACTIONS = {"feed", "play", "pet", "talk", "sleep"}


@router.get("/state")
def pet_state(request: Request):
    user_id = getattr(request.state, "user_id", "default")
    return pet_state_store.load(user_id)


@router.post("/interact")
async def pet_interact(request: Request):
    user_id = getattr(request.state, "user_id", "default")
    body = await request.json()
    action = (body.get("action") or "").strip().lower()
    if action not in _VALID_ACTIONS:
        return JSONResponse(
            {"ok": False, "error": f"action 必须是 {sorted(_VALID_ACTIONS)} 之一"},
            status_code=400,
        )
    state = pet_state_store.interact(action, user_id)
    return {"ok": True, "state": state}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 好感度路由
# GET /affinity   获取当前用户好感度（level / exp / next_threshold / streak）
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

from fastapi import APIRouter, Request

import affinity_store

router = APIRouter(tags=["affinity"])


@router.get("/affinity")
def affinity(request: Request):
    user_id = getattr(request.state, "user_id", "default")
    return affinity_store.load(user_id)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 用户数据权利路由（PIPL：访问/可携带权 / 删除权）
# GET    /user/export   导出该用户全部个人数据
# DELETE /user/data     删除该用户全部个人数据
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import datetime

from fastapi import APIRouter, Request

import affinity_store
import memory_store

router = APIRouter(prefix="/user", tags=["user"])


@router.get("/export")
def user_export(request: Request):
    """导出该用户全部个人数据（访问 / 可携带权）。"""
    user_id = getattr(request.state, "user_id", "default")
    return {
        "user_id": user_id,
        "memories": memory_store.export_all(user_id),
        "affinity": affinity_store.load(user_id),
        "exported_at": datetime.datetime.now().isoformat(timespec="seconds"),
    }


@router.delete("/data")
def user_data_delete(request: Request):
    """删除该用户全部个人数据（删除权）。"""
    user_id = getattr(request.state, "user_id", "default")
    memory_store.clear_all(user_id)
    affinity_store.reset(user_id)
    return {"ok": True, "user_id": user_id}

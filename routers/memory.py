# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 记忆路由（长期记忆 CRUD）
# GET    /memory/today      今日记忆
# GET    /memory/search     搜索记忆（同时返回 memories + results + count）
# GET    /memory/summaries  每日摘要
# POST   /memory            存储一条记忆（兜底）
# PUT    /memory/{mem_id}   用户更正其个人记忆内容（PIPL 更正权）
# POST   /memory/clear      清空记忆
# DELETE /memory            清空某分类
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

import memory_store

router = APIRouter(prefix="/memory", tags=["memory"])


@router.get("/today")
def memory_today(request: Request):
    user_id = getattr(request.state, "user_id", "default")
    return {"memories": memory_store.get_today(user_id)}


@router.get("/search")
def memory_search(
    request: Request,
    q: str = "",
    mode: str = "keyword",
    category: str = "",
    limit: int = 20,
):
    user_id = getattr(request.state, "user_id", "default")
    mems = memory_store.search(q=q, category=category, limit=limit, user_id=user_id)
    results = [{"content": m["content"], "category": m["category"]} for m in mems]
    # 同时满足两个前端调用方：BackendService 读 memories，MemoryService 读 results+count
    return {"count": len(mems), "results": results, "memories": mems}


@router.get("/summaries")
def memory_summaries(request: Request):
    user_id = getattr(request.state, "user_id", "default")
    return {"summaries": memory_store.summaries(user_id)}


@router.post("")
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


@router.put("/{mem_id}")
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


@router.post("/clear")
def memory_clear(request: Request):
    user_id = getattr(request.state, "user_id", "default")
    memory_store.clear_all(user_id)
    return {"ok": True}


@router.delete("")
def memory_delete_category(request: Request, category: str = ""):
    user_id = getattr(request.state, "user_id", "default")
    if category:
        memory_store.clear_category(category, user_id)
    else:
        memory_store.clear_all(user_id)
    return {"ok": True}

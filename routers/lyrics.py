# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 歌词库路由（CRUD）
# GET    /lyrics          列表（分页）
# POST   /lyrics          创建
# GET    /lyrics/{id}     获取单条
# PUT    /lyrics/{id}     更新
# DELETE /lyrics/{id}     删除
# GET    /lyrics/search   搜索
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

import lyrics_store

router = APIRouter(prefix="/lyrics", tags=["lyrics"])


@router.get("")
def lyrics_list(request: Request, limit: int = 50, offset: int = 0):
    user_id = getattr(request.state, "user_id", "default")
    items = lyrics_store.list(user_id=user_id, limit=limit, offset=offset)
    return {"items": items, "count": len(items)}


@router.post("")
async def lyrics_create(request: Request):
    user_id = getattr(request.state, "user_id", "default")
    body = await request.json()
    title = (body.get("title") or "").strip()
    content = body.get("content", "")
    tags = body.get("tags", [])
    mood = body.get("mood", "")
    if not title:
        return JSONResponse({"ok": False, "error": "title 不能为空"}, status_code=400)
    if not content:
        return JSONResponse({"ok": False, "error": "content 不能为空"}, status_code=400)
    lid = lyrics_store.create(title=title, content=content, tags=tags, mood=mood, user_id=user_id)
    return {"ok": True, "id": lid}


@router.get("/search")
def lyrics_search(request: Request, q: str = "", mood: str = "", limit: int = 20):
    user_id = getattr(request.state, "user_id", "default")
    items = lyrics_store.search(q=q, mood=mood, user_id=user_id, limit=limit)
    return {"items": items, "count": len(items)}


@router.get("/{lyrics_id}")
def lyrics_get(lyrics_id: int, request: Request):
    user_id = getattr(request.state, "user_id", "default")
    item = lyrics_store.get(lyrics_id, user_id)
    if not item:
        return JSONResponse({"ok": False, "error": "未找到"}, status_code=404)
    return item


@router.put("/{lyrics_id}")
async def lyrics_update(lyrics_id: int, request: Request):
    user_id = getattr(request.state, "user_id", "default")
    body = await request.json()
    ok = lyrics_store.update(
        lyrics_id,
        title=body.get("title"),
        content=body.get("content"),
        tags=body.get("tags"),
        mood=body.get("mood"),
        user_id=user_id,
    )
    if not ok:
        return JSONResponse({"ok": False, "error": "未找到或无权修改"}, status_code=404)
    return {"ok": True}


@router.delete("/{lyrics_id}")
def lyrics_delete(lyrics_id: int, request: Request):
    user_id = getattr(request.state, "user_id", "default")
    ok = lyrics_store.delete(lyrics_id, user_id)
    if not ok:
        return JSONResponse({"ok": False, "error": "未找到"}, status_code=404)
    return {"ok": True}

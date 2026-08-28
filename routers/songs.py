# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 歌曲库路由
# GET    /songs              歌曲列表（分页，支持仅收藏）
# GET    /songs/{id}         获取单首歌曲
# POST   /songs/{id}/favorite  切换收藏状态
# POST   /songs/{id}/play       记录播放
# DELETE /songs/{id}         删除歌曲
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

import music_store

router = APIRouter(prefix="/songs", tags=["songs"])


@router.get("")
def songs_list(request: Request, limit: int = 50, offset: int = 0, favorite: bool = False):
    user_id = getattr(request.state, "user_id", "default")
    items = music_store.list_songs(user_id=user_id, limit=limit, offset=offset, only_favorite=favorite)
    return {"items": items, "count": len(items)}


@router.get("/{song_id}")
def songs_get(song_id: int, request: Request):
    user_id = getattr(request.state, "user_id", "default")
    song = music_store.get_song(song_id, user_id)
    if not song:
        return JSONResponse({"ok": False, "error": "歌曲不存在"}, status_code=404)
    return song


@router.post("/{song_id}/favorite")
def songs_favorite(song_id: int, request: Request):
    user_id = getattr(request.state, "user_id", "default")
    ok = music_store.toggle_favorite(song_id, user_id)
    if not ok:
        return JSONResponse({"ok": False, "error": "歌曲不存在"}, status_code=404)
    song = music_store.get_song(song_id, user_id)
    return {"ok": True, "is_favorite": song["is_favorite"]}


@router.post("/{song_id}/play")
def songs_play(song_id: int, request: Request):
    user_id = getattr(request.state, "user_id", "default")
    ok = music_store.increment_play(song_id, user_id)
    if not ok:
        return JSONResponse({"ok": False, "error": "歌曲不存在"}, status_code=404)
    return {"ok": True}


@router.delete("/{song_id}")
def songs_delete(song_id: int, request: Request):
    user_id = getattr(request.state, "user_id", "default")
    ok = music_store.delete_song(song_id, user_id)
    if not ok:
        return JSONResponse({"ok": False, "error": "歌曲不存在"}, status_code=404)
    return {"ok": True}

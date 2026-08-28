# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 音乐生成任务 & 歌曲库存储（music_store.py）
#
# 持久化到统一数据库的 music_jobs / songs 表（按 user_id 隔离）。
#
# music_jobs：异步音乐生成任务状态追踪
#   job_id / status / prompt / lyrics_id / style / audio_url / duration / error /
#   created_at / completed_at / user_id
#
# songs：已生成/收藏的歌曲库
#   id / title / audio_url / cover_url / duration / lyrics_id / style /
#   play_count / is_favorite / created_at / user_id
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import datetime
import json
import os
import uuid

from sqlalchemy import text

import db
from config import settings


def _now() -> str:
    return datetime.datetime.now().isoformat(timespec="seconds")


# ════════════════════════════════════════════════════════
# 音乐生成任务（music_jobs）
# ════════════════════════════════════════════════════════

def _job_row_to_dict(row) -> dict:
    return {
        "job_id": row.job_id,
        "status": row.status,
        "prompt": row.prompt,
        "lyrics_id": row.lyrics_id,
        "style": row.style,
        "audio_url": row.audio_url,
        "duration": row.duration,
        "error": row.error,
        "created_at": row.created_at,
        "completed_at": row.completed_at,
        "user_id": row.user_id,
    }


def create_job(prompt: str = "", lyrics_id: int = None, style: str = "", user_id: str = "default") -> str:
    job_id = uuid.uuid4().hex[:16]
    now = _now()
    with db.conn() as c:
        c.execute(
            text(
                "INSERT INTO music_jobs(job_id, status, prompt, lyrics_id, style, created_at, user_id) "
                "VALUES (:jid, 'pending', :prompt, :lid, :style, :created, :uid)"
            ),
            {
                "jid": job_id,
                "prompt": prompt,
                "lid": lyrics_id,
                "style": style,
                "created": now,
                "uid": user_id,
            },
        )
        c.commit()
    return job_id


def get_job(job_id: str, user_id: str = "default") -> dict | None:
    with db.conn() as c:
        row = c.execute(
            text("SELECT * FROM music_jobs WHERE job_id = :jid AND user_id = :uid"),
            {"jid": job_id, "uid": user_id},
        ).fetchone()
    return _job_row_to_dict(row) if row else None


def update_job_status(job_id: str, status: str, audio_url: str = None, duration: float = None, error: str = None, user_id: str = "default") -> bool:
    now = _now()
    completed = now if status in ("done", "failed") else None
    with db.conn() as c:
        c.execute(
            text(
                "UPDATE music_jobs SET status = :status, audio_url = :audio, duration = :dur, "
                "error = :err, completed_at = :completed WHERE job_id = :jid AND user_id = :uid"
            ),
            {
                "status": status,
                "audio": audio_url,
                "dur": duration,
                "err": error,
                "completed": completed,
                "jid": job_id,
                "uid": user_id,
            },
        )
        c.commit()
    return True


def list_jobs(user_id: str = "default", limit: int = 20) -> list:
    with db.conn() as c:
        rows = c.execute(
            text(
                "SELECT * FROM music_jobs WHERE user_id = :uid "
                "ORDER BY created_at DESC LIMIT :limit"
            ),
            {"uid": user_id, "limit": limit},
        ).fetchall()
    return [_job_row_to_dict(r) for r in rows]


# ════════════════════════════════════════════════════════
# 歌曲库（songs）
# ════════════════════════════════════════════════════════

def _song_row_to_dict(row) -> dict:
    return {
        "id": row.id,
        "title": row.title,
        "audio_url": row.audio_url,
        "cover_url": row.cover_url,
        "duration": row.duration,
        "lyrics_id": row.lyrics_id,
        "style": row.style,
        "play_count": row.play_count,
        "is_favorite": bool(row.is_favorite),
        "created_at": row.created_at,
        "user_id": row.user_id,
    }


def list_songs(user_id: str = "default", limit: int = 50, offset: int = 0, only_favorite: bool = False) -> list:
    query = "SELECT * FROM songs WHERE user_id = :uid"
    params = {"uid": user_id}
    if only_favorite:
        query += " AND is_favorite = 1"
    query += " ORDER BY created_at DESC LIMIT :limit OFFSET :offset"
    params["limit"] = limit
    params["offset"] = offset
    with db.conn() as c:
        rows = c.execute(text(query), params).fetchall()
    return [_song_row_to_dict(r) for r in rows]


def get_song(song_id: int, user_id: str = "default") -> dict | None:
    with db.conn() as c:
        row = c.execute(
            text("SELECT * FROM songs WHERE id = :id AND user_id = :uid"),
            {"id": song_id, "uid": user_id},
        ).fetchone()
    return _song_row_to_dict(row) if row else None


def add_song(title: str, audio_url: str, cover_url: str = "", duration: float = None,
             lyrics_id: int = None, style: str = "", user_id: str = "default") -> int:
    now = _now()
    with db.conn() as c:
        result = c.execute(
            text(
                "INSERT INTO songs(title, audio_url, cover_url, duration, lyrics_id, style, created_at, user_id) "
                "VALUES (:title, :audio, :cover, :dur, :lid, :style, :created, :uid)"
            ),
            {
                "title": title,
                "audio": audio_url,
                "cover": cover_url,
                "dur": duration,
                "lid": lyrics_id,
                "style": style,
                "created": now,
                "uid": user_id,
            },
        )
        c.commit()
        return result.lastrowid


def toggle_favorite(song_id: int, user_id: str = "default") -> bool:
    song = get_song(song_id, user_id)
    if not song:
        return False
    new_val = 0 if song["is_favorite"] else 1
    with db.conn() as c:
        c.execute(
            text("UPDATE songs SET is_favorite = :val WHERE id = :id AND user_id = :uid"),
            {"val": new_val, "id": song_id, "uid": user_id},
        )
        c.commit()
    return True


def increment_play(song_id: int, user_id: str = "default") -> bool:
    with db.conn() as c:
        c.execute(
            text("UPDATE songs SET play_count = play_count + 1 WHERE id = :id AND user_id = :uid"),
            {"id": song_id, "uid": user_id},
        )
        c.commit()
    return True


def delete_song(song_id: int, user_id: str = "default") -> bool:
    with db.conn() as c:
        result = c.execute(
            text("DELETE FROM songs WHERE id = :id AND user_id = :uid"),
            {"id": song_id, "uid": user_id},
        )
        c.commit()
        return result.rowcount > 0


# ════════════════════════════════════════════════════════
# 音频文件存储路径
# ════════════════════════════════════════════════════════

def audio_dir() -> str:
    """音频文件存储目录（确保存在）。"""
    d = os.path.join(settings.DATA_DIR, "audio")
    os.makedirs(d, exist_ok=True)
    return d


def audio_path(filename: str) -> str:
    return os.path.join(audio_dir(), filename)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 歌词库存储（lyrics_store.py）
#
# 持久化到统一数据库的 lyrics 表（按 user_id 隔离）。
# 支持 CRUD：list / get / create / update / delete / search
#
# 字段：id / title / content / tags(JSON) / mood / created_at / updated_at / user_id
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import datetime
import json

from sqlalchemy import text

import db


def _now() -> str:
    return datetime.datetime.now().isoformat(timespec="seconds")


def _row_to_dict(row) -> dict:
    return {
        "id": row.id,
        "title": row.title,
        "content": row.content,
        "tags": json.loads(row.tags) if row.tags else [],
        "mood": row.mood,
        "created_at": row.created_at,
        "updated_at": row.updated_at,
        "user_id": row.user_id,
    }


def list(user_id: str = "default", limit: int = 50, offset: int = 0) -> list:
    with db.conn() as c:
        rows = c.execute(
            text(
                "SELECT * FROM lyrics WHERE user_id = :uid "
                "ORDER BY updated_at DESC LIMIT :limit OFFSET :offset"
            ),
            {"uid": user_id, "limit": limit, "offset": offset},
        ).fetchall()
    return [_row_to_dict(r) for r in rows]


def get(lyrics_id: int, user_id: str = "default") -> dict | None:
    with db.conn() as c:
        row = c.execute(
            text("SELECT * FROM lyrics WHERE id = :id AND user_id = :uid"),
            {"id": lyrics_id, "uid": user_id},
        ).fetchone()
    return _row_to_dict(row) if row else None


def create(title: str, content: str, tags: list = None, mood: str = "", user_id: str = "default") -> int:
    now = _now()
    with db.conn() as c:
        result = c.execute(
            text(
                "INSERT INTO lyrics(title, content, tags, mood, created_at, updated_at, user_id) "
                "VALUES (:title, :content, :tags, :mood, :created, :updated, :uid)"
            ),
            {
                "title": title,
                "content": content,
                "tags": json.dumps(tags or [], ensure_ascii=False),
                "mood": mood,
                "created": now,
                "updated": now,
                "uid": user_id,
            },
        )
        c.commit()
        return result.lastrowid


def update(lyrics_id: int, title: str = None, content: str = None, tags: list = None, mood: str = None, user_id: str = "default") -> bool:
    existing = get(lyrics_id, user_id)
    if not existing:
        return False
    now = _now()
    with db.conn() as c:
        c.execute(
            text(
                "UPDATE lyrics SET title = :title, content = :content, tags = :tags, "
                "mood = :mood, updated_at = :updated WHERE id = :id AND user_id = :uid"
            ),
            {
                "title": title if title is not None else existing["title"],
                "content": content if content is not None else existing["content"],
                "tags": json.dumps(tags if tags is not None else existing["tags"], ensure_ascii=False),
                "mood": mood if mood is not None else existing["mood"],
                "updated": now,
                "id": lyrics_id,
                "uid": user_id,
            },
        )
        c.commit()
    return True


def delete(lyrics_id: int, user_id: str = "default") -> bool:
    with db.conn() as c:
        result = c.execute(
            text("DELETE FROM lyrics WHERE id = :id AND user_id = :uid"),
            {"id": lyrics_id, "uid": user_id},
        )
        c.commit()
        return result.rowcount > 0


def search(q: str = "", mood: str = "", user_id: str = "default", limit: int = 20) -> list:
    query = "SELECT * FROM lyrics WHERE user_id = :uid"
    params = {"uid": user_id}
    if q:
        query += " AND (title LIKE :q OR content LIKE :q)"
        params["q"] = f"%{q}%"
    if mood:
        query += " AND mood = :mood"
        params["mood"] = mood
    query += " ORDER BY updated_at DESC LIMIT :limit"
    params["limit"] = limit
    with db.conn() as c:
        rows = c.execute(text(query), params).fetchall()
    return [_row_to_dict(r) for r in rows]

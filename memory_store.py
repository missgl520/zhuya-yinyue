# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 记忆存储（memory_store.py）
#
# 后端长期记忆，通过统一数据库持久化（SQLite 或 MySQL）。
# 字段与前端 MemoryItem.fromJson 对齐：
#   id / content / category / tags(list) / created_at
#
# 多用户隔离（v1.1）：每条记忆归属一个 user_id，所有读写均按
# user_id 过滤，避免单例共享库混存不同用户数据（PIPL 合规）。
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import datetime
import json

from sqlalchemy import text

from config import settings
import db
import encryption


def init() -> None:
    # 建表 + 迁移统一由 db.init() 负责，这里仅确保数据库就绪
    db.init()


def store(role: str, content: str, category: str = "chat_memory",
          tags=None, importance: float = 0.5, user_id: str = "default") -> int:
    with db.conn() as conn:
        now = datetime.datetime.now().isoformat(timespec="seconds")
        result = conn.execute(
            text(
                "INSERT INTO memories(role, content, category, tags, importance, created_at, user_id) "
                "VALUES (:role, :content, :cat, :tags, :imp, :ts, :uid)"
            ),
            {
                "role": role,
                "content": encryption.encrypt(content),
                "cat": category,
                "tags": json.dumps(tags or [], ensure_ascii=False),
                "imp": importance,
                "ts": now,
                "uid": user_id,
            },
        )
        conn.commit()
        # SQLAlchemy ResultProxy: inserted_primary_key 是元组
        mid = result.lastrowid or result.inserted_primary_key[0]
    return mid


def get_today(user_id: str = "default") -> list:
    today = datetime.date.today().isoformat()
    with db.conn() as conn:
        rows = conn.execute(
            text(
                "SELECT id, content, category, tags, created_at FROM memories "
                "WHERE created_at LIKE :today AND user_id = :uid ORDER BY id ASC"
            ),
            {"today": today + "%", "uid": user_id},
        ).fetchall()
    return [_row_to_dict(r) for r in rows]


def search(q: str, limit: int = 20, user_id: str = "default") -> list:
    """加密后 SQL LIKE 无法命中密文，改为拉取该用户全部记忆、内存解密后按子串过滤。

    个人数据量小，全表扫描可接受；既保证静态加密，又不丢失搜索能力。
    """
    with db.conn() as conn:
        rows = conn.execute(
            text(
                "SELECT id, content, category, tags, created_at FROM memories "
                "WHERE user_id = :uid ORDER BY id DESC"
            ),
            {"uid": user_id},
        ).fetchall()
    q_lower = (q or "").lower()
    out = []
    for r in rows:
        d = _row_to_dict(r)
        if q_lower and q_lower not in d["content"].lower():
            continue
        out.append(d)
        if len(out) >= limit:
            break
    return out


def summaries(user_id: str = "default") -> list:
    with db.conn() as conn:
        rows = conn.execute(
            text("SELECT role, content, created_at FROM memories WHERE user_id = :uid ORDER BY id ASC"),
            {"uid": user_id},
        ).fetchall()
    by_day = {}
    for r in rows:
        day = (r.created_at or "")[:10]
        by_day.setdefault(day, [])
        by_day[day].append((r.role, r.content))
    out = []
    for day, items in sorted(by_day.items(), reverse=True):
        first_user = next((c for role, c in items if role == "user"), "")
        out.append({"date": day, "count": len(items), "content": first_user})
    return out


def clear_all(user_id: str = "default") -> None:
    with db.conn() as conn:
        conn.execute(
            text("DELETE FROM memories WHERE user_id = :uid"),
            {"uid": user_id},
        )
        conn.commit()


def clear_category(category: str, user_id: str = "default") -> None:
    with db.conn() as conn:
        conn.execute(
            text("DELETE FROM memories WHERE category = :cat AND user_id = :uid"),
            {"cat": category, "uid": user_id},
        )
        conn.commit()


def update_content(mem_id: int, content: str, user_id: str = "default") -> bool:
    """更正某条记忆内容（PIPL 更正权）。仅允许修改本人记录。"""
    with db.conn() as conn:
        cur = conn.execute(
            text("UPDATE memories SET content = :content WHERE id = :mid AND user_id = :uid"),
            {"content": encryption.encrypt(content), "mid": mem_id, "uid": user_id},
        )
        conn.commit()
        changed = cur.rowcount > 0
    return changed


def export_all(user_id: str = "default") -> list:
    """导出该用户全部记忆（访问 / 可携带权）。"""
    with db.conn() as conn:
        rows = conn.execute(
            text(
                "SELECT id, role, content, category, tags, created_at FROM memories "
                "WHERE user_id = :uid ORDER BY id ASC"
            ),
            {"uid": user_id},
        ).fetchall()
    return [_full_dict(r) for r in rows]


def _row_to_dict(r) -> dict:
    try:
        tags = json.loads(r.tags) if r.tags else []
    except Exception:
        tags = []
    return {
        "id": r.id,
        "content": encryption.decrypt(r.content),
        "category": r.category,
        "tags": tags,
        "created_at": r.created_at,
    }


def _full_dict(r) -> dict:
    try:
        tags = json.loads(r.tags) if r.tags else []
    except Exception:
        tags = []
    return {
        "id": r.id,
        "role": r.role,
        "content": encryption.decrypt(r.content),
        "category": r.category,
        "tags": tags,
        "created_at": r.created_at,
    }

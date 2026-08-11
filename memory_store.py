# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 记忆存储（memory_store.py）
#
# 后端长期记忆，SQLite 持久化到 data/zhuyu_memory.db。
# 字段与前端 MemoryItem.fromJson 对齐：
#   id / content / category / tags(list) / created_at
#
# 多用户隔离（v1.1）：每条记忆归属一个 user_id，所有读写均按
# user_id 过滤，避免单例共享库混存不同用户数据（PIPL 合规）。
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import datetime
import json
import os
import sqlite3

from config import settings
import db
import encryption

DB_PATH = db.DB_PATH  # 统一到 data/zhuyu.db（保留常量以兼容老引用）


def _conn() -> sqlite3.Connection:
    return db.conn()


def init() -> None:
    # 建表 + 迁移统一由 db.init() 负责，这里仅确保数据库就绪
    db.init()


def store(role: str, content: str, category: str = "chat_memory",
          tags=None, importance: float = 0.5, user_id: str = "default") -> int:
    conn = _conn()
    now = datetime.datetime.now().isoformat(timespec="seconds")
    cur = conn.execute(
        "INSERT INTO memories(role, content, category, tags, importance, created_at, user_id) "
        "VALUES (?,?,?,?,?,?,?)",
        (role, encryption.encrypt(content), category, json.dumps(tags or [], ensure_ascii=False), importance, now, user_id),
    )
    conn.commit()
    mid = cur.lastrowid
    conn.close()
    return mid


def get_today(user_id: str = "default") -> list:
    today = datetime.date.today().isoformat()
    conn = _conn()
    rows = conn.execute(
        "SELECT id, content, category, tags, created_at FROM memories "
        "WHERE created_at LIKE ? AND user_id = ? ORDER BY id ASC",
        (today + "%", user_id),
    ).fetchall()
    conn.close()
    return [_row_to_dict(r) for r in rows]


def search(q: str, limit: int = 20, user_id: str = "default") -> list:
    """加密后 SQL LIKE 无法命中密文，改为拉取该用户全部记忆、内存解密后按子串过滤。

    个人数据量小，全表扫描可接受；既保证静态加密，又不丢失搜索能力。
    """
    conn = _conn()
    rows = conn.execute(
        "SELECT id, content, category, tags, created_at FROM memories "
        "WHERE user_id = ? ORDER BY id DESC",
        (user_id,),
    ).fetchall()
    conn.close()
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
    conn = _conn()
    rows = conn.execute(
        "SELECT role, content, created_at FROM memories WHERE user_id = ? ORDER BY id ASC",
        (user_id,),
    ).fetchall()
    conn.close()
    by_day = {}
    for r in rows:
        day = (r["created_at"] or "")[:10]
        by_day.setdefault(day, [])
        by_day[day].append((r["role"], r["content"]))
    out = []
    for day, items in sorted(by_day.items(), reverse=True):
        first_user = next((c for role, c in items if role == "user"), "")
        out.append({"date": day, "count": len(items), "content": first_user})
    return out


def clear_all(user_id: str = "default") -> None:
    conn = _conn()
    conn.execute("DELETE FROM memories WHERE user_id = ?", (user_id,))
    conn.commit()
    conn.close()


def clear_category(category: str, user_id: str = "default") -> None:
    conn = _conn()
    conn.execute(
        "DELETE FROM memories WHERE category = ? AND user_id = ?", (category, user_id)
    )
    conn.commit()
    conn.close()


def update_content(mem_id: int, content: str, user_id: str = "default") -> bool:
    """更正某条记忆内容（PIPL 更正权）。仅允许修改本人记录。"""
    conn = _conn()
    cur = conn.execute(
        "UPDATE memories SET content = ? WHERE id = ? AND user_id = ?",
        (encryption.encrypt(content), mem_id, user_id),
    )
    conn.commit()
    changed = cur.rowcount > 0
    conn.close()
    return changed


def export_all(user_id: str = "default") -> list:
    """导出该用户全部记忆（访问 / 可携带权）。"""
    conn = _conn()
    rows = conn.execute(
        "SELECT id, role, content, category, tags, created_at FROM memories "
        "WHERE user_id = ? ORDER BY id ASC",
        (user_id,),
    ).fetchall()
    conn.close()
    return [_full_dict(r) for r in rows]


def _row_to_dict(r) -> dict:
    try:
        tags = json.loads(r["tags"]) if r["tags"] else []
    except Exception:
        tags = []
    return {
        "id": r["id"],
        "content": encryption.decrypt(r["content"]),
        "category": r["category"],
        "tags": tags,
        "created_at": r["created_at"],
    }


def _full_dict(r) -> dict:
    try:
        tags = json.loads(r["tags"]) if r["tags"] else []
    except Exception:
        tags = []
    return {
        "id": r["id"],
        "role": r["role"],
        "content": encryption.decrypt(r["content"]),
        "category": r["category"],
        "tags": tags,
        "created_at": r["created_at"],
    }

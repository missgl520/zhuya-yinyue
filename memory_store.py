# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 记忆存储（memory_store.py）
#
# 后端长期记忆，SQLite 持久化到 data/zhuyu_memory.db。
# 字段与前端 MemoryItem.fromJson 对齐：
#   id / content / category / tags(list) / created_at
#
# 渲染规则（见 memory_history_page.dart）：
#   - category == "user_memory"       → 显示为「你」
#   - category == "chat_memory"       → 内容以 "竹笌：" 开头时显示为「竹笌」
# 因此我们存用户消息用 user_memory，存竹笌回复用 chat_memory + "竹笌：" 前缀。
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import datetime
import json
import os
import sqlite3

from config import settings

DB_PATH = os.path.join(settings.DATA_DIR, "zhuyu_memory.db")


def _conn() -> sqlite3.Connection:
    os.makedirs(settings.DATA_DIR, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init() -> None:
    conn = _conn()
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS memories (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            role        TEXT NOT NULL,
            content     TEXT NOT NULL,
            category    TEXT NOT NULL DEFAULT 'chat_memory',
            tags        TEXT NOT NULL DEFAULT '[]',
            importance  REAL NOT NULL DEFAULT 0.5,
            created_at  TEXT NOT NULL
        )
        """
    )
    conn.commit()
    conn.close()


def store(role: str, content: str, category: str = "chat_memory",
          tags=None, importance: float = 0.5) -> int:
    conn = _conn()
    now = datetime.datetime.now().isoformat(timespec="seconds")
    cur = conn.execute(
        "INSERT INTO memories(role, content, category, tags, importance, created_at) "
        "VALUES (?,?,?,?,?,?)",
        (role, content, category, json.dumps(tags or [], ensure_ascii=False), importance, now),
    )
    conn.commit()
    mid = cur.lastrowid
    conn.close()
    return mid


def get_today() -> list:
    today = datetime.date.today().isoformat()
    conn = _conn()
    rows = conn.execute(
        "SELECT id, content, category, tags, created_at FROM memories "
        "WHERE created_at LIKE ? ORDER BY id ASC",
        (today + "%",),
    ).fetchall()
    conn.close()
    return [_row_to_dict(r) for r in rows]


def search(q: str, limit: int = 20) -> list:
    conn = _conn()
    rows = conn.execute(
        "SELECT id, content, category, tags, created_at FROM memories "
        "WHERE content LIKE ? ORDER BY id DESC LIMIT ?",
        (f"%{q}%", limit),
    ).fetchall()
    conn.close()
    return [_row_to_dict(r) for r in rows]


def summaries() -> list:
    conn = _conn()
    rows = conn.execute(
        "SELECT role, content, created_at FROM memories ORDER BY id ASC"
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


def clear_all() -> None:
    conn = _conn()
    conn.execute("DELETE FROM memories")
    conn.commit()
    conn.close()


def clear_category(category: str) -> None:
    conn = _conn()
    conn.execute("DELETE FROM memories WHERE category = ?", (category,))
    conn.commit()
    conn.close()


def _row_to_dict(r) -> dict:
    try:
        tags = json.loads(r["tags"]) if r["tags"] else []
    except Exception:
        tags = []
    return {
        "id": r["id"],
        "content": r["content"],
        "category": r["category"],
        "tags": tags,
        "created_at": r["created_at"],
    }

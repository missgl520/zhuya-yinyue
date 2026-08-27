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


def store(
    role: str,
    content: str,
    category: str = "chat_memory",
    tags=None,
    importance: float = 0.5,
    user_id: str = "default",
) -> int:
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


def _relevance(d: dict, q_lower: str, importance: float) -> float:
    """相关性打分：命中词数 + 重要性 + 时间新近。无查询词时返回非负（按时间）。"""
    if q_lower:
        cnt = d["content"].lower().count(q_lower)
        if cnt == 0:
            return -1.0  # 不匹配
        score = cnt * 1.0
    else:
        score = 0.0
    score += float(importance or 0.5) * 0.5
    day = (d.get("created_at") or "")[:10]
    today = datetime.date.today().isoformat()
    yesterday = (datetime.date.today() - datetime.timedelta(days=1)).isoformat()
    if day == today:
        score += 2.0
    elif day == yesterday:
        score += 1.0
    return score


def search(
    q: str = "", category: str = "", limit: int = 20, user_id: str = "default"
) -> list:
    """加密后 SQL LIKE 无法命中密文，改为拉取该用户全部记忆、内存解密后过滤。

    支持：category 可选过滤；q 子串匹配；结果按相关性（命中词数 + 重要性 +
    时间新近）降序排序。个人数据量小，全表扫描可接受。
    """
    with db.conn() as conn:
        rows = conn.execute(
            text(
                "SELECT id, content, category, tags, importance, created_at FROM memories "
                "WHERE user_id = :uid ORDER BY id DESC"
            ),
            {"uid": user_id},
        ).fetchall()
    q_lower = (q or "").lower()
    out = []
    for r in rows:
        d = _row_to_dict(r)
        if category and d.get("category") != category:
            continue
        rel = _relevance(d, q_lower, getattr(r, "importance", 0.5))
        if rel < 0:
            continue
        d["relevance"] = round(rel, 3)
        out.append(d)
    out.sort(key=lambda x: x["relevance"], reverse=True)
    for d in out:
        d.pop("relevance", None)
    return out[:limit]


def _rule_summary(user_msgs: list) -> str:
    """把当天用户消息聚合成一句摘要（规则版，无需外部模型）。"""
    if not user_msgs:
        return ""
    wake = settings.WAKE_WORD_DEFAULT
    cleaned = []
    for m in user_msgs:
        c = (m or "").strip()
        if wake and c.startswith(wake):
            c = c[len(wake) :].strip()
        if c:
            cleaned.append(c)
    if not cleaned:
        return ""
    text = "；".join(cleaned)
    if len(text) > 120:
        text = text[:120] + "…"
    return text


def summaries(user_id: str = "default") -> list:
    with db.conn() as conn:
        rows = conn.execute(
            text(
                "SELECT role, content, created_at FROM memories WHERE user_id = :uid ORDER BY id ASC"
            ),
            {"uid": user_id},
        ).fetchall()
    by_day = {}
    for r in rows:
        day = (r.created_at or "")[:10]
        by_day.setdefault(day, [])
        try:
            plain = encryption.decrypt(r.content)
        except Exception:
            plain = r.content or ""
        by_day[day].append((r.role, plain))
    out = []
    for day, items in sorted(by_day.items(), reverse=True):
        user_msgs = [c for role, c in items if role == "user"]
        summary = _rule_summary(user_msgs)
        out.append(
            {
                "date": day,
                "count": len(items),
                "user_count": len(user_msgs),
                "summary": summary,
                "first_user": user_msgs[0] if user_msgs else "",
                "content": summary,  # 兼容旧字段名
            }
        )
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
            text(
                "UPDATE memories SET content = :content WHERE id = :mid AND user_id = :uid"
            ),
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

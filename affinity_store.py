# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 好感度存储（affinity_store.py）
#
# 持久化到统一数据库 data/zhuyu.db 的 affinity 表（按 user_id 隔离）。
# 整行作为加密 JSON blob 存储，与记忆的字段加密策略保持一致
# （满足 PIPL 个人信息 at-rest 加密）。
#
# 字段与前端 Affinity.fromJson 对齐：
#   trust / intimacy / familiarity / total_interactions / streak_days
#
# 公开 API 与旧版（每用户 JSON 文件）完全一致：
#   load / save / bump_after_chat / reset
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import datetime
import json

import db
import encryption

_DEFAULT = {
    "trust": 30.0,
    "intimacy": 20.0,
    "familiarity": 5.0,
    "total_interactions": 0,
    "streak_days": 0,
    "last_active_date": "",
}


def _default() -> dict:
    return dict(_DEFAULT)


def load(user_id: str = "default") -> dict:
    c = db.conn()
    row = c.execute(
        "SELECT data FROM affinity WHERE user_id = ?", (user_id,)
    ).fetchone()
    c.close()
    if not row:
        return _default()
    try:
        return {**_default(), **json.loads(encryption.decrypt(row["data"]))}
    except Exception:
        return _default()


def save(data: dict, user_id: str = "default") -> None:
    c = db.conn()
    c.execute(
        "INSERT OR REPLACE INTO affinity(user_id, data) VALUES (?, ?)",
        (user_id, encryption.encrypt(json.dumps(data, ensure_ascii=False))),
    )
    c.commit()
    c.close()


def bump_after_chat(user_id: str = "default") -> dict:
    """每轮对话后更新好感度，返回最新值。"""
    d = load(user_id)
    today = datetime.date.today().isoformat()
    yesterday = (datetime.date.today() - datetime.timedelta(days=1)).isoformat()

    d["total_interactions"] = d["total_interactions"] + 1
    d["trust"] = min(100.0, d["trust"] + 0.5)
    d["intimacy"] = min(100.0, d["intimacy"] + 0.8)
    d["familiarity"] = min(100.0, d["familiarity"] + 0.3)

    last = d.get("last_active_date", "")
    if last == today:
        pass
    elif last == yesterday:
        d["streak_days"] = d["streak_days"] + 1
    else:
        d["streak_days"] = 1
    d["last_active_date"] = today

    save(d, user_id)
    return d


def reset(user_id: str = "default") -> None:
    """删除该用户的好感度数据（删除权）。"""
    c = db.conn()
    c.execute("DELETE FROM affinity WHERE user_id = ?", (user_id,))
    c.commit()
    c.close()

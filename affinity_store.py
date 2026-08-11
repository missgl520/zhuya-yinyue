# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 好感度存储（affinity_store.py）
#
# 持久化到 data/affinity/{user_id}.json。字段与前端 Affinity.fromJson 对齐：
#   trust / intimacy / familiarity / total_interactions / streak_days
#
# 多用户隔离（v1.1）：每个 user_id 一份独立文件，避免好感度混存。
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import datetime
import json
import os

from config import settings
import encryption

AFFINITY_DIR = os.path.join(settings.DATA_DIR, "affinity")


def _path(user_id: str) -> str:
    # 仅保留安全字符，避免路径穿越
    safe = "".join(c for c in (user_id or "default") if c.isalnum() or c in "-_") or "default"
    os.makedirs(AFFINITY_DIR, exist_ok=True)
    return os.path.join(AFFINITY_DIR, f"{safe}.json")


def _default() -> dict:
    return {
        "trust": 30.0,
        "intimacy": 20.0,
        "familiarity": 5.0,
        "total_interactions": 0,
        "streak_days": 0,
        "last_active_date": "",
    }


def load(user_id: str = "default") -> dict:
    try:
        with open(_path(user_id), encoding="utf-8") as f:
            raw = f.read()
        text = encryption.decrypt(raw)
        data = json.loads(text)
        base = _default()
        base.update(data)
        return base
    except FileNotFoundError:
        return _default()


def save(data: dict, user_id: str = "default") -> None:
    os.makedirs(AFFINITY_DIR, exist_ok=True)
    text = json.dumps(data, ensure_ascii=False, indent=2)
    token = encryption.encrypt(text)
    with open(_path(user_id), "w", encoding="utf-8") as f:
        f.write(token)


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
    try:
        os.remove(_path(user_id))
    except FileNotFoundError:
        pass

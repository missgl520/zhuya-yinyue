# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 好感度存储（affinity_store.py）
#
# 持久化到 data/affinity.json。字段与前端 Affinity.fromJson 对齐：
#   trust / intimacy / familiarity / total_interactions / streak_days
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import datetime
import json
import os

from config import settings

AFFINITY_FILE = os.path.join(settings.DATA_DIR, "affinity.json")


def _default() -> dict:
    return {
        "trust": 30.0,
        "intimacy": 20.0,
        "familiarity": 5.0,
        "total_interactions": 0,
        "streak_days": 0,
        "last_active_date": "",
    }


def load() -> dict:
    try:
        with open(AFFINITY_FILE, encoding="utf-8") as f:
            data = json.load(f)
        base = _default()
        base.update(data)
        return base
    except FileNotFoundError:
        return _default()


def save(data: dict) -> None:
    os.makedirs(settings.DATA_DIR, exist_ok=True)
    with open(AFFINITY_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def bump_after_chat() -> dict:
    """每轮对话后更新好感度，返回最新值。"""
    d = load()
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

    save(d)
    return d

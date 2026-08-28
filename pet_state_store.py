# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 音乐狗子状态存储（pet_state_store.py）
#
# 持久化到统一数据库的 pet_state 表（按 user_id 隔离）。
# 整行作为加密 JSON blob 存储，与好感度/记忆的加密策略一致。
#
# 状态字段：
#   mood        情绪（happy/sad/neutral/excited/tired/sleepy）
#   energy      能量 0-100
#   bond        羁绊/亲密度 0-100
#   hunger      饥饿 0-100（越高越饿）
#   happiness   快乐 0-100
#   level       等级
#   exp         经验值
#   inventory   物品库存（JSON dict）
#   total_interactions  总交互次数
#   last_interaction    最后交互时间 ISO
#   created_at  创建时间
#
# 公开 API：
#   load / save / interact / reset
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import datetime
import json
import random

from sqlalchemy import text

import db
import encryption

_DEFAULT = {
    "mood": "neutral",
    "energy": 80.0,
    "bond": 10.0,
    "hunger": 30.0,
    "happiness": 60.0,
    "level": 1,
    "exp": 0,
    "inventory": {},
    "total_interactions": 0,
    "last_interaction": "",
    "created_at": "",
}

# 升级所需经验（每级递增）
_EXP_PER_LEVEL = 100


def _default() -> dict:
    now = datetime.datetime.now().isoformat(timespec="seconds")
    d = dict(_DEFAULT)
    d["created_at"] = now
    return d


def load(user_id: str = "default") -> dict:
    with db.conn() as c:
        row = c.execute(
            text("SELECT data FROM pet_state WHERE user_id = :uid"),
            {"uid": user_id},
        ).fetchone()
    if not row:
        return _default()
    try:
        return {**_default(), **json.loads(encryption.decrypt(row.data))}
    except Exception:
        return _default()


def save(data: dict, user_id: str = "default") -> None:
    now = datetime.datetime.now().isoformat(timespec="seconds")
    with db.conn() as c:
        c.execute(
            text(
                "INSERT INTO pet_state(user_id, data, updated_at) VALUES (:uid, :d, :t) "
                "ON DUPLICATE KEY UPDATE data = :d, updated_at = :t"
            ),
            {
                "uid": user_id,
                "d": encryption.encrypt(json.dumps(data, ensure_ascii=False)),
                "t": now,
            },
        )
        c.commit()


def _clamp(v: float, lo: float = 0.0, hi: float = 100.0) -> float:
    return max(lo, min(hi, v))


def _update_mood(data: dict) -> str:
    """根据能量/饥饿/快乐综合计算情绪。"""
    energy = data["energy"]
    hunger = data["hunger"]
    happiness = data["happiness"]

    if energy < 20:
        return "sleepy"
    if hunger > 80:
        return "sad"
    if happiness > 75 and energy > 50:
        return "excited"
    if happiness > 50:
        return "happy"
    if happiness < 30:
        return "sad"
    return "neutral"


def interact(action: str, user_id: str = "default") -> dict:
    """执行一次交互，返回更新后的状态。

    支持的 action：
      feed    喂食 —— 降低饥饿，增加快乐，少量羁绊
      play    玩耍 —— 降低能量，增加快乐和羁绊，增加经验
      pet     抚摸 —— 少量快乐和羁绊
      talk    对话 —— 少量羁绊和经验
      sleep   睡觉 —— 恢复能量
    """
    data = load(user_id)
    now = datetime.datetime.now().isoformat(timespec="seconds")

    data["total_interactions"] = data.get("total_interactions", 0) + 1
    data["last_interaction"] = now

    if action == "feed":
        data["hunger"] = _clamp(data["hunger"] - 25)
        data["happiness"] = _clamp(data["happiness"] + 10)
        data["bond"] = _clamp(data["bond"] + 2)
        data["exp"] = data.get("exp", 0) + 5
    elif action == "play":
        data["energy"] = _clamp(data["energy"] - 15)
        data["happiness"] = _clamp(data["happiness"] + 15)
        data["bond"] = _clamp(data["bond"] + 5)
        data["exp"] = data.get("exp", 0) + 10
    elif action == "pet":
        data["happiness"] = _clamp(data["happiness"] + 5)
        data["bond"] = _clamp(data["bond"] + 3)
        data["exp"] = data.get("exp", 0) + 2
    elif action == "talk":
        data["bond"] = _clamp(data["bond"] + 2)
        data["exp"] = data.get("exp", 0) + 3
        data["happiness"] = _clamp(data["happiness"] + 3)
    elif action == "sleep":
        data["energy"] = _clamp(data["energy"] + 40)
        data["happiness"] = _clamp(data["happiness"] + 5)
    else:
        # 未知动作：无效果
        pass

    # 升级判定
    while data["exp"] >= data["level"] * _EXP_PER_LEVEL:
        data["exp"] -= data["level"] * _EXP_PER_LEVEL
        data["level"] = data.get("level", 1) + 1
        data["happiness"] = _clamp(data["happiness"] + 20)
        data["bond"] = _clamp(data["bond"] + 5)

    # 重新计算情绪
    data["mood"] = _update_mood(data)

    save(data, user_id)
    return data


def reset(user_id: str = "default") -> None:
    """删除该用户的宠物状态数据（删除权）。"""
    with db.conn() as c:
        c.execute(
            text("DELETE FROM pet_state WHERE user_id = :uid"),
            {"uid": user_id},
        )
        c.commit()

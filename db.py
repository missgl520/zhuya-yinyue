# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 统一持久化入口（db.py）
#
# 竹笌后端唯一的 SQLite 入口。把「记忆 / 好感度 / 运行时状态」
# 全部收敛到一个数据库文件 data/zhuyu.db，彻底告别散落的 JSON 文件。
#
# 表设计：
#   memories  —— 长期记忆（content 字段经字段加密，与前端对齐）
#   affinity  —— 好感度（整行作为加密 JSON blob，按 user_id 隔离）
#   kv        —— 运行时键值状态（persona / wake_word 等，值经字段加密）
#
# 多用户隔离：memories / affinity 均按 user_id 过滤，避免混存（PIPL 合规）。
# 迁移：首次启动时把遗留的 state.json / affinity.json 导入数据库（幂等）。
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import json
import os
import sqlite3

from config import settings
import encryption

DB_PATH = os.path.join(settings.DATA_DIR, "zhuyu.db")

_AFFINITY_DEFAULT = {
    "trust": 30.0,
    "intimacy": 20.0,
    "familiarity": 5.0,
    "total_interactions": 0,
    "streak_days": 0,
    "last_active_date": "",
}


def conn() -> sqlite3.Connection:
    os.makedirs(settings.DATA_DIR, exist_ok=True)
    c = sqlite3.connect(DB_PATH)
    c.row_factory = sqlite3.Row
    return c


def init() -> None:
    """建表（幂等）+ 迁移遗留 JSON。后端启动时调用一次。"""
    c = conn()

    # ── 记忆表（与前端 MemoryItem.fromJson 对齐）──
    c.execute(
        """
        CREATE TABLE IF NOT EXISTS memories (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            role        TEXT NOT NULL,
            content     TEXT NOT NULL,
            category    TEXT NOT NULL DEFAULT 'chat_memory',
            tags        TEXT NOT NULL DEFAULT '[]',
            importance  REAL NOT NULL DEFAULT 0.5,
            created_at  TEXT NOT NULL,
            user_id     TEXT NOT NULL DEFAULT 'default'
        )
        """
    )
    cols = [r["name"] for r in c.execute("PRAGMA table_info(memories)").fetchall()]
    if "user_id" not in cols:
        c.execute(
            "ALTER TABLE memories ADD COLUMN user_id TEXT NOT NULL DEFAULT 'default'"
        )

    # ── 好感度表（整行加密 JSON，按 user_id 隔离）──
    c.execute(
        """
        CREATE TABLE IF NOT EXISTS affinity (
            user_id TEXT PRIMARY KEY,
            data    TEXT NOT NULL
        )
        """
    )

    # ── 运行时键值状态（值加密）──
    c.execute(
        """
        CREATE TABLE IF NOT EXISTS kv (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
        """
    )

    c.commit()
    c.close()

    migrate_legacy()


def migrate_legacy() -> None:
    """把迁移前的 JSON 文件导入数据库（仅当库中无对应数据时，幂等）。"""
    data_dir = settings.DATA_DIR

    # ── 旧 state.json（persona / wake_word，明文）──
    state_path = os.path.join(data_dir, "state.json")
    if os.path.exists(state_path):
        try:
            with open(state_path, encoding="utf-8") as f:
                s = json.load(f)
            c = conn()
            if c.execute("SELECT COUNT(*) AS n FROM kv").fetchone()["n"] == 0:
                for k in ("persona", "wake_word"):
                    if k in s:
                        c.execute(
                            "INSERT OR IGNORE INTO kv(key, value) VALUES (?, ?)",
                            (k, encryption.encrypt(str(s[k]))),
                        )
                c.commit()
            c.close()
            os.rename(state_path, state_path + ".migrated")
        except Exception:
            pass

    # ── 旧好感度：data/affinity.json（单文件）或 data/affinity/*.json（每用户）──
    affinity_candidates = []
    single = os.path.join(data_dir, "affinity.json")
    if os.path.exists(single):
        affinity_candidates.append(("default", single))
    aff_dir = os.path.join(data_dir, "affinity")
    if os.path.isdir(aff_dir):
        for fn in os.listdir(aff_dir):
            if fn.endswith(".json"):
                affinity_candidates.append((fn[:-5], os.path.join(aff_dir, fn)))

    if affinity_candidates:
        c = conn()
        for uid, path in affinity_candidates:
            try:
                with open(path, encoding="utf-8") as f:
                    raw = f.read()
                d = json.loads(encryption.decrypt(raw))
            except Exception:
                continue
            if not isinstance(d, dict):
                continue
            records = {}
            if "trust" in d:
                records[uid] = d
            else:
                for k, v in d.items():
                    if isinstance(v, dict) and "trust" in v:
                        records[k] = v
            for r_uid, rec in records.items():
                if c.execute(
                    "SELECT 1 FROM affinity WHERE user_id = ?", (r_uid,)
                ).fetchone():
                    continue
                merged = {**_AFFINITY_DEFAULT, **rec}
                c.execute(
                    "INSERT OR IGNORE INTO affinity(user_id, data) VALUES (?, ?)",
                    (r_uid, encryption.encrypt(json.dumps(merged, ensure_ascii=False))),
                )
        c.commit()
        c.close()
        try:
            if os.path.exists(single):
                os.rename(single, single + ".migrated")
            if os.path.isdir(aff_dir):
                os.rename(aff_dir, aff_dir + ".migrated")
        except Exception:
            pass

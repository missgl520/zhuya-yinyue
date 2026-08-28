# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 应用运行时状态（persona / wake_word）
#
# 持久化到数据库 kv 表（值加密），供 health/config/chat 等 router 共享。
# 从 main.py 拆分而来（原 load_state / save_state）。
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import encryption
import db
from config import settings
from sqlalchemy import text


def load_state() -> dict:
    """从 kv 表加载 persona / wake_word，不存在时用默认值。"""
    with db.conn() as c:
        rows = c.execute(
            text("SELECT `key`, value FROM kv WHERE `key` IN ('persona', 'wake_word')")
        ).fetchall()
    stored = {r.key: encryption.decrypt(r.value) for r in rows}
    return {
        "persona": stored.get("persona", settings.PERSONA_DEFAULT),
        "wake_word": stored.get("wake_word", settings.WAKE_WORD_DEFAULT),
    }


def save_state(state: dict) -> None:
    """保存 persona / wake_word 到 kv 表（加密存储，MySQL/SQLite 双兼容）。"""
    with db.conn() as c:
        is_mysql = c.dialect.name == "mysql"
        for k in ("persona", "wake_word"):
            if k not in state:
                continue
            if is_mysql:
                c.execute(
                    text(
                        "INSERT INTO kv(`key`, value) VALUES (:k, :v) "
                        "ON DUPLICATE KEY UPDATE value = :v"
                    ),
                    {"k": k, "v": encryption.encrypt(str(state[k]))},
                )
            else:
                c.execute(
                    text("INSERT OR REPLACE INTO kv(`key`, value) VALUES (:k, :v)"),
                    {"k": k, "v": encryption.encrypt(str(state[k]))},
                )
        c.commit()

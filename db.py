# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 统一持久化入口（db.py）
#
# 竹笌后端唯一的数据库入口。通过 SQLAlchemy Core 统一接口，
# 同时支持 SQLite（本地开发）和 MySQL（生产/SQLPub 云库）。
#
# 表设计：
#   memories  —— 长期记忆（content 字段经字段加密，与前端对齐）
#   affinity  —— 好感度（整行作为加密 JSON blob，按 user_id 隔离）
#   kv        —— 运行时键值状态（persona / wake_word 等，值经字段加密）
#
# 多用户隔离：memories / affinity 均按 user_id 过滤。
# 切换数据库只需改 config.py 的 DATABASE_URL，零代码改动。
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import json
import os
from typing import Optional

from sqlalchemy import (
    Column,
    Integer,
    String,
    Text,
    Float,
    MetaData,
    Table,
    create_engine,
    inspect,
    text,
)
from sqlalchemy.engine import Engine, Connection

from config import settings
import encryption

_metadata = MetaData()
_engine: Optional[Engine] = None


def _is_mysql_url(url: str) -> bool:
    return url.startswith("mysql")


def _mysql_connect_args() -> dict:
    """MySQL 连接参数：SQLPub / 多数云库要求 SSL，且自签证书需关闭校验。

    仅对 MySQL 生效；SQLite 不需要也不接受这些参数。
    """
    return {
        "ssl": {
            "ssl_verify_cert": False,
            "ssl_verify_identity": False,
        }
    }


# ── 表定义（ORM-style 声明，用于建表 / 检查列）──
memories_t = Table(
    "memories",
    _metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("role", String(32), nullable=False),
    Column("content", Text, nullable=False),
    Column("category", String(64), nullable=False, server_default="chat_memory"),
    Column(
        "tags", Text, nullable=True
    ),  # TiDB/严格MySQL: TEXT列不可设default，由应用层兜底"[]"
    Column("importance", Float, nullable=False, server_default="0.5"),
    Column("created_at", String(32), nullable=False),
    Column("user_id", String(128), nullable=False, server_default="default"),
)

affinity_t = Table(
    "affinity",
    _metadata,
    Column("user_id", String(128), primary_key=True),
    Column("data", Text, nullable=False),
)

kv_t = Table(
    "kv",
    _metadata,
    Column("key", String(128), primary_key=True),
    Column("value", Text, nullable=False),
)

# ── Phase 1 新增表：音乐狗子 × 音乐创作 ──

# 音乐狗子状态（每用户一条，JSON blob 存完整状态）
pet_state_t = Table(
    "pet_state",
    _metadata,
    Column("user_id", String(128), primary_key=True),
    Column("data", Text, nullable=False),  # 加密 JSON：mood/energy/bond/inventory/last_interaction
    Column("updated_at", String(32), nullable=False),
)

# 歌词库（用户创作的歌词，可被音乐生成引用）
lyrics_t = Table(
    "lyrics",
    _metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("title", String(256), nullable=False),
    Column("content", Text, nullable=False),  # 完整歌词文本
    Column("tags", Text, nullable=True),       # JSON 数组字符串
    Column("mood", String(64), nullable=True), # 情绪标签
    Column("created_at", String(32), nullable=False),
    Column("updated_at", String(32), nullable=False),
    Column("user_id", String(128), nullable=False, server_default="default"),
)

# 音乐生成任务（异步任务状态追踪）
music_jobs_t = Table(
    "music_jobs",
    _metadata,
    Column("job_id", String(64), primary_key=True),
    Column("status", String(32), nullable=False, server_default="pending"),  # pending/running/done/failed
    Column("prompt", Text, nullable=True),
    Column("lyrics_id", Integer, nullable=True),
    Column("style", String(128), nullable=True),
    Column("audio_url", String(512), nullable=True),
    Column("duration", Float, nullable=True),
    Column("error", Text, nullable=True),
    Column("created_at", String(32), nullable=False),
    Column("completed_at", String(32), nullable=True),
    Column("user_id", String(128), nullable=False, server_default="default"),
)

# 歌曲库（已生成/收藏的歌曲）
songs_t = Table(
    "songs",
    _metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("title", String(256), nullable=False),
    Column("audio_url", String(512), nullable=False),
    Column("cover_url", String(512), nullable=True),
    Column("duration", Float, nullable=True),
    Column("lyrics_id", Integer, nullable=True),
    Column("style", String(128), nullable=True),
    Column("play_count", Integer, nullable=False, server_default="0"),
    Column("is_favorite", Integer, nullable=False, server_default="0"),  # 0/1 布尔
    Column("created_at", String(32), nullable=False),
    Column("user_id", String(128), nullable=False, server_default="default"),
)


def _is_mysql(conn: Connection) -> bool:
    return conn.dialect.name == "mysql"


def get_engine() -> Engine:
    """延迟初始化引擎（首次调用时创建）。"""
    global _engine
    if _engine is None:
        url = settings.DATABASE_URL
        kwargs: dict = {
            "pool_pre_ping": True,  # 自动检测断连并重连
            "pool_recycle": 3600,  # MySQL 默认 8h 超时，提前回收
            "echo": False,
        }
        # MySQL 需要 SSL（SQLPub / 云库），且自签证书需关闭主机名/证书校验
        if _is_mysql_url(url):
            kwargs["connect_args"] = _mysql_connect_args()
        _engine = create_engine(url, **kwargs)
    return _engine


def conn() -> Connection:
    """获取一个数据库连接（从连接池）。

    用法与旧版 sqlite3.Connection 兼容：
      c = db.conn()
      c.execute(text("..."), {"param": value})
      c.commit()
      c.close()
    """
    return get_engine().connect()


def init() -> None:
    """建表（幂等）+ 迁移遗留 JSON。后端启动时调用一次。"""
    # 确保数据目录存在：SQLite 不会自动创建父目录，
    # 云托管镜像里 data/ 被 .dockerignore 排除，启动前必须自建，否则 create_all 直接崩。
    os.makedirs(settings.DATA_DIR, exist_ok=True)
    engine = get_engine()
    _metadata.create_all(engine, checkfirst=True)

    # 兼容旧库：补充 user_id 列（早期 SQLite 可能缺失）
    with engine.connect() as c:
        insp = inspect(engine)
        mem_cols = [col["name"] for col in insp.get_columns("memories")]
        if "user_id" not in mem_cols:
            if _is_mysql(c):
                c.execute(
                    text(
                        "ALTER TABLE memories ADD COLUMN user_id VARCHAR(128) NOT NULL DEFAULT 'default'"
                    )
                )
            else:
                c.execute(
                    text(
                        "ALTER TABLE memories ADD COLUMN user_id TEXT NOT NULL DEFAULT 'default'"
                    )
                )
            c.commit()

    migrate_legacy()


_AFFINITY_DEFAULT = {
    "trust": 30.0,
    "intimacy": 20.0,
    "familiarity": 5.0,
    "total_interactions": 0,
    "streak_days": 0,
    "last_active_date": "",
}


def migrate_legacy() -> None:
    """把迁移前的 JSON 文件导入数据库（仅当库中无对应数据时，幂等）。

    仅对 SQLite 本地文件有意义；MySQL 环境下 data/ 目录通常不存在，
    安全跳过即可。
    """
    data_dir = settings.DATA_DIR
    if not os.path.isdir(data_dir):
        return

    # ── 旧 state.json（persona / wake_word，明文）──
    state_path = os.path.join(data_dir, "state.json")
    if os.path.exists(state_path):
        try:
            with open(state_path, encoding="utf-8") as f:
                s = json.load(f)
            with conn() as c:
                row = c.execute(text("SELECT COUNT(*) AS n FROM kv")).one()
                if row.n == 0:
                    for k in ("persona", "wake_word"):
                        if k in s:
                            c.execute(
                                text(
                                    "INSERT IGNORE INTO kv(`key`, value) VALUES (:k, :v)"
                                ),
                                {"k": k, "v": encryption.encrypt(str(s[k]))},
                            )
                    c.commit()
            os.rename(state_path, state_path + ".migrated")
        except Exception:
            pass

    # ── 旧好感度 JSON 文件 ──
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
        with conn() as c:
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
                    existing = c.execute(
                        text("SELECT 1 FROM affinity WHERE user_id = :uid"),
                        {"uid": r_uid},
                    ).fetchone()
                    if existing:
                        continue
                    merged = {**_AFFINITY_DEFAULT, **rec}
                    c.execute(
                        text("INSERT INTO affinity(user_id, data) VALUES (:uid, :d)"),
                        {
                            "uid": r_uid,
                            "d": encryption.encrypt(
                                json.dumps(merged, ensure_ascii=False)
                            ),
                        },
                    )
            c.commit()
        try:
            if os.path.exists(single):
                os.rename(single, single + ".migrated")
            if os.path.isdir(aff_dir):
                os.rename(aff_dir, aff_dir + ".migrated")
        except Exception:
            pass

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 静态加密（encryption.py）
#
# 对落盘的个人数据（记忆 content、好感度 JSON）做对称加密，
# 满足 PIPL「个人信息存储加密」要求（at-rest encryption）。
#
# 密钥优先级：
#   1. 环境变量 ZHUYU_ENC_KEY（base64 的 32 字节 Fernet key）——生产推荐
#   2. 本地持久化密钥文件 data/.enc_key（gitignore，首次运行自动生成）
#
# 设计取舍：采用应用层字段加密（而非 sqlcipher 整库替换），
# 好处是不引入新的 SQLite 驱动依赖；代价是 SQL LIKE 全文检索失效，
# 故 memory_store 的搜索改为「内存解密后过滤」（个人数据量小，可接受）。
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import base64
import os

from cryptography.fernet import Fernet, InvalidToken

from config import settings

KEY_FILE = os.path.join(settings.DATA_DIR, ".enc_key")
_KEY = None  # 延迟加载，避免模块导入期就触发文件写入


def _load_key() -> bytes:
    # 1) 环境变量优先（生产部署把密钥放在环境变量 / Secrets 里）
    env_key = os.getenv("ZHUYU_ENC_KEY")
    if env_key:
        try:
            return base64.urlsafe_b64decode(env_key)
        except Exception:
            # 格式错误则回退到本地密钥文件
            pass

    # 2) 本地持久化密钥文件（gitignore，首次运行自动生成）
    os.makedirs(settings.DATA_DIR, exist_ok=True)
    if os.path.exists(KEY_FILE):
        with open(KEY_FILE, "rb") as f:
            return f.read()

    # 3) 首次运行：生成并落盘（仅本机可读）
    key = Fernet.generate_key()
    with open(KEY_FILE, "wb") as f:
        f.write(key)
    try:
        os.chmod(KEY_FILE, 0o600)
    except Exception:
        # Windows 上 chmod 无效果，忽略
        pass
    return key


def _fernet() -> Fernet:
    global _KEY
    if _KEY is None:
        _KEY = _load_key()
    return Fernet(_KEY)


def encrypt(plaintext: str) -> str:
    """加密 UTF-8 字符串，返回 base64 token 字符串。空值直接返回空串。"""
    if not plaintext:
        return ""
    token = _fernet().encrypt(plaintext.encode("utf-8"))
    return token.decode("ascii")


def decrypt(token: str) -> str:
    """解密 token 回明文。

    - 空 token 返回空串；
    - 解密失败（token 损坏，或命中迁移期的未加密旧数据）直接原样返回，
      保证老库 / 损坏行不会导致服务崩溃。
    """
    if not token:
        return ""
    try:
        return _fernet().decrypt(token.encode("ascii")).decode("utf-8")
    except (InvalidToken, Exception):
        return token

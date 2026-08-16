# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 竹笌后端配置（config.py）
#
# 从 .env 读取运行配置；不依赖外部文件时给出安全默认值。
# 本后端与前端 F:\zhuyapp 的接口契约完全对齐。
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import os

from dotenv import load_dotenv

load_dotenv()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))


class Settings:
    # ── Agnes 聊天大模型（OpenAI 兼容 /chat/completions）──
    # 不填 AGNES_API_KEY 时后端进入「mock 演示模式」，App 仍可完整跑通
    AGNES_API_KEY: str = os.getenv("AGNES_API_KEY", "")
    AGNES_USE_CN: bool = os.getenv("AGNES_USE_CN", "true").lower() in ("1", "true", "yes")
    AGNES_MODEL: str = os.getenv("AGNES_MODEL", "agnes-2.0-flash")
    # 自定义 base_url（可选）：覆盖下方默认域名，支持用户自有 agnes 网关
    AGNES_BASE_URL: str = os.getenv("AGNES_BASE_URL", "")

    # ── 服务监听 ──
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))

    # ── 持久化目录 ──
    DATA_DIR: str = os.getenv("DATA_DIR", os.path.join(BASE_DIR, "data"))

    # ── 数据库连接（SQLAlchemy URL）──
    # 默认使用本地 SQLite（开发）；设为 MySQL URL 即切换到远程云库。
    # MySQL 示例：mysql+pymysql://user:pass@host:port/dbname
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        f"sqlite:///{os.path.join(BASE_DIR, 'data', 'zhuyu.db')}",
    )

    # ── 默认角色 / 唤醒词 ──
    PERSONA_DEFAULT: str = os.getenv("PERSONA_DEFAULT", "gentle")
    WAKE_WORD_DEFAULT: str = os.getenv("WAKE_WORD_DEFAULT", "竹笌竹笌")

    # ── LiveKit（语音通话，可选）──
    LIVEKIT_URL: str = os.getenv("LIVEKIT_URL", "")
    LIVEKIT_API_KEY: str = os.getenv("LIVEKIT_API_KEY", "")
    LIVEKIT_API_SECRET: str = os.getenv("LIVEKIT_API_SECRET", "")

    # ── 接口签名鉴权（API Key + 请求签名）──
    # 留空（""）则进入「开发模式」：不强制签名，便于本地联调。
    # 生产环境【必须】设置强随机值，并在前端同步配置相同 API Key。
    API_KEY: str = os.getenv("ZHUYU_API_KEY", "zhuyu-dev-key-change-me")
    # 签名时间容差（秒）——用于防重放，建议生产保持 300 以内
    SIGNATURE_TOLERANCE_SECONDS: int = int(os.getenv("SIGNATURE_TOLERANCE_SECONDS", "300"))
    # CORS 允许的源（逗号分隔）。留空则使用内置本地方略（不使用通配符 "*"）。
    ALLOWED_ORIGINS: list = [
        o.strip() for o in os.getenv("ALLOWED_ORIGINS", "").split(",") if o.strip()
    ]

    # ── 运营主体与联系信息（用于隐私政策 / 用户协议占位替换）──
    # 上线前【必须】替换为真实信息：在 .env 设置以下变量即可，无需改动 legal/ 文档模板。
    # 默认值保留占位提示，未配置时前端展示仍为「请填写…」，便于上线前自检。
    OPERATOR_NAME: str = os.getenv("OPERATOR_NAME", "【请填写运营主体名称】")
    PRIVACY_CONTACT_EMAIL: str = os.getenv(
        "PRIVACY_CONTACT_EMAIL", "【请填写隐私联系邮箱】"
    )
    SERVICE_CONTACT_EMAIL: str = os.getenv(
        "SERVICE_CONTACT_EMAIL", "【请填写服务联系邮箱】"
    )

    @property
    def agnes_base_url(self) -> str:
        # 显式指定 base_url 时优先（支持用户自有域名，如 api.agnes-ai.cn）
        if self.AGNES_BASE_URL:
            base = self.AGNES_BASE_URL.rstrip("/")
            if base.endswith("/chat/completions"):
                return base
            return base + "/chat/completions"
        # 默认：国内版 / 国际版
        return (
            "https://apihub.agnes-ai.cn/v1/chat/completions"
            if self.AGNES_USE_CN
            else "https://apihub.agnes-ai.com/v1/chat/completions"
        )

    @property
    def has_agnes(self) -> bool:
        return bool(self.AGNES_API_KEY)


settings = Settings()

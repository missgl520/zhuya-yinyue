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

    # ── 服务监听 ──
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))

    # ── 持久化目录 ──
    DATA_DIR: str = os.getenv("DATA_DIR", os.path.join(BASE_DIR, "data"))

    # ── 默认角色 / 唤醒词 ──
    PERSONA_DEFAULT: str = os.getenv("PERSONA_DEFAULT", "gentle")
    WAKE_WORD_DEFAULT: str = os.getenv("WAKE_WORD_DEFAULT", "竹笌竹笌")

    # ── LiveKit（语音通话，可选）──
    LIVEKIT_URL: str = os.getenv("LIVEKIT_URL", "")
    LIVEKIT_API_KEY: str = os.getenv("LIVEKIT_API_KEY", "")
    LIVEKIT_API_SECRET: str = os.getenv("LIVEKIT_API_SECRET", "")

    @property
    def agnes_base_url(self) -> str:
        # 国内版 / 国际版
        return (
            "https://apihub.agnes-ai.cn/v1/chat/completions"
            if self.AGNES_USE_CN
            else "https://apihub.agnes-ai.com/v1/chat/completions"
        )

    @property
    def has_agnes(self) -> bool:
        return bool(self.AGNES_API_KEY)


settings = Settings()

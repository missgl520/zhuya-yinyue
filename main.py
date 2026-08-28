# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 竹笌后端主程序（main.py）—— 纯装配模式
#
# FastAPI 应用入口，仅负责：
#   1. 创建应用实例（全局签名鉴权）
#   2. 配置 CORS 中间件
#   3. 启动时自动拉起本地 IndexTTS 微服务
#   4. 初始化数据库
#   5. 注册所有资源 router
#
# 所有端点实现已按资源拆分到 routers/ 包：
#   health.py    —— GET /, GET /health
#   config.py    —— POST /wake-word, POST /persona
#   emotion.py   —— POST /emotion
#   tts.py       —— POST /tts
#   chat.py      —— POST /chat/v2（SSE 流式对话）
#   memory.py    —— /memory/*（7 个端点）
#   affinity.py  —— GET /affinity
#   livekit.py   —— GET /livekit/connect
#   legal.py     —— GET /legal/privacy, GET /legal/terms
#   user.py      —— GET /user/export, DELETE /user/data
#
# 运行：uvicorn main:app --host 0.0.0.0 --port 8000
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import os

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware

import auth
import db
from config import settings

# 按资源拆分的路由模块
from routers import (
    affinity,
    chat,
    config,
    emotion,
    health,
    legal,
    livekit,
    lyrics,
    memory,
    music,
    pet,
    songs,
    tts,
    user,
)

app = FastAPI(
    title="竹笌后端 (ZhuyApp Backend)",
    version="1.2.0",
    # 全路由统一签名鉴权（公开路径在 auth.verify_request 内白名单放行）
    dependencies=[Depends(auth.verify_request)],
)


# ════════════════════════════════════════════════════════
# 启动时自动拉起本地 IndexTTS 微服务
# ════════════════════════════════════════════════════════

def _start_tts_service():
    """自动拉起本地 IndexTTS 2.5 微服务（仅当 8001 端口空闲时）。

    这样用户只需启动主后端，语音合成服务随之就绪；端口已被占用或
    设置 ZHUYU_NO_TTS=1 时跳过。权重未下载前 /tts 会返回 503，属正常。
    """
    import socket
    import subprocess

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.connect(("127.0.0.1", 8001))
        sock.close()
        print(">> [TTS] 微服务已在 8001 运行，跳过拉起", flush=True)
        return
    except OSError:
        pass

    if os.environ.get("ZHUYU_NO_TTS") == "1":
        print(">> [TTS] ZHUYU_NO_TTS=1，跳过自动拉起", flush=True)
        return

    base = os.path.dirname(os.path.abspath(__file__))
    tts_dir = os.path.join(base, "tts_service", "index-tts")
    venv_py = os.path.join(tts_dir, ".venv", "Scripts", "python.exe")
    if not os.path.exists(venv_py):
        print(">> [TTS] 未找到 TTS 虚拟环境，跳过（请先 uv sync）", flush=True)
        return

    env = dict(os.environ)
    env.setdefault("HF_ENDPOINT", "https://hf-mirror.com")
    env.setdefault("HF_HOME", os.path.join(tts_dir, "checkpoints", "hf_cache"))
    env.setdefault(
        "MODELSCOPE_CACHE",
        os.path.join(base, "tts_service", "modelscope_cache"),
    )
    log_path = os.path.join(tts_dir, "tts_service.log")
    try:
        subprocess.Popen(
            [
                venv_py,
                "-m",
                "uvicorn",
                "app:app",
                "--host",
                "127.0.0.1",
                "--port",
                "8001",
            ],
            cwd=os.path.join(base, "tts_service"),
            env=env,
            stdout=open(log_path, "a"),
            stderr=subprocess.STDOUT,
        )
        print(">> [TTS] 已拉起 IndexTTS 微服务 (127.0.0.1:8001)", flush=True)
    except Exception as e:
        print(f">> [TTS] 拉起失败：{e}", flush=True)


@app.on_event("startup")
def _on_startup():
    _start_tts_service()


# ════════════════════════════════════════════════════════
# CORS 中间件
# ════════════════════════════════════════════════════════

def _cors_origins() -> list:
    # 生产【必须】通过环境变量 ALLOWED_ORIGINS 指定具体域名（逗号分隔）；
    # 未配置时不使用通配符 "*"，仅放行常见本地来源（移动端不受 CORS 限制）。
    if settings.ALLOWED_ORIGINS:
        return settings.ALLOWED_ORIGINS
    return [
        "http://localhost",
        "http://127.0.0.1",
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:5000",
        "https://chilly-sloths-jump.loca.lt",
    ]


app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins(),
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    allow_credentials=False,
)


# ════════════════════════════════════════════════════════
# 数据库初始化
# ════════════════════════════════════════════════════════

# 初始化存储（统一 SQLite：memories / affinity / kv）
db.init()


# ════════════════════════════════════════════════════════
# 注册所有资源 router
# ════════════════════════════════════════════════════════

# 注意：带 prefix 的 router（memory/livekit/legal/user）在各自模块内已声明 prefix，
# 不带 prefix 的 router（health/config/emotion/tts/chat/affinity）使用根路径。

app.include_router(health.router)      # /, /health
app.include_router(config.router)      # /wake-word, /persona
app.include_router(emotion.router)     # /emotion
app.include_router(tts.router)         # /tts
app.include_router(chat.router)        # /chat/v2
app.include_router(memory.router)      # /memory/*
app.include_router(affinity.router)    # /affinity
app.include_router(livekit.router)     # /livekit/connect
app.include_router(legal.router)       # /legal/*
app.include_router(user.router)        # /user/*
# Phase 1 新增路由
app.include_router(pet.router)         # /pet/*（音乐狗子状态与交互）
app.include_router(lyrics.router)      # /lyrics/*（歌词库 CRUD）
app.include_router(music.router)       # /music/*（音乐生成 + 任务 + 音频）
app.include_router(songs.router)       # /songs/*（歌曲库）

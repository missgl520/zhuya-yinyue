# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TTS 语音合成路由
# POST /tts   代理到本地 IndexTTS 2.5 微服务（127.0.0.1:8001）
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import httpx
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse, Response

router = APIRouter(tags=["tts"])

# 本地 IndexTTS 2.5 语音合成微服务地址（由主进程启动时自动拉起）
TTS_SERVICE_URL = "http://127.0.0.1:8001"


@router.post("/tts")
async def tts_proxy(request: Request):
    """代理到本地 IndexTTS 2.5 微服务。

    竹笌的语音由该服务离线合成；微服务未就绪时返回 503，
    前端 TtsService 会静默降级（文字照常显示，仅跳过朗读）。
    """
    raw = await request.body()
    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            r = await client.post(
                TTS_SERVICE_URL,
                content=raw,
                headers={"Content-Type": "application/json"},
            )
        return Response(
            content=r.content,
            media_type="audio/wav",
            status_code=r.status_code,
        )
    except Exception as e:  # 微服务挂了 / 端口不通
        return JSONResponse(
            {"ok": False, "error": f"TTS unavailable: {e}"},
            status_code=503,
        )

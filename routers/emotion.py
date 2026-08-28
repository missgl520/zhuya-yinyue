# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 情绪识别路由
# POST /emotion   14维规则情绪识别 {text} -> {emotion, confidence, scores}
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

from fastapi import APIRouter, Request

import emotion_engine

router = APIRouter(tags=["emotion"])


@router.post("/emotion")
async def emotion(request: Request):
    body = await request.json()
    text = body.get("text", "")
    return emotion_engine.detect_emotion(text)

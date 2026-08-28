# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 音乐生成路由
# POST /music/generate       发起音乐生成（异步任务）
# GET  /music/jobs/{job_id}  查询任务状态
# GET  /music/audio/{filename} 获取生成的音频文件
#
# 真实生成：ace_music.generate()（ACE Music，密钥来自 .env）
#   未配置 ACE_MUSIC_API_KEY → Mock 占位模式（sleep + 空文件）
#   真实生成失败 → 自动降级 Mock，保证前端流程可用
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import asyncio
import os
import threading
import time

from fastapi import APIRouter, Request
from fastapi.responses import FileResponse, JSONResponse

import ace_music
import lyrics_store
import music_store

router = APIRouter(prefix="/music", tags=["music"])


def _run_generation(job_id: str, user_id: str, title: str, prompt: str, lyrics: str, style: str, duration: int):
    """后台线程：生成音乐并落盘。

    优先真实 ACE Music；未配置或失败则降级 Mock 占位。
    """
    try:
        music_store.update_job_status(job_id, "running", user_id=user_id)

        filename = f"{job_id}.wav"
        filepath = music_store.audio_path(filename)

        used_real = False
        if ace_music.is_configured():
            try:
                audio_bytes = asyncio.run(ace_music.generate(prompt, lyrics, duration, "zh"))
                with open(filepath, "wb") as f:
                    f.write(audio_bytes)
                used_real = True
            except Exception as e:  # 真实生成失败 → 降级 Mock
                print(f"[music] ACE 真实生成失败, 降级 Mock: {e}")

        if not used_real:
            # Mock 占位：3 秒 + 空 wav
            time.sleep(3)
            with open(filepath, "wb") as f:
                f.write(b"")

        audio_url = f"/music/audio/{filename}"
        music_store.update_job_status(
            job_id, "done", audio_url=audio_url, duration=float(duration), user_id=user_id
        )
        music_store.add_song(
            title=title or "未命名歌曲",
            audio_url=audio_url,
            duration=float(duration),
            user_id=user_id,
            lyrics_id=None,
            style=style,
        )
    except Exception as e:
        music_store.update_job_status(job_id, "failed", error=str(e), user_id=user_id)


@router.post("/generate")
async def music_generate(request: Request):
    user_id = getattr(request.state, "user_id", "default")
    body = await request.json()
    prompt = body.get("prompt", "")
    lyrics_id = body.get("lyrics_id")
    style = body.get("style", "")
    title = body.get("title", "")
    duration = int(body.get("duration", 180))

    # 如果指定了 lyrics_id，验证存在并提取标题
    lyrics_text = ""
    if lyrics_id:
        lyric = lyrics_store.get(int(lyrics_id), user_id)
        if not lyric:
            return JSONResponse({"ok": False, "error": "歌词不存在"}, status_code=404)
        lyrics_text = lyric.get("content", "") or ""
        if not title:
            title = lyric["title"]

    # 创建任务
    job_id = music_store.create_job(
        prompt=prompt, lyrics_id=lyrics_id, style=style, user_id=user_id
    )

    # 后台启动生成（真实 ACE 或 Mock 降级）
    thread = threading.Thread(
        target=_run_generation,
        args=(job_id, user_id, title, prompt, lyrics_text, style, duration),
        daemon=True,
    )
    thread.start()

    return {"ok": True, "job_id": job_id, "status": "pending"}


@router.get("/jobs/{job_id}")
def music_job_status(job_id: str, request: Request):
    user_id = getattr(request.state, "user_id", "default")
    job = music_store.get_job(job_id, user_id)
    if not job:
        return JSONResponse({"ok": False, "error": "任务不存在"}, status_code=404)
    return job


@router.get("/audio/{filename}")
def music_audio(filename: str, request: Request):
    """获取生成的音频文件。

    安全限制：filename 不得包含路径分隔符，防止目录遍历。
    """
    if "/" in filename or "\\" in filename or ".." in filename:
        return JSONResponse({"ok": False, "error": "无效文件名"}, status_code=400)

    filepath = music_store.audio_path(filename)
    if not os.path.exists(filepath):
        return JSONResponse({"ok": False, "error": "音频文件不存在"}, status_code=404)

    return FileResponse(
        filepath,
        media_type="audio/wav",
        filename=filename,
    )

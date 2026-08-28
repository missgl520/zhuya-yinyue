# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 音乐生成路由
# POST /music/generate       发起音乐生成（异步任务）
# GET  /music/jobs/{job_id}  查询任务状态
# GET  /music/audio/{filename} 获取生成的音频文件
#
# 当前实现：模拟生成流程（pending → running → done），
# 后续可接入真实音乐生成 API（如 Suno / 自研模型）。
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import os
import threading
import time

from fastapi import APIRouter, Request
from fastapi.responses import FileResponse, JSONResponse

import lyrics_store
import music_store

router = APIRouter(prefix="/music", tags=["music"])


def _simulate_generation(job_id: str, user_id: str, title: str):
    """后台线程：模拟音乐生成过程。

    真实实现应替换为调用 Suno API / 自研音乐生成模型。
    生成完成后将音频文件保存到 audio_dir，更新 job 状态，
    并将歌曲加入 songs 库。
    """
    try:
        # 标记为运行中
        music_store.update_job_status(job_id, "running", user_id=user_id)
        time.sleep(3)  # 模拟生成耗时

        # 生成一个占位音频文件（真实实现应为实际音频）
        filename = f"{job_id}.wav"
        filepath = music_store.audio_path(filename)
        # 创建一个空的占位文件（真实实现应写入实际音频数据）
        with open(filepath, "wb") as f:
            f.write(b"")  # 占位

        audio_url = f"/music/audio/{filename}"
        duration = 180.0  # 模拟3分钟

        # 更新任务状态为完成
        music_store.update_job_status(
            job_id, "done", audio_url=audio_url, duration=duration, user_id=user_id
        )

        # 自动加入歌曲库
        music_store.add_song(
            title=title or "未命名歌曲",
            audio_url=audio_url,
            duration=duration,
            user_id=user_id,
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

    # 如果指定了 lyrics_id，验证存在并提取标题
    if lyrics_id:
        lyric = lyrics_store.get(int(lyrics_id), user_id)
        if not lyric:
            return JSONResponse({"ok": False, "error": "歌词不存在"}, status_code=404)
        if not title:
            title = lyric["title"]

    # 创建任务
    job_id = music_store.create_job(
        prompt=prompt, lyrics_id=lyrics_id, style=style, user_id=user_id
    )

    # 后台启动模拟生成（真实实现应改为调用真实 API）
    thread = threading.Thread(
        target=_simulate_generation, args=(job_id, user_id, title), daemon=True
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
    # 安全检查：防止目录遍历
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

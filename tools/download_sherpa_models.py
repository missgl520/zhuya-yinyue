#!/usr/bin/env python3
"""
Sherpa-ONNX 模型下载脚本
===========================
下载 ASR（Paraformer-zh）+ TTS（VITS-zh）模型到本地目录。

用法：
    python3 tools/download_sherpa_models.py --out ./sherpa_models

模型说明：
    ASR: sherpa-onnx-paraformer-zh-2023-09-14（中文语音识别，~16MB）
    TTS: sherpa-onnx-vits-zh-2024-06-11（中文语音合成，~160MB）
"""

import argparse
import os
import sys
import urllib.request
import urllib.error

# ── 模型下载配置 ──────────────────────────────────────────────
SHERPA_MODELS = {
    "asr": {
        "name": "Paraformer-zh ASR",
        "base": "https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.0.0",
        "files": {
            "asr/model.onnx":  "sherpa-onnx-paraformer-zh-2023-09-14/model.onnx",
            "asr/tokens.txt":  "sherpa-onnx-paraformer-zh-2023-09-14/tokens.txt",
        },
    },
    "tts": {
        "name": "VITS-zh TTS",
        "base": "https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.0.0",
        "files": {
            "tts/model.onnx":  "sherpa-onnx-vits-zh-2024-06-11/model.onnx",
            "tts/tokens.txt":  "sherpa-onnx-vits-zh-2024-06-11/tokens.txt",
            "tts/lexicon.txt": "sherpa-onnx-vits-zh-2024-06-11/lexicon.txt",
        },
    },
}

def download_file(url: str, dest: str, chunk_size: int = 8192) -> bool:
    """下载单个文件，显示进度条"""
    try:
        req = urllib.request.Request(url, headers={
            "User-Agent": "Mozilla/5.0 (compatible; sherpa-onnx-downloader/1.0)"
        })
        with urllib.request.urlopen(req, timeout=60) as resp:
            total = int(resp.headers.get("Content-Length", 0))
            downloaded = 0
            print(f"  ⬇  {os.path.basename(dest):40s}", end="", flush=True)

            with open(dest, "wb") as f:
                while True:
                    chunk = resp.read(chunk_size)
                    if not chunk:
                        break
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total > 0:
                        pct = downloaded * 100 // total
                        print(f"\r  ⬇  {os.path.basename(dest):40s}  {pct:3d}%", end="", flush=True)
            print()
            return True

    except urllib.error.HTTPError as e:
        print(f"\n  ❌ HTTP {e.code}: {url}")
        return False
    except urllib.error.URLError as e:
        print(f"\n  ❌ 网络错误: {e.reason}")
        return False
    except Exception as e:
        print(f"\n  ❌ 错误: {e}")
        return False


def download_all(out_dir: str, skip_existing: bool = True) -> bool:
    """下载全部模型"""
    total_ok = 0
    total_fail = 0

    for key, meta in SHERPA_MODELS.items():
        print(f"\n📦 [{key.upper()}] {meta['name']}")
        print("─" * 60)

        for rel_path, remote_name in meta["files"].items():
            dest = os.path.join(out_dir, rel_path)
            url  = f"{meta['base']}/{remote_name}"

            if skip_existing and os.path.exists(dest):
                size = os.path.getsize(dest) / 1024 / 1024
                print(f"  ✅ 已存在: {rel_path} ({size:.1f}MB) — 跳过")
                total_ok += 1
                continue

            os.makedirs(os.path.dirname(dest), exist_ok=True)
            ok = download_file(url, dest)
            if ok:
                size = os.path.getsize(dest) / 1024 / 1024
                print(f"  ✅ 完成: {rel_path} ({size:.1f}MB)")
                total_ok += 1
            else:
                total_fail += 1

    print(f"\n{'='*60}")
    print(f"📊 结果: ✅ {total_ok} 成功 / ❌ {total_fail} 失败")
    if total_fail == 0:
        print(f"\n🎉 全部下载完成！模型路径: {out_dir}")
        print(f"\n在 Flutter 中使用：")
        print(f"  await SherpaOnnxService().initialize(modelsDir: '{out_dir}');")
    return total_fail == 0


def main():
    parser = argparse.ArgumentParser(description="下载 Sherpa-ONNX 模型")
    parser.add_argument("--out", "-o", default="./sherpa_models",
                        help="输出目录 (默认: ./sherpa_models)")
    parser.add_argument("--force", "-f", action="store_true",
                        help="强制重新下载（覆盖已存在的文件）")
    args = parser.parse_args()

    out = os.path.abspath(args.out)
    print(f"🗂  输出目录: {out}")
    print(f"🌐 使用 GitHub releases CDN 下载（可能需要代理）")

    ok = download_all(out, skip_existing=not args.force)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()

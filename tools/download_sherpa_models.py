#!/usr/bin/env python3
"""
Sherpa-ONNX 模型下载脚本
===========================
下载竹笌 App 所需的 ASR + TTS 模型文件。

用法：
    python3 tools/download_sherpa_models.py --out ./sherpa_models

下载内容：
    ASR: Paraformer-zh（中文语音识别）
    TTS: VITS-zh（中文语音合成）

下载完成后在 Flutter 中初始化：
    await SherpaOnnxService().initialize(
        modelsDir: 'assets/sherpa_models',  // 或绝对路径
    );

模型版本：sherpa-onnx v1.13.7
总大小：约 180MB（含所有语言模型）
"""

import argparse
import os
import sys
import urllib.request
import urllib.error
import tarfile
import zipfile

TAG = "v1.13.7"
BASE_URL = f"https://github.com/k2-fsa/sherpa-onnx/releases/download/{TAG}"

# ══════════════════════════════════════════════════════════════════
# 配置：需要下载的模型
# ══════════════════════════════════════════════════════════════════

# 方案 A：下载 Android 全量包（43MB，包含所有模型）
#   优点：一个文件包含所有语言模型
#   缺点：文件较大，需要解压
PACKAGES = {
    "android": {
        "name": "Sherpa-ONNX Android 全量包",
        "url": f"{BASE_URL}/sherpa-onnx-{TAG}-android.tar.bz2",
        "size_mb": 43,
        "contains": ["所有语言 ASR/TTS 模型", "Android 原生库"],
    },
    # 方案 B：下载 Linux 轻量版（只含 CPU 模型）
    "linux_cpu": {
        "name": "Sherpa-ONNX Linux CPU 版",
        "url": f"{BASE_URL}/sherpa-onnx-{TAG}-linux-x64-shared.tar.bz2",
        "size_mb": 64,
        "contains": ["所有语言 ASR/TTS 模型", "Linux x64 原生库"],
    },
}


def download_file(url: str, dest: str, chunk_size: int = 65536) -> bool:
    """下载单个文件，显示进度条"""
    try:
        req = urllib.request.Request(url, headers={
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
        })
        with urllib.request.urlopen(req, timeout=120) as resp:
            total = int(resp.headers.get("Content-Length", 0))

            downloaded = 0
            with open(dest, "wb") as f:
                while True:
                    chunk = resp.read(chunk_size)
                    if not chunk:
                        break
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total > 0 and downloaded % (1024 * 1024) < chunk_size:
                        pct = downloaded * 100 // total
                        print(f"\r  ⬇  {pct:3d}%  ({downloaded/1024/1024:.1f}MB)", end="", flush=True)

            print()
            return True

    except urllib.error.HTTPError as e:
        print(f"\n  ❌ HTTP {e.code}: {url}")
        return False
    except Exception as e:
        print(f"\n  ❌ 错误: {e}")
        if os.path.exists(dest):
            os.remove(dest)
        return False


def extract_chinese_models(archive_path: str, out_dir: str) -> dict:
    """从 tar.bz2 中提取中文 ASR + TTS 模型文件"""
    print(f"\n📦 从 {os.path.basename(archive_path)} 提取中文模型...")

    # 中文模型文件在压缩包中的路径模式
    CHINESE_PATTERNS = [
        "paraformer-zh",   # Paraformer-zh ASR
        "vits-zh",         # VITS 中文 TTS
    ]

    extracted = {"asr": [], "tts": [], "other": []}

    with tarfile.open(archive_path, "r:bz2") as tar:
        members = tar.getmembers()
        print(f"  共 {len(members)} 个文件")

        for member in members:
            name_lower = member.name.lower()
            if not any(p in name_lower for p in CHINESE_PATTERNS):
                continue

            if member.isfile():
                # 提取到对应目录
                if "paraformer" in name_lower and member.name.endswith(".onnx"):
                    dest = os.path.join(out_dir, "asr", os.path.basename(member.name))
                    os.makedirs(os.path.join(out_dir, "asr"), exist_ok=True)
                elif "paraformer" in name_lower and member.name.endswith(".txt"):
                    dest = os.path.join(out_dir, "asr", os.path.basename(member.name))
                    os.makedirs(os.path.join(out_dir, "asr"), exist_ok=True)
                elif "vits" in name_lower and not "cantonese" in name_lower and not "en-" in name_lower:
                    if member.name.endswith(".onnx"):
                        dest = os.path.join(out_dir, "tts", os.path.basename(member.name))
                        os.makedirs(os.path.join(out_dir, "tts"), exist_ok=True)
                    elif member.name.endswith(".txt") or member.name.endswith(".lexicon.txt"):
                        dest = os.path.join(out_dir, "tts", os.path.basename(member.name))
                        os.makedirs(os.path.join(out_dir, "tts"), exist_ok=True)
                    else:
                        dest = None
                else:
                    dest = None

                if dest:
                    try:
                        with tar.extractfile(member) as src:
                            with open(dest, "wb") as dst:
                                dst.write(src.read())
                        size_mb = member.size / 1024 / 1024
                        print(f"  ✅ {member.name} → {dest} ({size_mb:.1f}MB)")

                        if "paraformer" in name_lower:
                            extracted["asr"].append(dest)
                        elif "vits" in name_lower:
                            extracted["tts"].append(dest)
                    except Exception as e:
                        print(f"  ⚠️  提取失败 {member.name}: {e}")

    return extracted


def create_version_file(out_dir: str):
    """写入版本信息文件"""
    import json
    info = {
        "version": TAG,
        "source": "https://github.com/k2-fsa/sherpa-onnx",
        "note": "中文 ASR（Paraformer-zh）+ 中文 TTS（VITS-zh）",
    }
    path = os.path.join(out_dir, "version.json")
    with open(path, "w") as f:
        json.dump(info, f, indent=2)
    print(f"  ✅ 版本信息: {path}")


def main():
    parser = argparse.ArgumentParser(
        description="下载 Sherpa-ONNX 模型（中文 ASR + TTS）"
    )
    parser.add_argument(
        "--out", "-o", default="./sherpa_models",
        help="输出目录 (默认: ./sherpa_models)"
    )
    parser.add_argument(
        "--pkg", "-p", default="android",
        choices=list(PACKAGES.keys()),
        help="下载包类型 (默认: android)",
    )
    parser.add_argument(
        "--skip-download", action="store_true",
        help="跳过下载，直接从 --out 目录中的压缩包提取",
    )
    args = parser.parse_args()

    out_dir = os.path.abspath(args.out)
    pkg_info = PACKAGES[args.pkg]
    archive = os.path.join(out_dir, f"sherpa-onnx-{TAG}-{args.pkg}.tar.bz2")

    print(f"🗂  输出目录: {out_dir}")
    print(f"📦 下载包: {pkg_info['name']} ({pkg_info['size_mb']}MB)")
    print(f"   包含: {', '.join(pkg_info['contains'])}")
    print()

    os.makedirs(out_dir, exist_ok=True)

    # 下载
    if args.skip_download and os.path.exists(archive):
        print(f"✅ 跳过下载（使用已有: {archive}）")
    else:
        print(f"🌐 开始下载...")
        ok = download_file(pkg_info["url"], archive)
        if not ok:
            print("\n❌ 下载失败！可能原因：")
            print("  - 网络不稳定（请挂代理重试）")
            print("  - GitHub CDN 访问受限")
            print(f"\n  替代方案：手动下载 {pkg_info['url']}")
            print(f"           保存到: {archive}")
            print("           然后重新运行: python3 tools/download_sherpa_models.py --skip-download")
            sys.exit(1)

    # 提取中文模型
    if os.path.exists(archive):
        extracted = extract_chinese_models(archive, out_dir)
        create_version_file(out_dir)

        # 整理为标准目录结构
        print("\n📂 最终模型目录:")
        for key in ["asr", "tts"]:
            dir_path = os.path.join(out_dir, key)
            os.makedirs(dir_path, exist_ok=True)
            files = list(Path(dir_path).glob("*") for _ in [None]) or []
            print(f"  {key}/")
            for f in os.listdir(dir_path):
                size = os.path.getsize(os.path.join(dir_path, f))
                print(f"    {f} ({size/1024:.0f}KB)")

        print(f"\n🎉 完成！模型保存在: {out_dir}")
        print(f"\n使用方式:")
        print(f"  await SherpaOnnxService().initialize(modelsDir: '{out_dir}');")
    else:
        print("❌ 压缩包不存在，跳过提取")


if __name__ == "__main__":
    # minimal Polyfill for Path glob
    import glob
    class Path:
        @staticmethod
        def glob(pattern):
            return glob.glob(pattern)
    main()

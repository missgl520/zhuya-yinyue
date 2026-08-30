#!/usr/bin/env bash
# 启动竹笌安卓模拟器 (zhuyu_emu / Pixel 7 / API 34 x86_64)
# 在 Git Bash / Linux / macOS 下可用；脚本内覆盖 ANDROID_SDK_ROOT 以绕过系统误配。
set -e

SDK_WIN="$(cygpath -w "$LOCALAPPDATA/Android/Sdk" 2>/dev/null || echo "C:/Users/ROG/AppData/Local/Android/Sdk")"
export ANDROID_SDK_ROOT="$SDK_WIN"
export ANDROID_HOME="$SDK_WIN"

echo "ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT"
echo "正在启动安卓模拟器 zhuyu_emu ..."
"$SDK_WIN/emulator/emulator.exe" -avd zhuyu_emu -netdelay none -netspeed full -dns-server 8.8.8.8,114.114.114.114

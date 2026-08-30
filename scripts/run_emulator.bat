@echo off
REM 启动竹笌安卓模拟器 (zhuyu_emu / Pixel 7 / API 34 x86_64)
REM 注意：本机系统环境变量 ANDROID_SDK_ROOT 当前误指向 F:\Android\AndroidStudio，
REM 会导致 emulator 找不到 system-images。这里在脚本内覆盖为正确路径。
set "ANDROID_SDK_ROOT=%LOCALAPPDATA%\Android\Sdk"
set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"

if not exist "%ANDROID_SDK_ROOT%\emulator\emulator.exe" (
  echo [错误] 找不到 emulator.exe，请确认 Android SDK 已安装（路径：%ANDROID_SDK_ROOT%）
  pause
  exit /b 1
)

echo 正在启动安卓模拟器 zhuyu_emu ...
"%ANDROID_SDK_ROOT%\emulator\emulator.exe" -avd zhuyu_emu -netdelay none -netspeed full -dns-server 8.8.8.8,114.114.114.114

#!/usr/bin/env bash
# 装 keep-alive 版主 app，截 30 帧覆盖 6s，看 3D 走路是否持续
set -u
ADB="C:/Users/ROG/AppData/Local/Android/Sdk/platform-tools/adb.exe"
PKG=com.zhuyapp.zhuyapp

"$ADB" install -r -t f:/zhuyapp/build/app/outputs/flutter-apk/app-debug.apk 2>&1 | tail -2
"$ADB" shell am force-stop "$PKG" 2>/dev/null
"$ADB" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
echo "LAUNCHED"
sleep 13
for i in $(seq 1 30); do
  "$ADB" exec-out screencap -p > "f:/zhuyapp/_k_$i.png"
  sleep 0.2
done
ls f:/zhuyapp/_k_*.png | wc -l
echo "CAPTURE_DONE"

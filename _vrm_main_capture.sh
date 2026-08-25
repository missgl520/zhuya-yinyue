#!/usr/bin/env bash
# 装主 app（3D 人形版）到模拟器，截 14 帧覆盖 ~2 个走路周期验证真抬腿
set -u
ADB="C:/Users/ROG/AppData/Local/Android/Sdk/platform-tools/adb.exe"
PKG=com.zhuyapp.zhuyapp

"$ADB" install -r -t f:/zhuyapp/build/app/outputs/flutter-apk/app-debug.apk 2>&1 | tail -3
"$ADB" shell am force-stop "$PKG" 2>/dev/null
"$ADB" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
echo "LAUNCHED"
sleep 12
for i in $(seq 1 14); do
  "$ADB" exec-out screencap -p > "f:/zhuyapp/_m_$i.png"
  sleep 0.15
done
ls -la f:/zhuyapp/_m_*.png | head -20
echo "CAPTURE_DONE"

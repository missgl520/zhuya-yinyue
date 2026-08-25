#!/usr/bin/env bash
SDK=C:/Users/ROG/AppData/Local/Android/Sdk
ADB="$SDK/platform-tools/adb.exe"
PKG=com.zhuyapp.zhuyapp

"$ADB" install -r -t f:/zhuyapp/build/app/outputs/flutter-apk/app-debug.apk 2>&1 | tail -3
echo "INSTALL_EXIT=$?"
"$ADB" shell am force-stop $PKG 2>/dev/null
sleep 1
"$ADB" shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
echo "LAUNCHED"
# 等 webview 加载 + 模型渲染
sleep 15
# 截 12 帧，间隔 0.2s，覆盖走路周期
for i in $(seq 1 12); do
  "$ADB" exec-out screencap -p > f:/zhuyapp/_vrm_$i.png
  sleep 0.2
done
ls -la f:/zhuyapp/_vrm_*.png
echo "front: $($ADB shell dumpsys activity activities 2>/dev/null | grep -E 'mResumedActivity' | head -1)"

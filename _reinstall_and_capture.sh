#!/bin/bash
ADB="C:/Users/ROG/AppData/Local/Android/Sdk/platform-tools/adb.exe"
APK="f:/zhuyapp/build/app/outputs/flutter-apk/app-debug.apk"

"$ADB" logcat -c
"$ADB" shell am force-stop com.zhuyapp.zhuyapp
sleep 1
"$ADB" install -r -t "$APK" 2>&1 | tail -3
"$ADB" shell am start -n com.zhuyapp.zhuyapp/.MainActivity
echo "---STARTED, waiting 12s for render---"
sleep 12

# 截 8 帧 (间隔 0.15s, 覆盖 ~1.2s 步态周期)
for i in 1 2 3 4 5 6 7 8; do
  "$ADB" exec-out screencap -p > "f:/zhuyapp/_leg2_$i.png"
  sleep 0.15
done

echo "---FRONT---"
"$ADB" shell dumpsys activity activities 2>/dev/null | grep -E "mResumedActivity" | head -1
echo "---SIZES (不同=动画在跑)---"
ls -la f:/zhuyapp/_leg2_*.png
echo "---FATAL check---"
"$ADB" logcat -d 2>/dev/null | grep -iE "FATAL|MissingLibrary" | head -3

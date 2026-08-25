#!/bin/bash
ADB="C:/Users/ROG/AppData/Local/Android/Sdk/platform-tools/adb.exe"
APK="f:/zhuyapp/build/app/outputs/flutter-apk/app-debug.apk"
"$ADB" shell am force-stop com.zhuyapp.zhuyapp
sleep 1
"$ADB" install -r -t "$APK" 2>&1 | tail -2
"$ADB" shell am start -n com.zhuyapp.zhuyapp/.MainActivity
echo "---WAIT 12s---"
sleep 12
"$ADB" exec-out screencap -p > f:/zhuyapp/_leg_max.png
echo "---front---"
"$ADB" shell dumpsys activity activities 2>/dev/null | grep -E "mResumedActivity" | head -1
ls -la f:/zhuyapp/_leg_max.png

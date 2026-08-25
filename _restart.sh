#!/bin/bash
ADB="C:/Users/ROG/AppData/Local/Android/Sdk/platform-tools/adb.exe"
"$ADB" logcat -c
"$ADB" shell am force-stop com.zhuyapp.zhuyapp
sleep 1
"$ADB" shell am start -n com.zhuyapp.zhuyapp/.MainActivity
echo "---STARTED---"
sleep 12
"$ADB" exec-out screencap -p > f:/zhuyapp/_retry_f1.png
echo "---FRONT---"
"$ADB" shell dumpsys activity activities 2>/dev/null | grep -E "mResumedActivity|mFocusedActivity" | head -2
echo "---SIZE---"
ls -la f:/zhuyapp/_retry_f1.png
echo "---LOGCAT (app/fatal/flutter)---"
"$ADB" logcat -d 2>/dev/null | grep -iE "zhuyapp|AndroidRuntime|FATAL|flutter|dart" | tail -50

#!/bin/bash
ADB="C:/Users/ROG/AppData/Local/Android/Sdk/platform-tools/adb.exe"
APK="f:/zhuyapp/build/app/outputs/flutter-apk/app-debug.apk"
"$ADB" shell am force-stop com.zhuyapp.zhuyapp
sleep 1
"$ADB" install -r -t "$APK" 2>&1 | tail -2
"$ADB" shell am start -n com.zhuyapp.zhuyapp/.MainActivity
echo "WAIT 12s"
sleep 12
for i in 1 2 3 4 5 6 7 8; do
  "$ADB" exec-out screencap -p > "f:/zhuyapp/_run_$i.png"
  sleep 0.15
done
echo "---sizes---"
ls -la f:/zhuyapp/_run_*.png

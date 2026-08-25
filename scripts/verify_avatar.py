#!/usr/bin/env python3
# 验证竹笌 3D 人形：装 APK -> 启动 App -> 截帧 -> 帧差判定走路动画在播
import subprocess, time, sys
from PIL import Image
import numpy as np

ADB = r'C:/Users/ROG/AppData/Local/Android/Sdk/platform-tools/adb.exe'
PKG = 'com.zhuyapp.zhuyapp'
APK = r'F:/zhuyapp/build/app/outputs/flutter-apk/app-debug.apk'
OUT = r'F:/zhuyapp/_vrf_{}.png'

def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print('CMD FAIL', ' '.join(cmd), r.stderr[:300])
    return r

print('== install ==')
run([ADB, 'install', '-r', '-t', APK])
print('== launch ==')
run([ADB, 'shell', 'monkey', '-p', PKG, '-c', 'android.intent.category.LAUNCHER', '1'])
# model_viewer_plus WebView 在 Android 模拟器上首次加载 GLB 需要 ~8-12s
time.sleep(12)

print('== capture 8 frames ==')
frames = []
for i in range(8):
    p = OUT.format(i)
    with open(p, 'wb') as f:
        subprocess.run([ADB, 'exec-out', 'screencap', '-p'], stdout=f)
    frames.append(p)
    time.sleep(0.5)

print('== frame diff ==')
imgs = [np.asarray(Image.open(p).convert('RGB')).astype(int) for p in frames]
h, w, _ = imgs[0].shape
changes = []
for i in range(1, len(imgs)):
    diff = np.abs(imgs[i] - imgs[i-1]).sum(axis=2)
    # 人物区：中间 50% 宽度
    person = diff[:, w//4:3*w//4]
    changes.append(int((person > 30).sum()))
print('person-pixel changes per frame:', changes)
peak = max(changes)
print('PEAK', peak, '=>', 'ANIMATING (walk playing)' if peak > 5000 else 'FROZEN/static')
# 保存第一帧与帧差最大的两帧对比供肉眼看
Image.fromarray(imgs[0].astype('uint8')).save(r'F:/zhuyapp/_vrf_compare.png')
print('saved _vrf_compare.png (frame0)')

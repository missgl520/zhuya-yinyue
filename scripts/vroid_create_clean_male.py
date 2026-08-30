import ctypes, time, subprocess, shutil, os
import pyautogui
pyautogui.FAILSAFE = False
import PIL.ImageGrab as G

user32 = ctypes.windll.user32

def focus():
    EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    found = []
    def cb(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            n = user32.GetWindowTextLengthW(hwnd)
            if n:
                buf = ctypes.create_unicode_buffer(n + 1)
                user32.GetWindowTextW(hwnd, buf, n + 1)
                if 'VRoid' in buf.value:
                    found.append(hwnd)
        return True
    user32.EnumWindows(EnumWindowsProc(cb), 0)
    h = found[0]
    user32.ShowWindow(h, 9)
    user32.SetForegroundWindow(h)
    time.sleep(0.8)

focus()
# 1. new
pyautogui.click(170, 300, duration=0.2)
print('new')
time.sleep(2.5)
# 2. male
pyautogui.click(1400, 700, duration=0.2)
print('male')
time.sleep(6.0)
# 3. save default
pyautogui.keyDown('ctrl')
pyautogui.keyDown('s')
pyautogui.keyUp('s')
pyautogui.keyUp('ctrl')
print('ctrl+s')
time.sleep(2.5)
# accept default filename "model.vroid" by pressing Enter
pyautogui.keyDown('return')
pyautogui.keyUp('return')
print('enter save')
time.sleep(3.0)
# 4. copy to project dir
src = r'C:\Users\ROG\Documents\model.vroid'
dst = r'F:\zhuyapp\assets\vrm_test\zhuyu_ren_base.vroid'
if os.path.exists(src):
    shutil.copy2(src, dst)
    print('copied', src, '->', dst)
else:
    print('src not found', src)
# 5. screenshot
im = G.grab()
im.save(r'F:\zhuyapp\_vroid_clean_male_done.png')
print('screen saved')

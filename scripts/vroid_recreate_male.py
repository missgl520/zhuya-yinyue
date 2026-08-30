import ctypes, time, os
import pyautogui
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
# 1. click new big card
pyautogui.click(170, 300, duration=0.2)
print('clicked new')
time.sleep(2.5)
# 2. click male (right card in choose-base dialog)
pyautogui.click(1000, 650, duration=0.2)
print('clicked male')
time.sleep(5.0)
# 3. save
pyautogui.keyDown('ctrl')
pyautogui.keyDown('s')
pyautogui.keyUp('s')
pyautogui.keyUp('ctrl')
print('ctrl+s')
time.sleep(2.5)
# 4. type full path and press Enter
os.makedirs(r'F:\zhuyapp\assets\vrm_test', exist_ok=True)
pyautogui.keyDown('ctrl')
pyautogui.keyDown('a')
pyautogui.keyUp('a')
pyautogui.keyUp('ctrl')
pyautogui.typewrite(r'F:\zhuyapp\assets\vrm_test\zhuyu_ren_base.vroid', interval=0.01)
print('typed path')
time.sleep(0.5)
pyautogui.keyDown('return')
pyautogui.keyUp('return')
print('pressed enter')
time.sleep(3.0)
# 5. screenshot
im = G.grab()
im.save(r'F:\zhuyapp\_vroid_recreated.png')
print('screen saved')

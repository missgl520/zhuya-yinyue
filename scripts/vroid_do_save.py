import ctypes, time, os
import pyautogui

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
# Ensure save dialog filename field is selected and type full path
pyautogui.keyDown('ctrl')
pyautogui.keyDown('a')
pyautogui.keyUp('a')
pyautogui.keyUp('ctrl')
out_dir = r'F:\zhuyapp\assets\vrm_test'
os.makedirs(out_dir, exist_ok=True)
pyautogui.typewrite(r'F:\zhuyapp\assets\vrm_test\zhuyu_ren_base.vroid', interval=0.01)
print('typed path')
time.sleep(0.5)
pyautogui.click(560, 545, duration=0.2)  # 保存(S) button approx
print('clicked save')
time.sleep(2.0)

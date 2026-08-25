import ctypes, time
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
# Click "打开" (Open) top-right button
pyautogui.click(2340, 95, duration=0.2)
print('clicked open')
time.sleep(2.5)
# Type full path in filename field
pyautogui.keyDown('ctrl')
pyautogui.keyDown('a')
pyautogui.keyUp('a')
pyautogui.keyUp('ctrl')
pyautogui.typewrite(r'F:\zhuyapp\assets\vrm_test\zhuyu_ren_base.vroid', interval=0.01)
print('typed path')
time.sleep(0.5)
# Click Open button (approx)
pyautogui.click(1080, 620, duration=0.2)
print('clicked open file')
time.sleep(5.0)
im = G.grab()
im.save(r'F:\zhuyapp\_vroid_project_opened.png')
print('screen saved')

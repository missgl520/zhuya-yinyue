import ctypes, time
import pyautogui
import PIL.ImageGrab as G

user32 = ctypes.windll.user32

def find_and_focus():
    windows = []
    EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    def cb(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            n = user32.GetWindowTextLengthW(hwnd)
            if n:
                buf = ctypes.create_unicode_buffer(n + 1)
                user32.GetWindowTextW(hwnd, buf, n + 1)
                if 'VRoid' in buf.value or 'vroid' in buf.value:
                    windows.append((hwnd, buf.value))
        return True
    user32.EnumWindows(EnumWindowsProc(cb), 0)
    if not windows:
        raise RuntimeError('VRoid window not found')
    hwnd, title = windows[0]
    print('focus', hwnd, title)
    user32.ShowWindow(hwnd, 9)
    user32.SetForegroundWindow(hwnd)
    time.sleep(0.8)

find_and_focus()
# Click the big "+" new-project card center
pyautogui.click(170, 300, duration=0.2)
print('clicked (170,300)')
time.sleep(3.0)
im = G.grab()
im.save(r'F:\zhuyapp\_vroid_after_click.png')
print('saved _vroid_after_click.png')

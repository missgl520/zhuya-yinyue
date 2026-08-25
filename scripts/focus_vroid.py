import ctypes, time
from ctypes import wintypes
import PIL.ImageGrab as G

user32 = ctypes.windll.user32

windows = []
EnumWindowsProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

def enum_cb(hwnd, _):
    if user32.IsWindowVisible(hwnd):
        n = user32.GetWindowTextLengthW(hwnd)
        if n:
            buf = ctypes.create_unicode_buffer(n + 1)
            user32.GetWindowTextW(hwnd, buf, n + 1)
            windows.append((hwnd, buf.value))
    return True

user32.EnumWindows(EnumWindowsProc(enum_cb), 0)
print('visible windows count', len(windows))
for h, t in windows:
    if 'VRoid' in t or 'vroid' in t or 'Studio' in t:
        print('found', h, t)
        user32.ShowWindow(h, 9)      # SW_RESTORE
        user32.SetForegroundWindow(h)
        time.sleep(1.5)
        im = G.grab()
        im.save(r'F:\zhuyapp\_vroid_front.png')
        print('saved _vroid_front.png size', im.size)
        break
else:
    print('VRoid window not found among visible windows')
    print(windows[:30])

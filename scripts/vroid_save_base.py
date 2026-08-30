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
pyautogui.keyDown('ctrl')
pyautogui.keyDown('s')
pyautogui.keyUp('s')
pyautogui.keyUp('ctrl')
print('sent ctrl+s')
time.sleep(2.5)
im = G.grab()
im.save(r'F:\zhuyapp\_vroid_save_dialog.png')
print('saved _vroid_save_dialog.png')

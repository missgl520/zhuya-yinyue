import ctypes, time, sys
import pyautogui
from ctypes import wintypes

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32

def find_window():
    result = []
    def enum_proc(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            length = user32.GetWindowTextLengthW(hwnd)
            if length > 0:
                buf = ctypes.create_unicode_buffer(length + 1)
                user32.GetWindowTextW(hwnd, buf, length + 1)
                title = buf.value
                if "VRoid" in title:
                    result.append((hwnd, title))
        return True
    EnumWindowsProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user32.EnumWindows(EnumWindowsProc(enum_proc), 0)
    return result

wins = find_window()
print("windows:", wins)
hwnd = wins[0][0]
user32.ShowWindow(hwnd, 3)
time.sleep(0.5)

current = user32.GetForegroundWindow()
if hwnd != current and current:
    fg_thread = user32.GetWindowThreadProcessId(current, None)
    my_thread = kernel32.GetCurrentThreadId()
    user32.AttachThreadInput(fg_thread, my_thread, True)
    user32.SetForegroundWindow(hwnd)
    user32.AttachThreadInput(fg_thread, my_thread, False)
time.sleep(1.0)

img = pyautogui.screenshot()
img.save(r"F:/zhuyapp/_vroid_now.png")
print("saved", img.size)

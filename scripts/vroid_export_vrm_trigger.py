import ctypes
from ctypes import wintypes
import time
import pyautogui

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32

SW_RESTORE = 9
SW_SHOW = 5

# Find VRoid Studio window by class/title.
# Use EnumWindows to look for title containing "VRoid Studio"
TARGET_SUBSTR = "VRoid Studio"

found_hwnd = None

def enum_proc(hwnd, extra):
    global found_hwnd
    if not user32.IsWindowVisible(hwnd):
        return True
    text = ctypes.create_unicode_buffer(256)
    user32.GetWindowTextW(hwnd, text, 256)
    t = text.value
    if TARGET_SUBSTR in t:
        found_hwnd = hwnd
        return False
    return True

EnumWindowsProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
user32.EnumWindows(EnumWindowsProc(enum_proc), 0)

if found_hwnd is None:
    raise RuntimeError("VRoid Studio window not found")

print(f"VRoid hwnd={found_hwnd}")

# Restore if minimized and bring to foreground
if user32.IsIconic(found_hwnd):
    user32.ShowWindow(found_hwnd, SW_RESTORE)
else:
    user32.ShowWindow(found_hwnd, SW_SHOW)

time.sleep(0.2)

# SetForegroundWindow may fail if current thread isn't attached; try AttachThreadInput
current_thread = kernel32.GetCurrentThreadId()
target_thread = user32.GetWindowThreadProcessId(found_hwnd, None)
if current_thread != target_thread:
    user32.AttachThreadInput(current_thread, target_thread, True)
user32.SetForegroundWindow(found_hwnd)
if current_thread != target_thread:
    user32.AttachThreadInput(current_thread, target_thread, False)

time.sleep(0.5)

# Send Ctrl+Shift+V via pyautogui (global hotkey, window must be focused)
pyautogui.keyDown('ctrl')
pyautogui.keyDown('shift')
pyautogui.keyDown('v')
pyautogui.keyUp('v')
pyautogui.keyUp('shift')
pyautogui.keyUp('ctrl')

print("sent Ctrl+Shift+V")
time.sleep(2.0)

img = pyautogui.screenshot()
out = r"F:/zhuyapp/_vroid_after_export_hotkey.png"
img.save(out)
print(f"saved: {out}")

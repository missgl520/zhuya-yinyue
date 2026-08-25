import time
import ctypes
from ctypes import wintypes
from PIL import ImageGrab
import pyautogui

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32


def find_vroid():
    found = []
    EnumWindowsProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    def cb(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            buf = ctypes.create_unicode_buffer(256)
            user32.GetWindowTextW(hwnd, buf, 256)
            if "VRoid Studio" in buf.value:
                found.append(hwnd)
        return True
    user32.EnumWindows(EnumWindowsProc(cb), 0)
    return found[0] if found else None


def focus(hwnd):
    user32.ShowWindow(hwnd, 9)
    tid = user32.GetWindowThreadProcessId(hwnd, None)
    cur = kernel32.GetCurrentThreadId()
    if tid != cur:
        user32.AttachThreadInput(cur, tid, True)
    user32.SetForegroundWindow(hwnd)
    if tid != cur:
        user32.AttachThreadInput(cur, tid, False)
    time.sleep(0.5)


def main():
    hwnd = find_vroid()
    focus(hwnd)

    # "返回至选择模型" is at the bottom of the left sidebar.
    x, y = 80, 395
    print(f"clicking '返回至选择模型' at ({x}, {y})")
    pyautogui.click(x, y)
    time.sleep(3.0)

    out = r"F:\zhuyapp\_vroid_after_return_home.png"
    ImageGrab.grab().save(out)
    print(f"saved: {out}")


if __name__ == "__main__":
    main()

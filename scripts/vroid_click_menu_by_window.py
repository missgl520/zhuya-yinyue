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
    time.sleep(0.8)


def main():
    hwnd = find_vroid()
    print(f"VRoid hwnd={hwnd}")
    focus(hwnd)

    rect = wintypes.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(rect))
    print(f"window rect: left={rect.left} top={rect.top} right={rect.right} bottom={rect.bottom}")

    # Click inside the hamburger icon at top-left of client area.
    # Based on prior successful coordinate (32,85), use window top-left + offset.
    x = rect.left + 25
    y = rect.top + 65
    print(f"clicking at ({x}, {y})")
    pyautogui.click(x, y)
    time.sleep(2.5)

    out = r"F:\zhuyapp\_vroid_menu_opened3.png"
    ImageGrab.grab().save(out)
    print(f"saved: {out}")


if __name__ == "__main__":
    main()

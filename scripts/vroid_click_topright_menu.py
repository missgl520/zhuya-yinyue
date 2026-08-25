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
    rect = wintypes.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(rect))
    print(f"window rect: {rect.left},{rect.top} {rect.right},{rect.bottom}")

    # Three-dot menu icon is near top-right of the VRoid content area.
    # Based on full-HD screenshot: top-right icons around x=2500, y=70 in screen coords.
    x = rect.right - 55
    y = rect.top + 55
    print(f"clicking three-dot menu at ({x}, {y})")
    pyautogui.click(x, y)
    time.sleep(1.5)

    out = r"F:\zhuyapp\_vroid_topright_menu.png"
    ImageGrab.grab().save(out)
    print(f"saved: {out}")


if __name__ == "__main__":
    main()

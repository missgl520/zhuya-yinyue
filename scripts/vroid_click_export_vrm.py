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
    time.sleep(0.3)


def main():
    hwnd = find_vroid()
    focus(hwnd)

    # "导出VRM" is the first item in the dropdown under the camera icon.
    x, y = 2390, 120
    print(f"clicking '导出VRM' at ({x}, {y})")
    pyautogui.click(x, y)
    time.sleep(3.0)

    out = r"F:\zhuyapp\_vroid_after_export_vrm_click.png"
    ImageGrab.grab().save(out)
    print(f"saved: {out}")


if __name__ == "__main__":
    main()

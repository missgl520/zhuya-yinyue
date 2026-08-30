import time
import ctypes
from ctypes import wintypes
import cv2
import numpy as np
from PIL import ImageGrab

MENU = r"F:\zhuyapp\scripts\assets\vroid_menu.png"

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


def click_abs(x, y, W, H):
    nx = int(x * 65535 / (W - 1))
    ny = int(y * 65535 / (H - 1))
    user32.mouse_event(0x8000 | 0x0001, nx, ny, 0, 0)
    time.sleep(0.05)
    user32.mouse_event(0x0002, 0, 0, 0, 0)
    time.sleep(0.05)
    user32.mouse_event(0x0004, 0, 0, 0, 0)
    time.sleep(0.05)


def main():
    hwnd = find_vroid()
    focus(hwnd)
    screen = np.array(ImageGrab.grab())
    screen_bgr = cv2.cvtColor(screen, cv2.COLOR_RGB2BGR)
    H, W = screen_bgr.shape[:2]

    tmpl = cv2.imread(MENU)
    res = cv2.matchTemplate(screen_bgr, tmpl, cv2.TM_CCOEFF_NORMED)
    _, max_val, _, max_loc = cv2.minMaxLoc(res)
    th, tw = tmpl.shape[:2]
    print(f"match loc={max_loc} val={max_val:.3f} tmpl={tw}x{th}")

    # Hamburger lines are at the TOP of the template (bbox y=0..~10 within 55x50).
    # Click near the top-center of the matched region, not the geometric center.
    mx = max_loc[0] + tw // 2
    my = max_loc[1] + 8  # near the top lines
    print(f"clicking hamburger at ({mx}, {my})")
    click_abs(mx, my, W, H)
    time.sleep(2.0)

    out = r"F:\zhuyapp\_vroid_menu_opened4.png"
    ImageGrab.grab().save(out)
    print(f"saved: {out}")


if __name__ == "__main__":
    main()

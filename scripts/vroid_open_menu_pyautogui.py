import time
import ctypes
from ctypes import wintypes
import cv2
import numpy as np
from PIL import ImageGrab, Image
import pyautogui

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
    user32.ShowWindow(hwnd, 9)  # restore
    tid = user32.GetWindowThreadProcessId(hwnd, None)
    cur = kernel32.GetCurrentThreadId()
    if tid != cur:
        user32.AttachThreadInput(cur, tid, True)
    user32.SetForegroundWindow(hwnd)
    if tid != cur:
        user32.AttachThreadInput(cur, tid, False)
    time.sleep(0.8)
    fg = user32.GetForegroundWindow()
    buf = ctypes.create_unicode_buffer(256)
    user32.GetWindowTextW(fg, buf, 256)
    print(f"foreground after SetForegroundWindow: {buf.value!r} hwnd={fg}")


def match_template(screen_bgr, tmpl_path, threshold=0.7):
    tmpl = cv2.imread(tmpl_path)
    res = cv2.matchTemplate(screen_bgr, tmpl, cv2.TM_CCOEFF_NORMED)
    _, max_val, _, max_loc = cv2.minMaxLoc(res)
    print(f"template match: loc={max_loc} val={max_val:.3f}")
    if max_val < threshold:
        raise RuntimeError(f"match failed {max_val:.3f}")
    h, w = tmpl.shape[:2]
    return max_loc[0] + w // 2, max_loc[1] + h // 2, max_val


def main():
    hwnd = find_vroid()
    print(f"VRoid hwnd={hwnd}")
    focus(hwnd)

    # Screenshot and locate menu button
    screen = np.array(ImageGrab.grab())
    screen_bgr = cv2.cvtColor(screen, cv2.COLOR_RGB2BGR)
    mx, my, score = match_template(screen_bgr, MENU, threshold=0.7)
    print(f"menu at ({mx}, {my}) score={score:.3f}")

    # Click with pyautogui
    pyautogui.click(mx, my)
    print("clicked menu")
    time.sleep(2.0)

    out = r"F:\zhuyapp\_vroid_menu_opened2.png"
    ImageGrab.grab().save(out)
    print(f"saved: {out}")


if __name__ == "__main__":
    main()

# -*- coding: utf-8 -*-
"""点击 VRoid Studio 左上角菜单并截屏，查看导出 VRM 入口。"""
import time
import ctypes
import cv2
import numpy as np
from PIL import ImageGrab

MENU = r"F:\zhuyapp\scripts\assets\vroid_menu.png"


def find_vroid():
    user32 = ctypes.windll.user32
    EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    found = []
    def cb(hwnd, _):
        if user32.IsWindowVisible(hwnd) and user32.GetWindowTextLengthW(hwnd):
            buf = ctypes.create_unicode_buffer(user32.GetWindowTextLengthW(hwnd) + 1)
            user32.GetWindowTextW(hwnd, buf, len(buf))
            if "VRoid" in buf.value:
                found.append(hwnd)
        return True
    user32.EnumWindows(EnumWindowsProc(cb), 0)
    return found[0] if found else None


def focus(hwnd):
    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32
    tid = user32.GetWindowThreadProcessId(hwnd, None)
    cur = kernel32.GetCurrentThreadId()
    if tid != cur:
        user32.AttachThreadInput(cur, tid, True)
    user32.ShowWindow(hwnd, 9)
    user32.SetForegroundWindow(hwnd)
    if tid != cur:
        user32.AttachThreadInput(cur, tid, False)
    time.sleep(0.5)


def match_template(screen_bgr, tmpl_path, threshold=0.7):
    tmpl = cv2.imread(tmpl_path)
    res = cv2.matchTemplate(screen_bgr, tmpl, cv2.TM_CCOEFF_NORMED)
    _, max_val, _, max_loc = cv2.minMaxLoc(res)
    if max_val < threshold:
        raise RuntimeError(f"match failed {max_val:.3f}")
    h, w = tmpl.shape[:2]
    return max_loc[0] + w // 2, max_loc[1] + h // 2, max_val


def click_abs(x, y, W, H):
    nx = int(x * 65535 / (W - 1))
    ny = int(y * 65535 / (H - 1))
    user32 = ctypes.windll.user32
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
    mx, my, score = match_template(screen_bgr, MENU, threshold=0.7)
    print(f"menu at ({mx}, {my}) score={score:.3f}")
    click_abs(mx, my, W, H)
    time.sleep(1.0)
    ImageGrab.grab().save(r"F:\zhuyapp\_vroid_menu_opened.png")
    print("menu opened screenshot saved")


if __name__ == "__main__":
    main()

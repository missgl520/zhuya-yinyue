# -*- coding: utf-8 -*-
"""用底层 mouse_event/SendInput 在屏幕绝对坐标点点击男性卡片，绕过 pyautogui 的坐标映射。"""
import time
import ctypes
import cv2
import numpy as np
from PIL import ImageGrab

MOUSEEVENTF_MOVE = 0x0001
MOUSEEVENTF_ABSOLUTE = 0x8000
MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004

NEW_CARD = r"F:\zhuyapp\scripts\assets\vroid_new_card.png"
VERIFY = r"F:\zhuyapp\_vroid_male_sendinput.png"


def find_hwnd():
    user32 = ctypes.windll.user32
    EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    found = []
    def cb(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            ln = user32.GetWindowTextLengthW(hwnd)
            if ln > 0:
                buf = ctypes.create_unicode_buffer(ln + 1)
                user32.GetWindowTextW(hwnd, buf, ln + 1)
                if "VRoid" in buf.value:
                    found.append(hwnd)
        return True
    user32.EnumWindows(EnumWindowsProc(cb), 0)
    return found[0] if found else None


def focus_vroid():
    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32
    hwnd = find_hwnd()
    tid = user32.GetWindowThreadProcessId(hwnd, None)
    cur_tid = kernel32.GetCurrentThreadId()
    if tid != cur_tid:
        user32.AttachThreadInput(cur_tid, tid, True)
    user32.ShowWindow(hwnd, 9)
    user32.SetForegroundWindow(hwnd)
    if tid != cur_tid:
        user32.AttachThreadInput(cur_tid, tid, False)
    time.sleep(0.8)
    return hwnd


def match_template(screen_bgr, tmpl_bgr, threshold=0.65):
    res = cv2.matchTemplate(screen_bgr, tmpl_bgr, cv2.TM_CCOEFF_NORMED)
    _, max_val, _, max_loc = cv2.minMaxLoc(res)
    if max_val < threshold:
        raise RuntimeError(f"模板匹配失败 score={max_val:.3f}")
    h, w = tmpl_bgr.shape[:2]
    return max_loc[0] + w // 2, max_loc[1] + h // 2, max_val


def click_abs(x, y, screen_w, screen_h):
    """用底层 mouse_event 在屏幕绝对像素坐标点击。"""
    user32 = ctypes.windll.user32
    nx = int(x * 65535 / (screen_w - 1))
    ny = int(y * 65535 / (screen_h - 1))
    flags_move = MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_MOVE
    user32.mouse_event(flags_move, nx, ny, 0, 0)
    time.sleep(0.05)
    user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    time.sleep(0.05)
    user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
    time.sleep(0.05)
    print(f"mouse_event click ({x}, {y}) norm=({nx}, {ny})")


def main():
    hwnd = focus_vroid()

    # 点新建
    screen = np.array(ImageGrab.grab())
    screen_bgr = cv2.cvtColor(screen, cv2.COLOR_RGB2BGR)
    H, W = screen_bgr.shape[:2]
    new_tmpl = cv2.imread(NEW_CARD)
    nx, ny, nscore = match_template(screen_bgr, new_tmpl, threshold=0.7)
    print(f"new card ({nx}, {ny}) score={nscore:.3f}, screen={W}x{H}")
    click_abs(nx, ny, W, H)
    time.sleep(4.0)

    # 对话框打开，找男性卡片中心
    hwnd = focus_vroid()
    screen = np.array(ImageGrab.grab())
    screen_bgr = cv2.cvtColor(screen, cv2.COLOR_RGB2BGR)
    H, W = screen_bgr.shape[:2]

    # 动态裁男性上半身模板
    roi_x1, roi_y1 = int(W * 0.52), int(H * 0.42)
    roi_x2, roi_y2 = int(W * 0.60), int(H * 0.62)
    male_roi = screen_bgr[roi_y1:roi_y2, roi_x1:roi_x2]
    male_path = r"F:\zhuyapp\scripts\assets\vroid_male_dynamic.png"
    cv2.imwrite(male_path, male_roi)

    mx, my, mscore = match_template(screen_bgr, male_roi, threshold=0.8)
    print(f"male match ({mx}, {my}) score={mscore:.3f}")

    # 底层点击男性（双击）
    click_abs(mx, my, W, H)
    time.sleep(0.1)
    click_abs(mx, my, W, H)

    time.sleep(7.0)
    focus_vroid()
    ImageGrab.grab().save(VERIFY)
    print(f"verify saved: {VERIFY}")


if __name__ == "__main__":
    main()

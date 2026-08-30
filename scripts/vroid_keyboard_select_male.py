# -*- coding: utf-8 -*-
"""点新建打开选择基础对话框后，用键盘方向键+回车选择男性。"""
import time
import ctypes
import cv2
import numpy as np
from PIL import ImageGrab

WM_KEYDOWN = 0x0100
WM_KEYUP = 0x0101
VK_RIGHT = 0x27
VK_RETURN = 0x0D
VK_TAB = 0x09

NEW_CARD = r"F:\zhuyapp\scripts\assets\vroid_new_card.png"
VERIFY = r"F:\zhuyapp\_vroid_male_keyboard.png"


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


def send_key(hwnd, vk):
    user32 = ctypes.windll.user32
    user32.SendMessageW(hwnd, WM_KEYDOWN, vk, 0)
    time.sleep(0.05)
    user32.SendMessageW(hwnd, WM_KEYUP, vk, 0)
    time.sleep(0.05)


def main():
    hwnd = focus_vroid()

    # 1) 点新建
    screen = np.array(ImageGrab.grab())
    screen_bgr = cv2.cvtColor(screen, cv2.COLOR_RGB2BGR)
    new_tmpl = cv2.imread(NEW_CARD)
    nx, ny, nscore = match_template(screen_bgr, new_tmpl, threshold=0.7)
    import pyautogui
    pyautogui.FAILSAFE = False
    pyautogui.click(int(nx), int(ny), duration=0.2)
    print(f"clicked new card ({nx}, {ny})")
    time.sleep(4.0)

    # 2) 对话框打开，切到男性（右方向键）并回车
    hwnd = focus_vroid()
    print("send RIGHT")
    send_key(hwnd, VK_RIGHT)
    time.sleep(0.5)
    print("send RETURN")
    send_key(hwnd, VK_RETURN)

    time.sleep(7.0)
    focus_vroid()
    ImageGrab.grab().save(VERIFY)
    print(f"verify saved: {VERIFY}")


if __name__ == "__main__":
    main()

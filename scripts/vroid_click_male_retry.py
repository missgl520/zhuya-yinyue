# -*- coding: utf-8 -*-
"""在选择基础对话框已打开的前提下，用 pyautogui + OpenCV 点男性卡片进入编辑界面。"""
import time
import ctypes
import cv2
import numpy as np
from PIL import ImageGrab
import pyautogui

pyautogui.FAILSAFE = False
pyautogui.PAUSE = 0.2

MALE_BODY = r"F:\zhuyapp\scripts\assets\vroid_male_body.png"
VERIFY = r"F:\zhuyapp\_vroid_male_retry.png"


def focus_vroid():
    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32
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
    if not found:
        raise RuntimeError("没找到 VRoid Studio 窗口")
    h = found[0]
    tid = user32.GetWindowThreadProcessId(h, None)
    cur_tid = kernel32.GetCurrentThreadId()
    if tid != cur_tid:
        user32.AttachThreadInput(cur_tid, tid, True)
    user32.ShowWindow(h, 9)
    user32.SetForegroundWindow(h)
    if tid != cur_tid:
        user32.AttachThreadInput(cur_tid, tid, False)
    time.sleep(0.8)
    print(f"focused hwnd={h}")


def main():
    focus_vroid()
    screen = np.array(ImageGrab.grab())
    screen_bgr = cv2.cvtColor(screen, cv2.COLOR_RGB2BGR)
    tmpl_bgr = cv2.imread(MALE_BODY)
    res = cv2.matchTemplate(screen_bgr, tmpl_bgr, cv2.TM_CCOEFF_NORMED)
    _, max_val, _, max_loc = cv2.minMaxLoc(res)
    h, w = tmpl_bgr.shape[:2]
    cx, cy = max_loc[0] + w // 2, max_loc[1] + h // 2
    print(f"male body match score={max_val:.3f}, click ({cx}, {cy})")

    pyautogui.moveTo(cx, cy, duration=0.3)
    time.sleep(0.3)
    pyautogui.doubleClick(cx, cy)  # 尝试双击
    print("double clicked")

    time.sleep(6.0)
    focus_vroid()
    ImageGrab.grab().save(VERIFY)
    print(f"verify saved: {VERIFY}")


if __name__ == "__main__":
    main()

# -*- coding: utf-8 -*-
"""用 pyautogui + OpenCV 图像识别点击 VRoid Studio：新建 -> 男性 -> 进入编辑界面。"""
import os
import time
import ctypes
import cv2
import numpy as np
from PIL import ImageGrab
import pyautogui

pyautogui.FAILSAFE = False
pyautogui.PAUSE = 0.3

ASSETS = r"F:\zhuyapp\scripts\assets"
NEW_CARD = os.path.join(ASSETS, "vroid_new_card.png")
MALE_CARD = os.path.join(ASSETS, "vroid_male_card.png")
VERIFY = r"F:\zhuyapp\_vroid_male_clicked_pyautogui.png"


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
    print(f"focused VRoid hwnd={h}")


def find_and_click(template_path, threshold=0.75):
    focus_vroid()
    screen = np.array(ImageGrab.grab())
    screen_bgr = cv2.cvtColor(screen, cv2.COLOR_RGB2BGR)
    tmpl_bgr = cv2.imread(template_path)
    if tmpl_bgr is None:
        raise RuntimeError(f"模板加载失败: {template_path}")

    res = cv2.matchTemplate(screen_bgr, tmpl_bgr, cv2.TM_CCOEFF_NORMED)
    _, max_val, _, max_loc = cv2.minMaxLoc(res)
    print(f"match {os.path.basename(template_path)}: score={max_val:.3f}")
    if max_val < threshold:
        raise RuntimeError(f"模板匹配失败，得分 {max_val:.3f} < {threshold}")

    h, w = tmpl_bgr.shape[:2]
    cx, cy = max_loc[0] + w // 2, max_loc[1] + h // 2
    print(f"click at ({cx}, {cy})")
    pyautogui.click(cx, cy, duration=0.2)


def main():
    # 1) 点「新建」
    find_and_click(NEW_CARD, threshold=0.75)
    time.sleep(4.0)

    # 2) 点「男性」
    find_and_click(MALE_CARD, threshold=0.75)
    time.sleep(6.0)

    # 3) 验证
    focus_vroid()
    ImageGrab.grab().save(VERIFY)
    print(f"verify screenshot saved: {VERIFY}")


if __name__ == "__main__":
    main()

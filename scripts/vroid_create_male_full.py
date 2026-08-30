# -*- coding: utf-8 -*-
"""一键完整流程：重启 VRoid Studio -> 最大化 -> 点新建 -> 选择基础 -> SendMessage 双击男性 -> 进入编辑界面。"""
import os
import subprocess
import time
import ctypes
import cv2
import numpy as np
from PIL import ImageGrab

WM_MOUSEMOVE = 0x0200
WM_LBUTTONDOWN = 0x0201
WM_LBUTTONUP = 0x0202
MK_LBUTTON = 0x0001

ASSETS = r"F:\zhuyapp\scripts\assets"
NEW_CARD = os.path.join(ASSETS, "vroid_new_card.png")
VERIFY = r"F:\zhuyapp\_vroid_male_created_full.png"


def start_vroid():
    subprocess.Popen([r"F:\\2.14.0\\VRoidStudio.exe"], cwd=r"F:\\2.14.0")
    print("VRoid Studio launched")


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


def maximize_and_focus():
    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32
    hwnd = find_hwnd()
    if hwnd is None:
        raise RuntimeError("没找到 VRoid Studio 窗口")
    tid = user32.GetWindowThreadProcessId(hwnd, None)
    cur_tid = kernel32.GetCurrentThreadId()
    if tid != cur_tid:
        user32.AttachThreadInput(cur_tid, tid, True)
    user32.ShowWindow(hwnd, 3)        # SW_MAXIMIZE
    user32.SetForegroundWindow(hwnd)
    if tid != cur_tid:
        user32.AttachThreadInput(cur_tid, tid, False)
    time.sleep(1.0)
    print(f"maximized & focused hwnd={hwnd}")
    return hwnd


def match_template(screen_bgr, tmpl_bgr, threshold=0.65):
    res = cv2.matchTemplate(screen_bgr, tmpl_bgr, cv2.TM_CCOEFF_NORMED)
    _, max_val, _, max_loc = cv2.minMaxLoc(res)
    if max_val < threshold:
        raise RuntimeError(f"模板匹配失败 score={max_val:.3f}")
    h, w = tmpl_bgr.shape[:2]
    return max_loc[0] + w // 2, max_loc[1] + h // 2, max_val


def pyautogui_click_abs(x, y):
    import pyautogui
    pyautogui.FAILSAFE = False
    pyautogui.click(int(x), int(y), duration=0.2)


def send_double_click(hwnd, client_x, client_y):
    user32 = ctypes.windll.user32
    lparam = ((int(client_y) & 0xFFFF) << 16) | (int(client_x) & 0xFFFF)
    user32.SendMessageW(hwnd, WM_MOUSEMOVE, 0, lparam)
    time.sleep(0.05)
    for _ in range(2):
        user32.SendMessageW(hwnd, WM_LBUTTONDOWN, MK_LBUTTON, lparam)
        time.sleep(0.05)
        user32.SendMessageW(hwnd, WM_LBUTTONUP, 0, lparam)
        time.sleep(0.05)
    print(f"sent double-click client ({client_x}, {client_y})")


def screen_to_client(hwnd, sx, sy):
    pt = ctypes.wintypes.POINT()
    pt.x, pt.y = int(sx), int(sy)
    ctypes.windll.user32.ScreenToClient(hwnd, ctypes.byref(pt))
    return pt.x, pt.y


def main():
    # 1) 干净启动
    start_vroid()
    time.sleep(18.0)
    hwnd = maximize_and_focus()

    # 2) 点「新建」
    screen = np.array(ImageGrab.grab())
    screen_bgr = cv2.cvtColor(screen, cv2.COLOR_RGB2BGR)
    new_tmpl = cv2.imread(NEW_CARD)
    nx, ny, nscore = match_template(screen_bgr, new_tmpl, threshold=0.7)
    print(f"new card: ({nx}, {ny}) score={nscore:.3f}")
    pyautogui_click_abs(nx, ny)
    time.sleep(4.5)

    # 3) 对话框打开后，聚焦并截屏
    hwnd = maximize_and_focus()
    screen = np.array(ImageGrab.grab())
    screen_bgr = cv2.cvtColor(screen, cv2.COLOR_RGB2BGR)
    H, W = screen_bgr.shape[:2]

    # 对话框居中，男性卡片在对话框右侧；按屏幕比例裁剪 ROI
    # 基于 2560x1600 下男性人物上半身中心约 (1360, 660)
    roi_x1 = int(W * 0.52)
    roi_x2 = int(W * 0.60)
    roi_y1 = int(H * 0.42)
    roi_y2 = int(H * 0.62)
    male_roi = screen_bgr[roi_y1:roi_y2, roi_x1:roi_x2]
    male_path = os.path.join(ASSETS, "vroid_male_dynamic.png")
    cv2.imwrite(male_path, male_roi)
    print(f"male ROI saved: {male_path}, screen coords ({roi_x1},{roi_y1})-({roi_x2},{roi_y2})")

    # 4) 在 ROI 内匹配得到男性人物中心（相对全屏）
    mx, my, mscore = match_template(screen_bgr, male_roi, threshold=0.8)
    print(f"male dynamic match: ({mx}, {my}) score={mscore:.3f}")

    # 5) SendMessage 双击男性（客户区坐标）
    cx, cy = screen_to_client(hwnd, mx, my)
    send_double_click(hwnd, cx, cy)

    time.sleep(8.0)

    # 6) 验证
    hwnd = maximize_and_focus()
    ImageGrab.grab().save(VERIFY)
    print(f"verify saved: {VERIFY}")


if __name__ == "__main__":
    main()

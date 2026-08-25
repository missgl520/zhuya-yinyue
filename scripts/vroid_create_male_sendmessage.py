# -*- coding: utf-8 -*-
"""完整流程：VRoid Studio 首页点新建 -> 选择基础对话框 -> 动态裁男性模板 -> SendMessage 双击 -> 进入编辑界面。"""
import os
import time
import ctypes
import cv2
import numpy as np
from PIL import ImageGrab

WM_MOUSEMOVE = 0x0200
WM_LBUTTONDOWN = 0x0201
WM_LBUTTONUP = 0x0202
WM_LBUTTONDBLCLK = 0x0203
MK_LBUTTON = 0x0001

ASSETS = r"F:\zhuyapp\scripts\assets"
NEW_CARD = os.path.join(ASSETS, "vroid_new_card.png")
MALE_DYNAMIC = os.path.join(ASSETS, "vroid_male_dynamic.png")
VERIFY = r"F:\zhuyapp\_vroid_male_created.png"


def find_vroid_hwnd():
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
    if not found:
        raise RuntimeError("没找到 VRoid Studio 窗口")
    return found[0]


def focus_vroid():
    hwnd = find_vroid_hwnd()
    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32
    tid = user32.GetWindowThreadProcessId(hwnd, None)
    cur_tid = kernel32.GetCurrentThreadId()
    if tid != cur_tid:
        user32.AttachThreadInput(cur_tid, tid, True)
    user32.ShowWindow(hwnd, 9)
    user32.SetForegroundWindow(hwnd)
    if tid != cur_tid:
        user32.AttachThreadInput(cur_tid, tid, False)
    time.sleep(0.6)
    return hwnd


def match_template(screen_bgr, tmpl_bgr, threshold=0.65):
    res = cv2.matchTemplate(screen_bgr, tmpl_bgr, cv2.TM_CCOEFF_NORMED)
    _, max_val, _, max_loc = cv2.minMaxLoc(res)
    if max_val < threshold:
        raise RuntimeError(f"模板匹配失败 score={max_val:.3f} < {threshold}")
    h, w = tmpl_bgr.shape[:2]
    return max_loc[0] + w // 2, max_loc[1] + h // 2, max_val


def send_click(hwnd, client_x, client_y, double=False):
    user32 = ctypes.windll.user32
    lparam = ((int(client_y) & 0xFFFF) << 16) | (int(client_x) & 0xFFFF)
    user32.SendMessageW(hwnd, WM_MOUSEMOVE, 0, lparam)
    time.sleep(0.05)
    user32.SendMessageW(hwnd, WM_LBUTTONDOWN, MK_LBUTTON, lparam)
    time.sleep(0.05)
    user32.SendMessageW(hwnd, WM_LBUTTONUP, 0, lparam)
    time.sleep(0.05)
    if double:
        user32.SendMessageW(hwnd, WM_LBUTTONDOWN, MK_LBUTTON, lparam)
        time.sleep(0.05)
        user32.SendMessageW(hwnd, WM_LBUTTONUP, 0, lparam)
        time.sleep(0.05)


def screen_to_client(hwnd, sx, sy):
    pt = ctypes.wintypes.POINT()
    pt.x, pt.y = int(sx), int(sy)
    ctypes.windll.user32.ScreenToClient(hwnd, ctypes.byref(pt))
    return pt.x, pt.y


def pyautogui_click_abs(x, y):
    import pyautogui
    pyautogui.FAILSAFE = False
    pyautogui.click(int(x), int(y), duration=0.2)


def main():
    # 1) 前置窗口
    hwnd = focus_vroid()
    print(f"hwnd={hwnd}")

    # 2) 点「新建」——之前 pyautogui 这一步成功
    screen = np.array(ImageGrab.grab())
    screen_bgr = cv2.cvtColor(screen, cv2.COLOR_RGB2BGR)
    new_tmpl = cv2.imread(NEW_CARD)
    nx, ny, nscore = match_template(screen_bgr, new_tmpl, threshold=0.75)
    print(f"new card: ({nx}, {ny}) score={nscore:.3f}")
    pyautogui_click_abs(nx, ny)
    time.sleep(4.0)

    # 3) 对话框打开后，动态裁出男性身体模板（固定 ROI，基于 2560x1600 下的观察）
    hwnd = focus_vroid()
    screen = np.array(ImageGrab.grab())
    screen_bgr = cv2.cvtColor(screen, cv2.COLOR_RGB2BGR)
    # 男性卡片 ROI（右侧人物上半身），若分辨率不同需调
    male_roi = screen_bgr[600:780, 1270:1450]
    cv2.imwrite(MALE_DYNAMIC, male_roi)
    print(f"dynamic male template saved, shape={male_roi.shape}")

    # 4) 在当前截图中匹配这个动态模板，得到精确中心
    mx, my, mscore = match_template(screen_bgr, male_roi, threshold=0.85)
    print(f"male dynamic match: ({mx}, {my}) score={mscore:.3f}")

    # 5) SendMessage 双击男性（客户区坐标）
    cx, cy = screen_to_client(hwnd, mx, my)
    print(f"send double click client ({cx}, {cy})")
    send_click(hwnd, cx, cy, double=True)

    time.sleep(7.0)

    # 6) 验证
    hwnd = focus_vroid()
    ImageGrab.grab().save(VERIFY)
    print(f"verify saved: {VERIFY}")


if __name__ == "__main__":
    main()

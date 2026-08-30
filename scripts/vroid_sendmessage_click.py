# -*- coding: utf-8 -*-
"""用 Windows SendMessage 直接给 VRoid 窗口发送鼠标消息，点击男性卡片。"""
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

MALE_BODY = r"F:\zhuyapp\scripts\assets\vroid_male_body.png"
VERIFY = r"F:\zhuyapp\_vroid_male_sendmessage.png"


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


def client_to_screen(hwnd, cx, cy):
    user32 = ctypes.windll.user32
    pt = ctypes.wintypes.POINT()
    pt.x, pt.y = cx, cy
    user32.ClientToScreen(hwnd, ctypes.byref(pt))
    return pt.x, pt.y


def screen_to_client(hwnd, sx, sy):
    user32 = ctypes.windll.user32
    pt = ctypes.wintypes.POINT()
    pt.x, pt.y = sx, sy
    user32.ScreenToClient(hwnd, ctypes.byref(pt))
    return pt.x, pt.y


def find_template_center(screen_bgr, template_path, threshold=0.75):
    tmpl_bgr = cv2.imread(template_path)
    if tmpl_bgr is None:
        raise RuntimeError(f"模板加载失败: {template_path}")
    res = cv2.matchTemplate(screen_bgr, tmpl_bgr, cv2.TM_CCOEFF_NORMED)
    _, max_val, _, max_loc = cv2.minMaxLoc(res)
    h, w = tmpl_bgr.shape[:2]
    cx, cy = max_loc[0] + w // 2, max_loc[1] + h // 2
    return cx, cy, max_val


def click_client(hwnd, client_x, client_y, double=False):
    user32 = ctypes.windll.user32
    lparam = ((int(client_y) & 0xFFFF) << 16) | (int(client_x) & 0xFFFF)
    # 先 move
    user32.SendMessageW(hwnd, WM_MOUSEMOVE, 0, lparam)
    time.sleep(0.05)
    # down
    user32.SendMessageW(hwnd, WM_LBUTTONDOWN, MK_LBUTTON, lparam)
    time.sleep(0.05)
    # up
    user32.SendMessageW(hwnd, WM_LBUTTONUP, 0, lparam)
    time.sleep(0.05)
    if double:
        user32.SendMessageW(hwnd, WM_LBUTTONDOWN, MK_LBUTTON, lparam)
        time.sleep(0.05)
        user32.SendMessageW(hwnd, WM_LBUTTONUP, 0, lparam)
        time.sleep(0.05)
    print(f"sent click to client ({client_x}, {client_y}), double={double}")


def main():
    hwnd = find_vroid_hwnd()
    print(f"hwnd={hwnd}")

    # 截屏找男性卡片中心（屏幕绝对坐标）
    screen = np.array(ImageGrab.grab())
    screen_bgr = cv2.cvtColor(screen, cv2.COLOR_RGB2BGR)
    sx, sy, score = find_template_center(screen_bgr, MALE_BODY)
    print(f"male body match score={score:.3f}, screen=({sx}, {sy})")

    # 转成客户区坐标
    cx, cy = screen_to_client(hwnd, sx, sy)
    print(f"client coords=({cx}, {cy})")

    # 发送鼠标消息
    click_client(hwnd, cx, cy, double=True)

    time.sleep(6.0)
    ImageGrab.grab().save(VERIFY)
    print(f"verify saved: {VERIFY}")


if __name__ == "__main__":
    main()

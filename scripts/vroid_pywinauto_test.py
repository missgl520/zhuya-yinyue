# -*- coding: utf-8 -*-
"""测试 pywinauto + OpenCV 是否能可靠连接 VRoid 窗口并图像识别点击"""
import time
import cv2
import numpy as np
from PIL import ImageGrab
from pywinauto import Desktop

TEMPLATE = r"F:\zhuyapp\scripts\assets\vroid_new_card.png"


def match_template(screen_bgr, template_bgr, threshold=0.75):
    res = cv2.matchTemplate(screen_bgr, template_bgr, cv2.TM_CCOEFF_NORMED)
    min_val, max_val, min_loc, max_loc = cv2.minMaxLoc(res)
    h, w = template_bgr.shape[:2]
    cx, cy = max_loc[0] + w // 2, max_loc[1] + h // 2
    return (cx, cy, max_val)


def main():
    # 连接 VRoid 窗口（win32 backend，Unity 窗口通常只有顶层窗口一个控件）
    desktop = Desktop(backend="win32")
    win = desktop.window(title_re=".*VRoid.*")
    print("window rect:", win.rectangle())
    print("client rect:", win.client_rect())

    # 前置窗口
    win.set_focus()
    time.sleep(0.8)

    # 截全屏并匹配模板
    screen = np.array(ImageGrab.grab())
    # PIL 截屏是 RGB，opencv 默认用 BGR
    screen_bgr = cv2.cvtColor(screen, cv2.COLOR_RGB2BGR)
    tmpl_bgr = cv2.imread(TEMPLATE)
    cx, cy, score = match_template(screen_bgr, tmpl_bgr, threshold=0.7)
    print(f"new card match: abs=({cx},{cy}), score={score:.3f}")

    # 计算客户区相对坐标
    client = win.client_rect()
    rel_x = cx - client.left
    rel_y = cy - client.top
    print(f"relative coords: ({rel_x}, {rel_y})")

    # 用 pywinauto 点击（会自动把鼠标移到窗口客户区对应位置点击）
    win.click_input(coords=(rel_x, rel_y))
    print("clicked")


if __name__ == "__main__":
    main()

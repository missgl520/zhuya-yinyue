# -*- coding: utf-8 -*-
"""用 Airtest 图像识别在 VRoid Studio 2.14.0 中点击「新建」→「男性」，进入编辑界面。"""
import os
import time
import ctypes
from PIL import ImageGrab
from airtest.core.api import auto_setup, Template, touch, sleep, device

# 桌面模式：直接对全屏做图像识别点击，避开窗口句柄/DPI 问题
auto_setup(__file__, devices=["Windows:///"], logdir=False)

ASSETS = r"F:\zhuyapp\scripts\assets"
NEW_CARD = os.path.join(ASSETS, "vroid_new_card.png")
MALE_CARD = os.path.join(ASSETS, "vroid_male_card_dynamic.png")
VERIFY = r"F:\zhuyapp\_vroid_male_clicked_airtest.png"


def focus_vroid():
    """把 VRoid Studio 窗口强制前置（不要用鼠标去挪，脚本内完成）。"""
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
    h = found[0]
    user32.ShowWindow(h, 9)          # SW_RESTORE
    user32.SetForegroundWindow(h)    # 前置
    time.sleep(0.8)
    print(f"focus VRoid Studio hwnd={h}")


def main():
    focus_vroid()

    # 1) 点首页的「新建」卡片
    print("step 1: touch 新建")
    touch(Template(NEW_CARD, threshold=0.75, rgb=True))
    sleep(3.5)

    # 2) 进入「选择基础」对话框后，动态裁剪男性卡片模板（2560x1600 下位置固定）
    print("step 2: crop male card template")
    focus_vroid()
    screen = ImageGrab.grab()
    # 对话框居中，右侧男性卡片大致区域；若后续失败可调此 box
    male_region = (1180, 520, 1540, 880)
    screen.crop(male_region).save(MALE_CARD)
    print(f"male card template saved: {MALE_CARD}, size={screen.crop(male_region).size}")

    # 3) 点男性卡片
    print("step 3: touch 男性")
    touch(Template(MALE_CARD, threshold=0.75, rgb=True))
    sleep(6.0)

    # 4) 验证
    focus_vroid()
    ImageGrab.grab().save(VERIFY)
    print(f"verify screenshot: {VERIFY}")


if __name__ == "__main__":
    main()

# -*- coding: utf-8 -*-
"""处理 VRoid 保存确认对话框（model.vroid 已存在），点「是」替换，然后复制到 F 盘项目目录。"""
import os
import shutil
import time
import ctypes
from ctypes import wintypes
from PIL import ImageGrab

BM_CLICK = 0x00F5

user32 = ctypes.windll.user32


def find_confirm_dialogs():
    """枚举所有 #32770 对话框，返回子窗口中含「是」按钮的窗口。"""
    EnumWindowsProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    dialogs = []
    def cb(hwnd, _):
        if not user32.IsWindowVisible(hwnd):
            return True
        cls = ctypes.create_unicode_buffer(256)
        user32.GetClassNameW(hwnd, cls, 256)
        if cls.value != "#32770":
            return True
        # 枚举子窗口找「是」按钮
        children = []
        EnumChildProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
        def child_cb(child, _):
            child_cls = ctypes.create_unicode_buffer(256)
            user32.GetClassNameW(child, child_cls, 256)
            ln = user32.GetWindowTextLengthW(child)
            txt = ""
            if ln > 0:
                b = ctypes.create_unicode_buffer(ln + 1)
                user32.GetWindowTextW(child, b, ln + 1)
                txt = b.value
            children.append((child, child_cls.value, txt))
            return True
        user32.EnumChildWindows(hwnd, EnumChildProc(child_cb), 0)
        yes_btns = [c for c, cls2, txt in children if cls2 == "Button" and ("是" in txt or "Yes" in txt or "(&Y)" in txt)]
        if yes_btns:
            dialogs.append((hwnd, yes_btns))
        return True
    user32.EnumWindows(EnumWindowsProc(cb), 0)
    return dialogs


def click_yes_and_copy():
    dialogs = find_confirm_dialogs()
    if not dialogs:
        raise RuntimeError("没找到确认替换对话框")
    for dlg, btns in dialogs:
        print(f"found confirm dialog hwnd={dlg}, yes btns={len(btns)}")
        for btn in btns:
            user32.SendMessageW(btn, BM_CLICK, 0, 0)
            print(f"clicked yes btn={btn}")
    time.sleep(2.0)

    src = r"C:\Users\ROG\Documents\model.vroid"
    dst_dir = r"F:\zhuyapp\assets\vrm_test"
    dst = os.path.join(dst_dir, "zhuyu_ren_base.vroid")
    if not os.path.exists(src):
        raise RuntimeError(f"源文件未生成: {src}")
    os.makedirs(dst_dir, exist_ok=True)
    shutil.copy2(src, dst)
    print(f"copied {src} -> {dst}")

    ImageGrab.grab().save(r"F:\zhuyapp\_vroid_replaced_copied.png")
    print("done")


if __name__ == "__main__":
    click_yes_and_copy()

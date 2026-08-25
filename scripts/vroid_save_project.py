# -*- coding: utf-8 -*-
"""在 VRoid Studio 编辑界面的「保存」对话框中，把项目存到 F:\zhuyapp\assets\vrm_test\zhuyu_ren_base.vroid。"""
import time
import ctypes
from PIL import ImageGrab

VK_CONTROL = 0x11
VK_L = 0x4C
VK_A = 0x41
VK_RETURN = 0x0D
VK_TAB = 0x09


def key_down(vk):
    ctypes.windll.user32.keybd_event(vk, 0, 0, 0)


def key_up(vk):
    ctypes.windll.user32.keybd_event(vk, 0, 2, 0)


def key_combo(vk):
    key_down(VK_CONTROL)
    key_down(vk)
    key_up(vk)
    key_up(VK_CONTROL)
    time.sleep(0.1)


def type_text(text):
    for ch in text:
        # 简单 ASCII 输入
        code = ord(ch)
        if ch.isupper():
            key_down(0x10)  # SHIFT
        ctypes.windll.user32.keybd_event(code, 0, 0, 0)
        time.sleep(0.01)
        ctypes.windll.user32.keybd_event(code, 0, 2, 0)
        if ch.isupper():
            key_up(0x10)
        time.sleep(0.01)


def find_save_dialog():
    user32 = ctypes.windll.user32
    EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    found = []
    def cb(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            ln = user32.GetWindowTextLengthW(hwnd)
            if ln > 0:
                buf = ctypes.create_unicode_buffer(ln + 1)
                user32.GetWindowTextW(hwnd, buf, ln + 1)
                t = buf.value
                # 中文/日文/英文保存对话框标题都可能
                if t in ("保存", "Save", "另存为", "Save As") or "保存" in t:
                    found.append(hwnd)
        return True
    user32.EnumWindows(EnumWindowsProc(cb), 0)
    return found[0] if found else None


def focus_dialog(hwnd):
    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32
    tid = user32.GetWindowThreadProcessId(hwnd, None)
    cur = kernel32.GetCurrentThreadId()
    if tid != cur:
        user32.AttachThreadInput(cur, tid, True)
    user32.ShowWindow(hwnd, 9)
    user32.SetForegroundWindow(hwnd)
    if tid != cur:
        user32.AttachThreadInput(cur, tid, False)
    time.sleep(0.3)


def main():
    dlg = find_save_dialog()
    if dlg is None:
        raise RuntimeError("没找到保存对话框")
    print(f"save dialog hwnd={dlg}")
    focus_dialog(dlg)

    # 1) 聚焦地址栏 (Ctrl+L) 并输入目标目录
    key_combo(VK_L)
    time.sleep(0.2)
    type_text(r"F:\zhuyapp\assets\vrm_test")
    time.sleep(0.2)
    key_down(VK_RETURN)
    key_up(VK_RETURN)
    time.sleep(1.0)

    # 2) 改文件名：Ctrl+A 全选，输入新名
    key_combo(VK_A)
    time.sleep(0.1)
    type_text("zhuyu_ren_base.vroid")
    time.sleep(0.2)

    # 3) 回车保存
    key_down(VK_RETURN)
    key_up(VK_RETURN)
    time.sleep(2.0)

    ImageGrab.grab().save(r"F:\zhuyapp\_vroid_after_save.png")
    print("after-save screenshot saved")


if __name__ == "__main__":
    main()

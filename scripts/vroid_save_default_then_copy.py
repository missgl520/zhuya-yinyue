# -*- coding: utf-8 -*-
"""把 VRoid 项目保存到默认文档目录，再复制到 F 盘项目目录，绕过路径导航问题。"""
import os
import time
import shutil
import ctypes
from ctypes import wintypes
from PIL import ImageGrab

WM_SETTEXT = 0x000C
BM_CLICK = 0x00F5
VK_CONTROL = 0x11
VK_S = 0x53

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32


def find_vroid():
    EnumWindowsProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    found = []
    def cb(hwnd, _):
        if user32.IsWindowVisible(hwnd) and user32.GetWindowTextLengthW(hwnd):
            buf = ctypes.create_unicode_buffer(user32.GetWindowTextLengthW(hwnd) + 1)
            user32.GetWindowTextW(hwnd, buf, len(buf))
            if "VRoid" in buf.value:
                found.append(hwnd)
        return True
    user32.EnumWindows(EnumWindowsProc(cb), 0)
    return found[0] if found else None


def find_save_dialog():
    EnumWindowsProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    found = []
    def cb(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            ln = user32.GetWindowTextLengthW(hwnd)
            if ln > 0:
                buf = ctypes.create_unicode_buffer(ln + 1)
                user32.GetWindowTextW(hwnd, buf, len(buf))
                if "保存" in buf.value or "Save" in buf.value or "另存为" in buf.value:
                    found.append(hwnd)
        return True
    user32.EnumWindows(EnumWindowsProc(cb), 0)
    return found[0] if found else None


def focus(hwnd):
    tid = user32.GetWindowThreadProcessId(hwnd, None)
    cur = kernel32.GetCurrentThreadId()
    if tid != cur:
        user32.AttachThreadInput(cur, tid, True)
    user32.ShowWindow(hwnd, 9)
    user32.SetForegroundWindow(hwnd)
    if tid != cur:
        user32.AttachThreadInput(cur, tid, False)
    time.sleep(0.3)


def send_text(hwnd, text):
    buf = ctypes.create_unicode_buffer(text)
    user32.SendMessageW(hwnd, WM_SETTEXT, 0, ctypes.cast(buf, wintypes.LPWSTR))


def click_button(hwnd):
    user32.SendMessageW(hwnd, BM_CLICK, 0, 0)


def enum_children(hwnd):
    children = []
    EnumChildProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    def cb(child, _):
        cls = ctypes.create_unicode_buffer(256)
        user32.GetClassNameW(child, cls, 256)
        ln = user32.GetWindowTextLengthW(child)
        txt = ""
        if ln > 0:
            b = ctypes.create_unicode_buffer(ln + 1)
            user32.GetWindowTextW(child, b, ln + 1)
            txt = b.value
        children.append((child, cls.value, txt))
        return True
    user32.EnumChildWindows(hwnd, EnumChildProc(cb), 0)
    return children


def main():
    vroid = find_vroid()
    if vroid is None:
        raise RuntimeError("找不到 VRoid 窗口")
    focus(vroid)

    # Ctrl+S 打开保存对话框
    user32.keybd_event(VK_CONTROL, 0, 0, 0)
    user32.keybd_event(VK_S, 0, 0, 0)
    user32.keybd_event(VK_S, 0, 2, 0)
    user32.keybd_event(VK_CONTROL, 0, 2, 0)
    time.sleep(1.5)

    dlg = find_save_dialog()
    if dlg is None:
        raise RuntimeError("找不到保存对话框")
    print(f"save dialog hwnd={dlg}")
    focus(dlg)

    children = enum_children(dlg)
    edits = [c for c, cls, _ in children if cls == "Edit"]
    buttons = [(c, t) for c, _, t in children if t and ("保存" in t or "Save" in t)]
    print(f"edits={len(edits)}, buttons={buttons}")
    if not edits or not buttons:
        raise RuntimeError("控件不足")

    # 只设置纯文件名，保存到文档目录
    send_text(edits[-1], "zhuyu_ren_base.vroid")
    print("set filename to zhuyu_ren_base.vroid")
    time.sleep(0.3)

    click_button(buttons[0][0])
    print("clicked save")
    time.sleep(2.0)

    # 复制到项目目录
    src = r"C:\Users\ROG\Documents\zhuyu_ren_base.vroid"
    dst_dir = r"F:\zhuyapp\assets\vrm_test"
    dst = os.path.join(dst_dir, "zhuyu_ren_base.vroid")
    if not os.path.exists(src):
        raise RuntimeError(f"源文件未生成: {src}")
    os.makedirs(dst_dir, exist_ok=True)
    shutil.copy2(src, dst)
    print(f"copied {src} -> {dst}")

    ImageGrab.grab().save(r"F:\zhuyapp\_vroid_save_done.png")
    print("done")


if __name__ == "__main__":
    main()

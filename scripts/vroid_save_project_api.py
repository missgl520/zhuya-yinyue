# -*- coding: utf-8 -*-
"""用 Windows API 直接操作 VRoid Studio 保存对话框的子控件：设置文件名并点保存。"""
import time
import ctypes
from ctypes import wintypes
from PIL import ImageGrab

WM_SETTEXT = 0x000C
BM_CLICK = 0x00F5
WM_SYSCOMMAND = 0x0112
SC_CLOSE = 0xF060
VK_CONTROL = 0x11
VK_S = 0x53

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32


def keybd_event(vk, flags=0):
    user32.keybd_event(vk, 0, flags, 0)


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
                t = buf.value
                if t in ("保存", "Save", "另存为", "Save As") or "保存" in t:
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


def enum_children(hwnd):
    children = []
    EnumChildProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    def cb(child, _):
        cls = ctypes.create_unicode_buffer(256)
        user32.GetClassNameW(child, cls, 256)
        txt_len = user32.GetWindowTextLengthW(child)
        txt = ""
        if txt_len > 0:
            b = ctypes.create_unicode_buffer(txt_len + 1)
            user32.GetWindowTextW(child, b, txt_len + 1)
            txt = b.value
        children.append((child, cls.value, txt))
        return True
    user32.EnumChildWindows(hwnd, EnumChildProc(cb), 0)
    return children


def send_text(hwnd, text):
    buf = ctypes.create_unicode_buffer(text)
    user32.SendMessageW(hwnd, WM_SETTEXT, 0, ctypes.cast(buf, wintypes.LPWSTR))


def click_button(hwnd):
    user32.SendMessageW(hwnd, BM_CLICK, 0, 0)


def main():
    vroid = find_vroid()
    if vroid is None:
        raise RuntimeError("找不到 VRoid 窗口")
    print(f"vroid hwnd={vroid}")
    focus(vroid)

    # 发送 Ctrl+S 打开保存对话框
    keybd_event(VK_CONTROL)
    keybd_event(VK_S)
    keybd_event(VK_S, 2)
    keybd_event(VK_CONTROL, 2)
    time.sleep(1.5)

    dlg = find_save_dialog()
    if dlg is None:
        raise RuntimeError("找不到保存对话框")
    print(f"save dialog hwnd={dlg}")
    focus(dlg)

    children = enum_children(dlg)
    print(f"children count={len(children)}")
    for c, cls, txt in children:
        print(f"  child={c} cls={cls!r} txt={txt!r}")

    # 找文件名 Edit 和保存 Button
    edits = [c for c, cls, _ in children if cls == "Edit"]
    buttons = [(c, t) for c, _, t in children if t and ("保存" in t or "Save" in t)]
    print(f"edits={len(edits)}, buttons={buttons}")

    if not edits:
        raise RuntimeError("没找到文件名编辑框")
    # 通常最后一个 Edit 是文件名框；设置完整路径
    target = r"F:\zhuyapp\assets\vrm_test\zhuyu_ren_base.vroid"
    send_text(edits[-1], target)
    print(f"set filename: {target}")
    time.sleep(0.3)

    # 点保存按钮，找不到就回车
    if buttons:
        click_button(buttons[0][0])
        print("clicked save button")
    else:
        keybd_event(VK_RETURN)
        keybd_event(VK_RETURN, 2)
        print("pressed Enter")

    time.sleep(2.0)
    ImageGrab.grab().save(r"F:\zhuyapp\_vroid_save_api.png")
    print("after-save screenshot saved")


if __name__ == "__main__":
    main()

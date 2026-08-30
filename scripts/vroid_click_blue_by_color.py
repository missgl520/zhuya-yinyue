import ctypes, time, cv2, numpy as np
import pyautogui
from ctypes import wintypes

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32

def find_window():
    result = []
    def enum_proc(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            length = user32.GetWindowTextLengthW(hwnd)
            if length > 0:
                buf = ctypes.create_unicode_buffer(length + 1)
                user32.GetWindowTextW(hwnd, buf, length + 1)
                title = buf.value
                if "VRoid" in title:
                    result.append((hwnd, title))
        return True
    EnumWindowsProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user32.EnumWindows(EnumWindowsProc(enum_proc), 0)
    return result

wins = find_window()
hwnd = wins[0][0]
user32.ShowWindow(hwnd, 3)
time.sleep(0.3)
current = user32.GetForegroundWindow()
if hwnd != current and current:
    fg_thread = user32.GetWindowThreadProcessId(current, None)
    my_thread = kernel32.GetCurrentThreadId()
    user32.AttachThreadInput(fg_thread, my_thread, True)
    user32.SetForegroundWindow(hwnd)
    user32.AttachThreadInput(fg_thread, my_thread, False)
time.sleep(0.5)

img = pyautogui.screenshot()
img_np = np.array(img)
hsv = cv2.cvtColor(img_np, cv2.COLOR_RGB2HSV)

# blue/cyan button in VRoid export dialog
lower = np.array([95, 120, 120])
upper = np.array([135, 255, 255])
mask = cv2.inRange(hsv, lower, upper)

h, w = mask.shape
roi = mask[int(h*0.45):int(h*0.65), int(w*0.72):]
contours, _ = cv2.findContours(roi, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

if contours:
    largest = max(contours, key=cv2.contourArea)
    area = cv2.contourArea(largest)
    M = cv2.moments(largest)
    if M["m00"] > 0:
        cx = int(M["m10"] / M["m00"]) + int(w*0.72)
        cy = int(M["m01"] / M["m00"]) + int(h*0.45)
        print('blue button center:', cx, cy, 'area:', area)
        pyautogui.click(cx, cy)
    else:
        print('no area in largest contour')
else:
    print('no blue found')

time.sleep(2.0)
img2 = pyautogui.screenshot()
img2.save(r'F:/zhuyapp/_vroid_after_blue_click.png')
print('saved', img2.size)

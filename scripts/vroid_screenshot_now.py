import pyautogui
from PIL import Image
import time

# Brief pause, then screenshot full primary screen
# (VRoid should be maximized/frontmost from previous session)
time.sleep(0.5)
img = pyautogui.screenshot()
out = r"F:/zhuyapp/_vroid_current_now.png"
img.save(out)
print(f"saved: {out} size={img.size}")

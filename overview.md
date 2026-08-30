# 竹笌 3D 人形推进概览

## 已完成

1. **角色设计规范**：`docs/character-vroid-zhuyu-design.md`
   - 基于现有 2D Live2D 角色 Ren/竹笌提取视觉特征。
   - 输出少年体型、发型发色、瞳色、全身服装拆分、配色 HEX、VRoidStudio 2.14.0 操作建议。

2. **程序化 3D 人形 GLB**：`scripts/gen_zhuyu_avatar.py`
   - 用 managed Python 手写 glTF 2.0 GLB，分部位网格 + 8 种材质 + 骨骼层级 + walk 动画关键帧。
   - 输出 `assets/vrm_test/zhuyu_avatar.glb`（126KB，21 网格，8 材质，1 个 walk clip）。
   - 配色贴近竹笌：深灰黑发、青蓝挑染、浅蓝灰瞳、白夹克、黑 X 纹内搭、黑裤、黑短靴黄底。

3. **接入 App 渲染管线**
   - `lib/widgets/vrm_avatar_view.dart`：`kUserAvatarAsset` 指向 `assets/vrm_test/zhuyu_avatar.glb`。
   - `pubspec.yaml` 加入新资源条目。

4. **编译位置合规**
   - 工作目录：`F:\zhuyapp`
   - Flutter SDK：`F:\flutter`
   - 产物：`F:\zhuyapp\build\app\outputs\flutter-apk\app-debug.apk`
   - 全部在 F 盘，符合"不在 C 盘装东西"约束。

5. **模拟器验证（部分）**
   - APK 成功安装到 emulator-5554，3D 竹笌已渲染（白夹克/黑内搭/黑裤靴/黄鞋底/黑发）。
   - 发现相机参数过近（3m/80deg），人物占满屏幕且头顶被切。
   - 已调整为 `0deg 60deg 5m` / target `0m 0.85m 0m` / FOV `32deg`。
   - 正在后台重编验证调整后的框景与走路动画。

## 进行中

- 后台 `flutter build apk --debug` 重编（相机调参后）。
- 重编完成后 `adb install -r` + 截多帧 + 帧差分析，确认 walk 动画持续播放。

## 6. 尝试用 VRoidStudio 2.14.0 自动创建 Ren 基础模型

- 已启动 VRoidStudio 2.14.0（`F:\2.14.0`），并用 pyautogui 成功点开「新建」→「选择基础」对话框。
- **卡在「选择男性」这一步**：坐标点击、OpenCV 图像识别、Tab+Enter、双击均无法让对话框响应；Unity 自绘 GUI 的点击事件无法被 pyautogui 稳定模拟。
- 保存对话框对完整路径解析异常（输入 F 盘路径后按钮变成「打开」模式），只能保存到默认「文档」目录后再复制。
- 期间误触加载了一个紫裙猫耳女孩样本模型，已删除错误的 `F:/zhuyapp/assets/vrm_test/zhuyu_ren_base.vroid`。
- 安装 pyautogui + OpenCV 到 managed venv（实际位于 F 盘），不污染 C 盘环境。

## 说明

当前 3D 人形是程序化 low-poly 占位版本，用于先跑通"3D 竹笌 + 真走路动画"链路。VRoidStudio 的捏脸/选择基础体型这一步必须人在 GUI 前点，脚本无法稳定替代；用户点一下「男性」进入编辑界面后，保存、导出 VRM、UV 贴图补全（X 纹/竖条/挑染）、Mixamo 绑 walk、替换 GLB 仍可交给我脚本化完成。
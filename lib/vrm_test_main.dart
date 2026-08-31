// 3D 渲染管线验证入口（临时 spike，不影响主 app 的 Live2D）。
// 构建：flutter build apk --debug --target lib/vrm_test_main.dart
// 目的：确认 model_viewer_plus 在本模拟器能渲染 GLB 并自动播放内嵌走路动画
//      （真膝盖弯曲、脚离地），并验证 4 个角色资产切换正常。
import 'package:flutter/material.dart';
import 'package:zhuyapp/widgets/vrm_avatar_view.dart';

void main() => runApp(const VrmTestApp());

class VrmTestApp extends StatelessWidget {
  const VrmTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFEDF7F0),
        body: SafeArea(
          child: Stack(
            children: const [
              Positioned.fill(
                // 复用主 app 的 VrmAvatarView：默认女角色 + 显示角色切换条
                child: VrmAvatarView(
                  role: VrmRole.girl,
                  showRoleSwitch: true,
                ),
              ),
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'VRM TEST — 角色切换 (zhuyu / dog / girl / boy)',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

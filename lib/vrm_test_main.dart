// 3D 渲染管线验证入口（临时 spike，不影响主 app 的 Live2D）。
// 构建：flutter build apk --debug --target lib/vrm_test_main.dart
// 目的：确认 model_viewer_plus 在本模拟器能渲染 GLB 并自动播放内嵌走路动画
//      （真膝盖弯曲、脚离地），为后续接用户 VRoid .vrm 铺路。
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

void main() => runApp(const VrmTestApp());

class VrmTestApp extends StatelessWidget {
  const VrmTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFEDF7F0),
        body: Stack(
          children: [
            const Positioned.fill(
              child: ModelViewer(
                src: 'assets/vrm_test/CesiumMan.glb',
                alt: 'CesiumMan walk test',
                autoPlay: true,
                cameraControls: true,
                cameraOrbit: '0deg 80deg 3m',
                cameraTarget: '0m 1m 0m',
                fieldOfView: '35deg',
                backgroundColor: Color(0xFFEDF7F0),
              ),
            ),
            const Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'VRM TEST — CesiumMan (walk)',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

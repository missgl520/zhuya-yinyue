import Flutter
import UIKit

// @main 标记该类型为应用入口点（替代旧版 @UIApplicationMain）
@main
// @objc 暴露给 Objective-C 运行时，Flutter 插件注册需要
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    /// 应用启动完成回调
    /// - Parameters:
    ///   - application: UIApplication 实例
    ///   - launchOptions: 启动参数（如推送、URL Scheme 等）
    /// - Returns: 是否成功处理启动
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    /// 隐式 Flutter 引擎初始化完成回调
    /// 在这里注册所有 Flutter 插件，确保插件在引擎启动后即可使用
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }
}

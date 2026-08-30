// 项目级 Gradle 设置文件（Kotlin DSL）

pluginManagement {
    // 从 local.properties 中读取 Flutter SDK 路径
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            // 若未配置 flutter.sdk，则抛出错误提示
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    // 将 Flutter 工具中的 Gradle 构建脚本作为复合构建引入
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // 阿里云镜像优先（国内加速，避免先访问国际仓库被墙导致卡死）
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        // 国际仓库作为 fallback（国内镜像缺失时）
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    // Flutter 插件加载器
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Android 应用插件（仅声明，不应用）
    // AGP 8.11.1 与 Gradle 9.1 兼容，使用新 DSL（compileSdk 属性赋值）
    id("com.android.application") version "8.11.1" apply false
    // Kotlin Android 插件（仅声明，不应用）
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

// 包含 app 模块
include(":app")

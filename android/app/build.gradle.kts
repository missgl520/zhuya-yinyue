import java.util.Properties

plugins {
    // Android 应用插件
    id("com.android.application")
    // Flutter Gradle 插件必须在 Android 和 Kotlin 插件之后应用
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // 应用的命名空间，需与 AndroidManifest.xml 中的 package 保持一致
    namespace = "com.zhuyapp.zhuyapp"
    // 编译 SDK 版本由 Flutter 工具自动提供
    compileSdk = 36
    // NDK 版本由 Flutter 工具自动提供
    ndkVersion = flutter.ndkVersion

    // Java 编译兼容性设置为 JDK 17
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 应用唯一包名
        applicationId = "com.zhuyapp.zhuyapp"
        // 最低支持 Android 7.0（API 24）
        // 原因：flutter_live2d 插件依赖 OpenGL ES 2.0，最低需要 Android 7.0
        minSdk = 24
        // 目标 SDK 版本由 Flutter 工具自动提供
        targetSdk = 36
        // 版本号和版本名称由 Flutter 工具自动提供（来自 pubspec.yaml）
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ── 签名配置 ───────────────────────────────────────────────
    // 读取优先级：环境变量（CI） > key.properties（本地） > 不设置（回退 debug）
    // CI 通过环境变量注入，避免把 keystore / 密码提交到仓库：
    //   KEYSTORE_FILE        keystore 文件的绝对/相对路径
    //   KEYSTORE_PASSWORD    keystore 密码
    //   KEY_ALIAS            密钥别名
    //   KEY_PASSWORD         密钥密码
    signingConfigs {
        create("release") {
            val envStoreFile = System.getenv("KEYSTORE_FILE")
            val envStorePassword = System.getenv("KEYSTORE_PASSWORD")
            val envKeyAlias = System.getenv("KEY_ALIAS")
            val envKeyPassword = System.getenv("KEY_PASSWORD")

            if (envStoreFile != null && envStorePassword != null &&
                envKeyAlias != null && envKeyPassword != null) {
                // CI / 命令行：从环境变量读取签名信息
                storeFile = file(envStoreFile)
                storePassword = envStorePassword
                keyAlias = envKeyAlias
                keyPassword = envKeyPassword
            } else {
                // 本地开发：从根目录 key.properties 读取（已被 .gitignore 排除）
                val keyPropsFile = rootProject.file("key.properties")
                if (keyPropsFile.exists()) {
                    val props = Properties()
                    keyPropsFile.inputStream().use { stream -> props.load(stream) }
                    storeFile = file(props.getProperty("storeFile"))
                    storePassword = props.getProperty("storePassword")
                    keyAlias = props.getProperty("keyAlias")
                    keyPassword = props.getProperty("keyPassword")
                }
            }
        }
    }

    // ── 构建变体（Build Types）─────────────────────────────────
    buildTypes {
        release {
            // 仅当 release 签名配置完整且 keystore 文件存在时使用正式签名；
            // 否则回退到 debug 签名（保证本地 `flutter build apk` 不中断），并打印警告。
            // 若需强制 release 签名（缺失即报错），构建时加 -PzhuyappStrictSigning=true。
            val releaseStoreFile = signingConfigs.findByName("release")?.storeFile
            val canReleaseSign = releaseStoreFile != null && releaseStoreFile.exists()
            signingConfig = if (canReleaseSign) {
                signingConfigs.getByName("release")
            } else {
                if (project.hasProperty("zhuyappStrictSigning")) {
                    throw GradleException(
                        "缺少 release 签名配置（key.properties 或 KEYSTORE_* 环境变量），" +
                            "且已开启 zhuyappStrictSigning，终止构建。"
                    )
                }
                logger.warn(
                    "⚠️ 未找到 release 签名配置（key.properties 或 KEYSTORE_* 环境变量缺失），" +
                        "将回退到 debug 签名。生成的 APK 不是 release 签名，无法上架应用商店。"
                )
                signingConfigs.getByName("debug")
            }

            // R8 压缩 / 混淆：默认关闭，避免误伤 Flutter 插件。
            // 开启：`./gradlew assembleRelease -PzhuyappMinify=true`
            isMinifyEnabled = project.findProperty("zhuyappMinify") == "true"
            isShrinkResources = isMinifyEnabled
        }

        debug {
            // debug 变体保持默认 debug 签名，便于开发期安装调试
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        // Kotlin 编译目标 JVM 17，与 Java compileOptions 保持一致
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    // Flutter 项目根目录相对位置
    source = "../.."
}

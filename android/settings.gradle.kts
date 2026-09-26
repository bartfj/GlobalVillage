// 设置代理仓库与镜像（解决国内网络访问 Google/Gradle 官方源慢或不可达的问题）
pluginManagement {
    // 读取 flutter SDK 路径：UTF-8 方式读 local.properties（Properties.load 默认
    // ISO-8859-1 会把中文路径读成乱码），读取失败或路径无效时用相对路径兜底。
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        runCatching {
            file("local.properties").bufferedReader(Charsets.UTF_8).use { properties.load(it) }
        }
        val fromProps = properties.getProperty("flutter.sdk")
        if (fromProps != null && file(fromProps).exists()) fromProps else "../.trae/sdk/flutter"
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        maven { setUrl("https://maven.aliyun.com/repository/gradle-plugin") }
        maven { setUrl("https://maven.aliyun.com/repository/google") }
        maven { setUrl("https://maven.aliyun.com/repository/public") }
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
    }
}

plugins {
    // 应用于 Settings：读取 .flutter-plugins-dependencies 并把插件子工程 include 进构建，
    // 这样插件才能向 app 传递 flutter_embedding 依赖（放在 pluginManagement 中则不会生效）。
    id("dev.flutter.flutter-plugin-loader")
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}
dependencyResolutionManagement {
    repositories {
        maven { setUrl("https://maven.aliyun.com/repository/google") }
        maven { setUrl("https://maven.aliyun.com/repository/public") }
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
    }
}

rootProject.name = "english_village"
include(":app")

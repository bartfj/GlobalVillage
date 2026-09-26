# 更换 App 图标计划（v0.6.5）

## Summary
把 Android 启动图标从 Flutter 默认机器人换成"地球村"主题图标：多邻国绿（#58CC02）圆角底 + 白色地球线稿，与 App 名称、主题色统一。用 PIL 程序化绘制（可复现），覆盖 5 档 mipmap 分辨率，构建 v0.6.5 并模拟器桌面实测。

## Current State Analysis
- 图标资源：`android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`，尺寸 48/72/96/144/192，均为 Flutter 默认机器人图。
- [AndroidManifest.xml](file:///d:/workspace/github_code/地球村/android/app/src/main/AndroidManifest.xml#L5) 引用 `@mipmap/ic_launcher`；无 adaptive icon（无 mipmap-anydpi-v26），直接换 PNG 即可生效。
- 主题色：[theme.dart](file:///d:/workspace/github_code/地球村/lib/app/theme.dart#L5) `AppColors.green = 0xFF58CC02`。
- PIL 可用：`.trae\sdk\pylibs`（gen_qr.py 已用同方式引入）。

## Proposed Changes

### 1. 新增图标生成脚本 `.trae/gen_icon.py`
- `sys.path.insert(0, r'd:\workspace\github_code\地球村\.trae\sdk\pylibs')` 引入 PIL（与 gen_qr.py 一致）。
- 在 512×512 母版上绘制：
  - 圆角矩形背景：填充 #58CC02，圆角半径约 112（22%），RGBA 透明外圈；
  - 白色地球线稿（描边宽约 28，抗锯齿由 LANCZOS 缩放保证）：外圆（圆心 256,256、半径约 150）+ 经线竖椭圆（rx 约 70）+ 赤道横线 + 上下两条纬线弦（半弦长 = sqrt(r²−dy²)，dy≈70）；
  - 全部白色描边、无填充，风格与 App 内线性图标一致。
- 用 `Image.LANCZOS` 缩放出 48/72/96/144/192 五档，覆盖写入对应 `mipmap-*/ic_launcher.png`。
- 另存 512 母版到 `.trae\icon_preview.png` 供预览。
- 运行：`python .trae\gen_icon.py`，打印各输出路径与尺寸。

### 2. 升版本 0.6.5
- [constants.dart](file:///d:/workspace/github_code/地球村/lib/core/constants.dart#L5)：`kAppVersion = '0.6.5'`
- [pubspec.yaml](file:///d:/workspace/github_code/地球村/pubspec.yaml#L4)：`version: 0.6.5+11`

### 3. 构建与分发
- 环境变量按项目记忆（FLUTTER_STORAGE_BASE_URL/PUB_HOSTED_URL/PUB_CACHE/APPDATA/LOCALAPPDATA + ANDROID_SDK_ROOT/ANDROID_HOME/GRADLE_USER_HOME），在 `D:\english_village` 下 `flutter build apk --debug`。
- `Copy-Item` 为 `.trae\v065.apk`；`.trae\gen_qr.py` URL 改 `v065.apk` 并运行；`curl --head` 验证 HTTP 200。

## Assumptions & Decisions
- 不引入 adaptive icon（anydpi-v26 XML），维持现有 PNG 直引方式，改动最小。
- 图标风格：绿底 + 白色地球线稿，不加文字（小尺寸下文字不可读）；欢迎页 Logo 不动。
- 圆角由 PNG 自带透明圆角，桌面启动器直接显示圆角方形。

## Verification
1. 运行 gen_icon.py 后 Read `.trae\icon_preview.png` 目视确认设计。
2. 构建成功后 `adb install -r .trae\v065.apk`。
3. `adb shell input keyevent KEYCODE_HOME` 回桌面 + screencap，Read 截屏确认桌面图标为绿底白地球、名称"地球村"。
4. 更新项目记忆（v0.6.5 图标更换、gen_icon.py 可复现）。

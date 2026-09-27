# 地球村（GlobalVillage）

闯关式英语学习 App（Flutter / Android），参考多邻国的交互设计，帮助初学者通过「闯关答题 + 听力 + 跟读」循序渐进地学习英语。

## 功能特色

- **16 单元 × 4 课 × 9 题**（576 题）：从问候、时间、家庭到旅行、日常生活场景、运动与健康
- **5 种题型**：中译英选择、词块拼句、听力选择、填空题、跟读评分
- **离线语音识别**：内置 sherpa-onnx + Whisper tiny.en int8 模型，国产手机无系统语音服务也能给跟读打分
- **内置音频**：听力题与通关对话由微软 edge-tts 预生成（Jenny 语音），不依赖手机系统 TTS
- **通关奖励**：单元徽章收集 + 趣味对话表演（米娅/里奥）+ 庆祝动画；每次通关奖励 1 棵梭梭树（种子→幼苗→小树→大树成长阶段）
- **解锁机制**：正确率 ≥ 70% 解锁下一课，进度本地持久化（Hive）
- **多账号与备份**：支持访客/注册用户，进度可备份恢复

## 技术栈

- Flutter 3.x + Dart，Riverpod 状态管理，go_router 路由，Hive 本地存储
- sherpa_onnx（离线语音识别）、speech_to_text（系统语音）、flutter_tts、audioplayers、record

## 目录结构

```
lib/
├── app/          # 主题、路由、providers
├── core/         # 常量、服务（TTS、音效、备份）
├── data/         # 模型、Hive 存储、仓库
└── features/
    ├── learning_path/  # 学习路径页
    ├── lesson/         # 答题流程、结算、庆祝、对话
    └── rewards/        # 徽章收藏页
assets/
├── courses/      # 课程 JSON（course_beginner.json）
├── audio/        # 听力/跟读与对话音频
└── dialogues/    # 单元通关对话脚本
```

## 构建

```bash
flutter pub get
flutter test
flutter build apk --release
```

生成脚本（课程内容、音频、二维码等幂等流水线）位于 `.trae/` 目录。

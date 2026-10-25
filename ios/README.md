# iOS 构建与 Archive

## 当前配置

- Bundle ID：`com.vincentchen.earthvillage`（已在 Apple Developer 注册）
- Team：`ZJ5F7G49LS`（vincent chen）
- 显示名：地球村
- Release/Profile：手动签名 + `EarthVillage AppStore` 描述文件
- 隐私用途说明：麦克风 / 语音识别（跟读）
- `ITSAppUsesNonExemptEncryption` = false

## 已产出

```text
build/ios/ipa/english_village.ipa   # ~96MB，可上传 TestFlight
```

## 发给别人测试（TestFlight）

1. 打开 [App Store Connect → earth village → TestFlight](https://appstoreconnect.apple.com/apps/6816596368/testflight/ios)
2. 等待构建处理完成（通常几分钟到几十分钟，状态变为「就绪测试」）
3. 首次可能需填写「出口合规」：选 **否**（未使用非豁免加密；工程已设 `ITSAppUsesNonExemptEncryption=false`）
4. **内部测试**：添加 App Store Connect 用户为内部测试员  
   **外部测试**：创建外部小组 → 添加邮箱 → 提交「测试信息」审核（通常很快）
5. 测试员用 iPhone 安装 **TestFlight**，接受邀请后即可安装「地球村」

### 重新打包

```bash
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

产物：`build/ios/ipa/english_village.ipa`

### 已上传构建

- IPA：`build/ios/ipa/english_village.ipa`（~118MB）
- Version：`0.8.46` / Build：`63`
- API：`https://api.vincent-tech.cn/v1`
- Delivery UUID：`d7da180e-42da-4554-a762-8756c6755731`
- App ID：`6816596368`

### 历史构建

- Version：`0.8.44` / Build：`61`
- API：`https://validity-republican-suffering-acm.trycloudflare.com/v1`
- Delivery UUID：`ba88cd10-dd5e-4dd9-9da4-9ac6c527b99f`
- Version：`0.8.43` / Build：`60`
- API：`https://validity-republican-suffering-acm.trycloudflare.com/v1`
- Delivery UUID：`c2a82258-a77c-4e99-b4aa-a3c91de73db6`
- Version：`0.8.39` / Build：`56`
- API：`https://validity-republican-suffering-acm.trycloudflare.com/v1`
- Delivery UUID：`a7db1c0f-0644-41da-b31e-3b57b3f865a0`
- Version：`0.8.38` / Build：`55`
- API：`https://validity-republican-suffering-acm.trycloudflare.com/v1`
- Delivery UUID：`c4ce9dd2-790b-4410-9ce8-5275f8e43b03`
- Version：`0.8.35` / Build：`52`
- API：`https://validity-republican-suffering-acm.trycloudflare.com/v1`
- Delivery UUID：`0164ccac-5b5f-48c4-942c-f221a9bfa1d2`
- Version：`0.8.32` / Build：`49`
- API：`https://validity-republican-suffering-acm.trycloudflare.com/v1`
- Delivery UUID：`1d19f1cb-2165-4490-b0b9-901c462712c7`
- Version：`0.8.31` / Build：`48`
- Delivery UUID：`6e916b94-0a5b-448b-94f7-567e5c5c02af`
- Version：`0.8.30` / Build：`47`
- Delivery UUID：`d35390c9-8903-473e-a6c4-73ed4d11b196`
- Version：`0.8.29` / Build：`46`
- Delivery UUID：`912de99e-ece8-4a2f-8d63-57931769a6b9`
- Version：`0.8.27` / Build：`44`
- Delivery UUID：`8f58718b-362f-42f3-ba26-552aa94267e4`
- Version：`0.8.18` / Build：`35`
- Delivery UUID：`64230e45-382f-4caa-b43a-abbeff7c5b62`
- Version：`0.8.17` / Build：`34`
- Delivery UUID：`0f0e9b0f-5494-4ad5-bd38-4e797d18a0cf`
- Version：`0.8.16` / Build：`33`
- Delivery UUID：`a848ef94-f8ff-444c-beb9-173b4fd57083`
- Version：`0.8.15` / Build：`32`
- Delivery UUID：`b74fe8be-7492-41bc-96c2-cf5dc69f1a64`
- Version：`0.8.13` / Build：`30`
- Delivery UUID：`5ffbc684-dea0-4a81-9a83-42b082a3dd52`
- Version：`0.8.5` / Build：`22`
- Delivery UUID：`a346cba1-4f91-4447-abad-4db217048df6`

## 说明

- 账号下目前 **0 台设备**，所以自动签名会失败；已改用 App Store 描述文件打 IPA（见 `ios/ExportOptions.plist`）
- 真机调试需要先在 Developer 后台注册设备 UDID
- IPA 体积会因 Whisper 模型偏大，属预期
- 上传可用 Transporter，或 `xcrun altool --upload-app --type ios -f build/ios/ipa/english_village.ipa`

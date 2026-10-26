# iOS 打包指令（给 Mac 上执行的 agent）

目标：把本仓库的网页（`index.html`）用 Capacitor 包成原生 iOS 应用「百草衡」，先装到我的 iPhone 上，再上传 TestFlight。

仓库：https://github.com/eezzz/HerbalistSimulation

## 已经准备好的

| 文件 | 作用 |
|---|---|
| `capacitor.config.json` | appId `com.eezzz.baicaoheng`，显示名「百草衡」，`webDir` 为 `www` |
| `scripts/build-www.mjs` | 把 `index.html`、`manifest.webmanifest`、`icons/` 复制到 `www/` |
| `package.json` | 脚本：`build:www`、`ios:sync`、`ios:open`（依赖还没装，见步骤 2） |
| `icons/icon-1024.png` | App 图标，1024×1024，RGB 无透明通道，可直接作为 AppIcon |

网页是单文件，没有构建步骤。Bundle ID 如需更换，改 `capacitor.config.json` 的 `appId`，并与 App Store Connect 保持一致。

## 步骤

### 1. 环境

- 最新版 Xcode（已登录开发者账号：Xcode → Settings → Accounts），并装好命令行工具：`xcode-select --install`
- Node.js 20 或以上：`node -v`

### 2. 克隆并安装 Capacitor

```bash
git clone https://github.com/eezzz/HerbalistSimulation.git
cd HerbalistSimulation
npm install @capacitor/core @capacitor/ios
npm install -D @capacitor/cli
```

### 3. 生成 iOS 工程

```bash
npm run build:www
npx cap add ios
```

如果提示需要 CocoaPods：`brew install cocoapods` 后重跑 `npx cap add ios`。

### 4. 替换 App 图标

```bash
cat ios/App/App/Assets.xcassets/AppIcon.appiconset/Contents.json
```

查看其中 1024×1024 那一项的 `filename`（Capacitor 模板一般是 `AppIcon-512@2x.png`），用我们的图标覆盖它：

```bash
cp icons/icon-1024.png ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png
```

文件名以 `Contents.json` 里实际写的为准。

### 5. 工程设置

编辑 `ios/App/App/Info.plist`，加入：

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

（应用不含加密功能，上传 TestFlight 时就不会每次询问出口合规。）

在 Xcode 中打开工程（`npm run ios:open`），选中 **App** target：

- **General → Supported Destinations**：只保留 iPhone（去掉 iPad 和 Mac），避免以后上架还要准备 iPad 截图
- **General → Display Name**：确认为「百草衡」
- **Signing & Capabilities**：勾选 Automatically manage signing，Team 选我的开发者账号，Bundle Identifier 为 `com.eezzz.baicaoheng`
- **General → Version** `1.0.0`，**Build** `1`

然后同步一次：

```bash
npm run ios:sync
```

### 6A. 直接装到我的 iPhone（最快）

1. iPhone 用数据线连到 Mac，手机上信任这台电脑
2. iPhone：设置 → 隐私与安全性 → 开发者模式 → 打开（需重启）
3. Xcode 顶部设备选择我的 iPhone，点 Run（⌘R）

### 6B. 上传 TestFlight

1. 在 App Store Connect（https://appstoreconnect.apple.com）→ 我的 App → 新建 App：平台 iOS，名称「百草衡」，主要语言简体中文，Bundle ID `com.eezzz.baicaoheng`，SKU 填 `baicaoheng`
2. Xcode：设备选 **Any iOS Device (arm64)** → Product → Archive
3. Organizer → Distribute App → App Store Connect → Upload
4. 处理完成后（约 10–30 分钟），在 App Store Connect → TestFlight → 内部测试，把我的 Apple ID 加为测试员
5. 我在 iPhone 上用 TestFlight 应用安装

命令行版本（如果不想点 Xcode 界面）：

```bash
cd ios/App
xcodebuild -workspace App.xcworkspace -scheme App -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/App.xcarchive \
  -allowProvisioningUpdates archive
```

（如果 `cap add ios` 生成的是 `App.xcodeproj` 而没有 `.xcworkspace`，把 `-workspace App.xcworkspace` 换成 `-project App.xcodeproj`。）

新建 `ExportOptions.plist`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
```

```bash
xcodebuild -exportArchive -archivePath build/App.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export -allowProvisioningUpdates
```

## 装好后要在真机上检查

- **灵动岛 / 刘海**：竖屏顶部内容不被遮挡；横屏左右不被遮挡；底部不压 Home 指示条（网页已用 `env(safe-area-inset-*)` 处理，配置里 `contentInset: never`）
- **深色模式**：切换系统深色，页面和状态栏文字都正常
- **离线**：开飞行模式重新打开，页面可用。离线时中文字体会回落到系统的苹方 / 宋体，属正常
- **数据保存**：载入一个方子、改克数，杀掉 App 再打开，状态还在
- **点击**：方库里连续切换不同方子，药方成分随之变化

## 以后更新网页

网页改动推到 GitHub 后，在 Mac 上：

```bash
git pull
npm run ios:sync
```

在 Xcode 把 **Build** 号加 1，再重复 6A 或 6B。

## 注意

- 不要在 iOS 应用里接网页广告（AdSense）；以后要加广告用 AdMob 原生 SDK
- 网页里的 Service Worker 和「添加到主屏幕」提示只在 GitHub Pages 上启用，在 App 内会自动跳过，无需修改
- `www/` 和 `node_modules/` 不提交；`ios/` 目录生成后可以提交，方便以后重复打包

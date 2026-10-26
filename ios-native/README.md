# 百草衡 · iOS 原生版（SwiftUI）

网页版 `index.html` 的原生重写。界面全部是 SwiftUI，数据和计算都在 App 内，**运行时不发起任何网络请求**。

- 最低 iOS 17，仅 iPhone
- Bundle ID：`com.eezzz.baicaoheng`，显示名「百草衡」
- 中英双语（App 内右上角切换）

## 目录

| 路径 | 内容 |
|---|---|
| `project.yml` | XcodeGen 工程定义（`.xcodeproj` 不提交，由它生成） |
| `BaicaoHeng/App/` | App 入口、底部四个标签页 |
| `BaicaoHeng/Model/DataModels.swift` | 数据结构与 `herbdata.json` 加载 |
| `BaicaoHeng/Model/Engine.swift` | 计算模型：溶出率、四气五味、五行、君臣佐使、每日总量与疗程、注意事项。与网页版函数逐项对应 |
| `BaicaoHeng/Model/AppState.swift` | 状态与本地保存（UserDefaults） |
| `BaicaoHeng/Model/Texts.swift` | 中英文文字查找 |
| `BaicaoHeng/Views/` | 方库、药柜、药方、分析四个页面与图表组件 |
| `BaicaoHeng/Resources/herbdata.json` | 123 味药材、85 个方子、44 个配伍及全部英文文本，由 `../scripts/export-herbdata.cjs` 从网页版导出 |

---

## 给 Mac 上 agent 的打包步骤

### 1. 环境

```bash
xcode-select -p          # 确认已装 Xcode 与命令行工具
brew install xcodegen    # 用于生成 .xcodeproj
```

Xcode → Settings → Accounts 中已登录开发者账号。

### 2. 生成工程

```bash
git clone https://github.com/eezzz/HerbalistSimulation.git
cd HerbalistSimulation/ios-native
xcodegen generate
open BaicaoHeng.xcodeproj
```

### 3. 签名

Xcode 中选中 **BaicaoHeng** target → Signing & Capabilities：勾选 Automatically manage signing，Team 选开发者账号。
也可以写进 `project.yml` 的 `settings.base` 里加 `DEVELOPMENT_TEAM: <团队 ID>`，再重新 `xcodegen generate`。

### 4. 编译并修正

```bash
xcodebuild -project BaicaoHeng.xcodeproj -scheme BaicaoHeng \
  -destination 'generic/platform=iOS Simulator' build
```

这份代码是在 Windows 上写的，**没有经过编译**，可能会有少量编译错误。修正原则：

- 只修语法 / 类型 / API 问题，不改计算逻辑和文字内容
- `Engine.swift` 里每个函数都对应网页版 `index.html` 的同名函数，拿不准时以网页版为准
- 工程使用 Swift 5 语言模式（`SWIFT_VERSION: "5.0"`），不要切到 Swift 6 严格并发

### 5. 在模拟器核对计算结果

在模拟器（如 iPhone 16）运行，到「方库」依次载入下列方子，保持默认设置（每日 1 剂、连服 14 天、体重 60 kg、平和体质、非孕期），到「药方」和「分析」页核对。数值由网页版计算得出，原生版应完全一致：

| 方子 | 各药 头煎/合计 溶出率与角色 | 药性 | 出汤 | 建议最长连服 | 功效前三 | 注意事项 |
|---|---|---|---|---|---|---|
| 四君子汤 | 党参 44/61% 君，白术 56/74% 臣，茯苓 23/35% 臣，甘草 56/74% 使 | +0.4 微温 | 528 ml | 7 天 | 健脾、补气、祛湿 | 疗程过长、甘草酸超量 |
| 当归补血汤 | 黄芪 48/66% 君，当归 58/75% 佐（比例 5:1 符合原方） | +1.1 温 | 510 ml | 28 天 | 补气、固表、养血 | 未见明显问题 |
| 杞菊明目茶 | 枸杞子 10/16% 臣，菊花 51/66% 君 | −0.7 凉 | 382 ml | 28 天 | 明目、疏风、清热 | 溶出偏低 |
| 交泰丸茶 | 黄连 41/57% 君，肉桂 35/51% 佐（比例 10:1 符合原方） | −1.4 凉 | 349 ml | 14 天 | 清热、解毒、祛湿 | 寒热并用 |
| 缬草啤酒花安神茶 | 缬草 29/42% 君，啤酒花 65/78% 臣，香蜂草 55/70% 臣，薄荷 55/70% 佐 | −0.3 微凉 | 293 ml | 14 天 | 安神、缓急、理气 | 量偏小、寒热并用 |

### 6. 真机检查

- **灵动岛 / 刘海**：竖屏和横屏下标题、列表都不被遮挡，底部标签栏不压 Home 指示条
- **深色模式**：切换系统深色，所有文字、图表、汤色正常
- **英文**：右上角切到 EN，四个页面没有残留中文（药材档案里的中文名除外）
- **方库**：连续点不同分类、不同方子，药方随之更换，底部「药方」标签上的数字同步
- **按症状找方**：在方库搜索框输入 `dry eye` 或「眼睛干涩」，应识别为「眼干眼累」，前两名是杞菊明目茶、决明子菊花茶；输入「失眠 焦虑」应同时识别两个症状；输入「胸痛」应出现红色就医提示；点症状标签可多选
- **药柜**：搜索“安神”“sleep”都有结果；点药材加入 / 移出；长按可看档案
- **药方**：加减克数、直接输入克数、切换泡水/煮、开关“后下”“捣碎”等，分析页同步变化
- **折叠**：各分区标题可折叠，杀掉 App 再打开后折叠状态和药方都还在
- **断网**：开飞行模式，所有功能正常

### 7. 装到 iPhone

1. iPhone 连 Mac，手机上点“信任”
2. iPhone：设置 → 隐私与安全性 → 开发者模式 → 打开（需重启）
3. Xcode 选该 iPhone 为运行目标，⌘R

### 8. 上传 TestFlight

1. App Store Connect → 我的 App → 新建：iOS，名称「百草衡」，主要语言简体中文，Bundle ID `com.eezzz.baicaoheng`，SKU `baicaoheng`
2. Xcode 运行目标选 **Any iOS Device (arm64)** → Product → Archive → Distribute App → App Store Connect → Upload
3. 处理完成后，TestFlight → 内部测试 → 添加测试员，用 TestFlight App 安装

命令行方式：

```bash
xcodebuild -project BaicaoHeng.xcodeproj -scheme BaicaoHeng -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/BaicaoHeng.xcarchive \
  -allowProvisioningUpdates archive

cat > build/ExportOptions.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST

xcodebuild -exportArchive -archivePath build/BaicaoHeng.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist -exportPath build/export -allowProvisioningUpdates
```

`Info.plist` 已声明 `ITSAppUsesNonExemptEncryption = NO`，上传时不会再问出口合规。每次重新上传，先把 `project.yml` 里的 `CURRENT_PROJECT_VERSION` 加 1，再 `xcodegen generate`。

---

## 数据更新

网页版的药材、方剂、配伍改动后，在仓库根目录运行：

```bash
node scripts/export-herbdata.cjs index.html ios-native/BaicaoHeng/Resources/herbdata.json
```

再重新编译 App 即可。计算公式改动则需要同步修改 `Engine.swift`。

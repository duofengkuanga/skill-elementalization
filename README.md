# CoolSkill

CoolSkill 是一个 Apple Silicon/macOS 15+ 原生桌面 App。它只读取 `~/.agents/skills`，用本地中英文规则归入风、火、水、山，并提供 Codex 调用文本插入能力。

## 当前能力

- 仅扫描 `~/.agents/skills`，不混入 `.codex` 或插件目录；
- 风火水山规则分类、拖拽/右键人工归类和永久状态；
- 从 Codex 本地 rollout 重建显式、自动和子代理 Skill 使用；
- `Command + D + P` 三键监听与 150ms `Command + D` 回放；
- 启动即显示可缩放的技能库主窗口；初始不展开任何元素，悬停左侧图标后显示对应列表；
- 左栏底部保留 Pin，作为窗口置顶开关；手动更新位于设置页；
- 设置入口位于左栏底部：可修改 `Command + 键 + 键` 快捷键、控制登录启动、更新 Skills，并查看或请求辅助功能/输入监听权限；
- 标准 macOS App 生命周期和 Dock 图标；不再创建或依赖菜单栏状态项；
- App 采用四元素彩虹：由外到内为火（朱橙）、山（岩金）、风（青绿）、水（蓝）；保留浅深模式和 Reduce Motion。

## 构建与验证

当前仓库支持两条验证路径：

```sh
Scripts/verify.sh
Scripts/build-app.sh
Scripts/verify-lifecycle.sh
```

`Scripts/verify.sh` 使用当前 Command Line Tools 对 Core 与 SwiftUI/AppKit 层做类型检查，运行核心验收 runner，并生成 arm64 可执行文件。

`Scripts/build-app.sh` 进一步组装 `.build/CoolSkill.app`，生成 ICNS，修正 bundle 内动态库引用，并执行本地 ad-hoc 签名。

若本机已配置正式的 macOS 签名证书，可在构建时传入其身份；脚本默认仍使用 ad-hoc 签名：

```sh
COOLSKILL_SIGNING_IDENTITY='Developer ID Application: …' Scripts/build-app.sh
```

`Scripts/verify-lifecycle.sh` 验证启动时出现标准 CoolSkill 主窗口，并验证没有菜单栏状态项。

安装完整 Xcode 后还应运行：

```sh
swift test
swift build
```

本机当前没有完整 Xcode，因此 `xcodebuild` 与 XCTest 尚不是可运行验证门；对应测试源码已经保留。

## 隐私与边界

- CoolSkill 不修改任何 `SKILL.md`；
- 不读取或保存 Codex token、cookie 或私有账号分析；
- 使用统计只保存派生事件、计数和增量游标，不保存对话正文；
- V1 只写入 bundle identifier 为 `com.openai.codex` 的可写文本控件；
- 本地重建次数可能与 Codex 服务端统计存在少量差异。

产品规格与 tracer-bullet tickets 位于 `.scratch/coolskill/`。

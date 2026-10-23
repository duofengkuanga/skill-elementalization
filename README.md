# kcoisga

kcoisga 是一个 Apple Silicon/macOS 15+ 原生桌面 App。它只读取 `~/.agents/skills`，用本地中英文规则归入风、火、水、山，并提供 Codex 调用文本插入能力。

## 当前能力

- 仅扫描 `~/.agents/skills` 中的真实目录，忽略符号链接，不混入 `.codex` 或插件目录；
- 风火水山规则分类、右键人工归类和永久状态；元素图标支持右键拖动排序；
- 从 Codex 本地 rollout 重建显式、自动和子代理 Skill 使用；
- App 运行期间每 30 秒自动刷新使用次数和最近调用时间；手动“更新 Skills”会重扫目录并全量重建统计；
- Skill 列表显示累计次数、精确到秒的最近调用时间和只读“自动 / 手动”标记，并按最近调用时间降序排列；
- 参考 Ikaga 的双栏布局：文字导航侧栏和内嵌技能列表；启动显示“风 · 协作”，点击切换分类；
- 标准 macOS 窗口支持缩放、最小化和关闭；关闭主窗口即退出，不使用悬浮栏、贴边吸附或独立列表弹窗；
- 技能列表显示一句中文介绍；手动“更新 Skills”时，Codex 按 eli5 Skill 为新增或描述变化的技能生成介绍并在本机缓存；使用次数紧跟技能名称；
- 左栏底部为设置入口；主内容区与设置页均可更新 Skills；
- ⌘1–4 切换分类，方向键选择 Skill，Return 插入，⌘W 关闭窗口，⌘, 打开设置；
- 设置入口位于左栏底部：可控制登录启动、更新 Skills，并查看或请求辅助功能权限；
- 标准 macOS App 生命周期和 Dock 图标；不再创建或依赖菜单栏状态项；
- 几何小写 k 品牌图标，靛蓝与冷灰主题；分类使用统一线条图标和低饱和辅助色，支持浅深模式，界面无持续动画。

## 构建与验证

当前仓库支持两条验证路径：

```sh
Scripts/verify.sh
Scripts/build-app.sh
Scripts/verify-lifecycle.sh
```

`Scripts/verify.sh` 使用当前 Command Line Tools 对 Core 与 SwiftUI/AppKit 层做类型检查，运行核心验收 runner，并显式以 `arm64-apple-macosx15.0` 为目标生成可执行文件，避免最低系统版本随构建机器变化。

`Scripts/build-app.sh` 进一步组装 `.build/kcoisga.app`，生成 ICNS，修正 bundle 内动态库引用，并执行本地 ad-hoc 签名。

若本机已配置正式的 macOS 签名证书，可在构建时传入其身份；脚本默认仍使用 ad-hoc 签名：

```sh
COOLSKILL_SIGNING_IDENTITY='Developer ID Application: …' Scripts/build-app.sh
```

`Scripts/verify-lifecycle.sh` 验证标准可缩放窗口、普通窗口层级、无可见浮层，以及关闭窗口后进程退出。

`Scripts/render-previews.sh` 生成深浅色、最小尺寸、长文本和空分类预览，以及设置页的未授权、已授权、登录启动开启和失败提示状态。

安装完整 Xcode 后还应运行：

```sh
swift test
swift build
```

## 免费安装

发布流程将生成 `kcoisga-<version>-macos-arm64.zip`。解压后把 `kcoisga.app` 移到“应用程序”文件夹；首次打开时，macOS 可能要求在“隐私与安全性”中确认打开。当前免费构建未使用 Developer ID 签名，因此每次更新后可能需要重新授予辅助功能权限。

从 CoolSkill 0.6.x 升级请先退出旧版，再手动下载并打开 kcoisga.app；原有统计和人工分类会保留。

本机当前没有完整 Xcode，因此 `xcodebuild` 与 XCTest 尚不是可运行验证门；对应测试源码已经保留。

## 隐私与边界

- kcoisga 不修改任何 `SKILL.md`；
- 不读取或保存 Codex token、cookie 或私有账号分析；
- 使用统计只保存派生事件、计数和增量游标，不保存对话正文；
- V1 只写入 bundle identifier 为 `com.openai.codex` 的可写文本控件；
- 本地重建次数可能与 Codex 服务端统计存在少量差异。

产品规格与 tracer-bullet tickets 位于 `.scratch/coolskill/`。

## 中文介绍

首次使用或手动加入新 Skill 后，在设置中点击“更新 Skills”。kcoisga 读取各自的 `description`，通过本机 Codex CLI 按 `~/.agents/skills/eli5/SKILL.md` 的说明批量生成一句中文介绍，结果保存在本机状态文件中。描述未变化时复用缓存；生成失败时列表显示“待生成中文介绍”，设置页显示失败原因。此功能需要本机已登录 Codex CLI，并安装 eli5 Skill。

## 名称兼容

用户可见名称和构建产物为 kcoisga。内部 Swift 模块名、`com.coolskill.app` 标识和 `Library/Application Support/CoolSkill` 数据目录保留，以沿用既有统计、人工分类与系统授权，不进行数据迁移。

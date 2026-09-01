# 01 — 建立可运行的菜单栏 CoolSkill

**What to build:** 交付一个可启动的 Apple Silicon/macOS 15 原生 CoolSkill 壳。用户可以从菜单栏打开一个使用示例 Skill 的风火水山面板，并看到后续能力将复用的真实应用状态流。

**Blocked by:** None — can start immediately.

**Status:** done

- [x] 应用以菜单栏工具运行，默认不显示 Dock 图标。
- [x] 菜单栏左击显示原生操作菜单，其中“显示技能库”打开约 400 × 480 pt 的基础面板。
- [x] 面板用固定示例数据展示四元素导航和 Skill 行。
- [x] 建立可在无真实系统权限下运行的应用级测试 seam。
- [x] Swift Package 与手动工具链验证命令可重复运行；当前机器缺少完整 Xcode，使用 `Scripts/verify.sh` 作为可执行门。

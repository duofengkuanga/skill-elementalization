# 06 — 通过三键组合呼出并键盘操作面板

**What to build:** 用户可以用 `Command + D + P` 在任意时刻切换 CoolSkill，并可用键盘选择元素和 Skill；未形成完整组合时，原应用仍收到正常的 `Command + D`。

**Blocked by:** 05 — 把选中的 Skill 安全插入 Codex.

**Status:** done

- [x] 150ms 窗口内的 `Command + D + P` 被识别并吞掉。
- [x] 超时的单独 `Command + D` 被准确归还且不重复。
- [x] 快捷键监听器接受可替换配置；设置界面与持久化由 Ticket 08 接通。
- [x] 1–4、方向键、Return 和 Escape 的行为与 spec 一致。
- [x] 权限缺失时监听器保持可恢复状态且不影响菜单栏入口。

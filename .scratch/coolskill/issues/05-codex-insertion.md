# 05 — 把选中的 Skill 安全插入 Codex

**What to build:** 用户点击 Skill 后，CoolSkill 只在已验证的 Codex 输入框光标位置插入 `$skill-name `，保持现有草稿、选择和剪贴板不受破坏。

**Blocked by:** 02 — 从真实 Codex Skills 生成元素面板.

**Status:** done

- [x] 只接受可写的 Codex composer，其他应用和只读目标被拒绝。
- [x] 插入保留现有内容并智能处理光标前后空格。
- [x] 成功插入后临时面板关闭；Pinned 保持行为由 Ticket 07 接管。
- [x] 无目标、目标丢失或权限不足时面板保持并显示中文恢复提示。
- [x] 当前实现只使用 Accessibility 直接写入，不修改剪贴板；未启用粘贴回退。

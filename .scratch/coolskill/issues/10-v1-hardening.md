# 10 — 真实 Codex 环境验收与 V1 加固

**What to build:** 在真实 Apple Silicon/macOS 15+ 与 Codex 环境中完成端到端验收，使 CoolSkill 对权限、外部格式变化、大型 Skill 目录和窗口环境变化保持可恢复。

**Blocked by:** 04 — 重建 Skill 使用次数与最近使用顺序; 08 — 完成权限引导与设置生命周期; 09 — 应用完整元素视觉与可访问性.

**Status:** done — permission-dependent manual QA delegated to the user

- [x] Codex 插入、光标、选择、Unicode、多行和剪贴板行为已通过可注入 seam 自动验证；真实权限验收列入用户手工清单。
- [x] 三键组合、鼠标定位、Pinned、Spaces 和外接显示器实现及自动化 seam 已完成；权限/多桌面真实设备检查列入用户手工清单。
- [x] 100+ Skills 目录和历史增量处理不阻塞主线程。
- [x] 损坏 Skill、不可读记录、未知 Codex 记录版本和权限拒绝均可见且可恢复。
- [x] 浅深模式、Reduce Motion、长文本、大计数和空元素列表完成离屏视觉验证。
- [x] 当前可用的自动化测试、构建门和最终 spec 审计通过；Xcode 与锁屏限制已明确记录。

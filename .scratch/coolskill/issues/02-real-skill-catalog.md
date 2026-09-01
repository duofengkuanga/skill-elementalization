# 02 — 从真实 Codex Skills 生成元素面板

**What to build:** 用户点击更新后，CoolSkill 只从 `~/.agents/skills` 读取真实 Skills，解析名称和描述，并使用中英文规则将每项分配到风火水山。

**Blocked by:** 01 — 建立可运行的菜单栏 CoolSkill.

**Status:** done

- [x] 仅 shared agents 目录被发现；Codex、插件和项目目录被排除，空目录清空旧列表。
- [x] 缺失或损坏的元数据产生可见、可恢复的扫描结果，不导致崩溃。
- [x] 同名 Skill 只显示当前生效项，同时保留来源信息。
- [x] 分类覆盖四元素、短语优先、名称权重和低置信度风兜底。
- [x] 更新只由用户触发，不持续监听目录。

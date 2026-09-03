## Problem Statement

当前范围更新（2026-09-03）：Skill 来源仅为 `~/.agents/skills`；启动显示常规技能库窗口；技能库初始不展开元素或高亮列表行；Pin 按钮保留在左栏底部。全局快捷键及输入监听权限已移除；使用次数与最近调用时间每 30 秒自动刷新，手动更新目录时全量重建统计；Skill 行展示秒级最近调用时间和只读“允许自动调用”开关，并按最近调用时间排序；元素图标支持右键拖动排序。下方与这些决定冲突的历史故事不再属于当前交付范围。

Codex 用户可能安装几十个全局或插件 Skill，但现有调用方式要求用户记住名称、理解用途，并在对话框中手动输入准确的 `$skill-name`。当 Skill 数量增长后，用户难以快速发现、记忆和调用合适的 Skill，也缺少一个能反映实际使用习惯的稳定视觉入口。

用户需要一个轻量、原生、随时可呼出的 macOS 工具，将 Codex Skills 按直观的风、火、水、山元素体系组织起来。这个工具既要快速完成调用，也要允许用户形成空间记忆、修正自动分类，并看到每个 Skill 的累计使用次数。它不应修改 Skill 文件、误写其他应用、窃取 Codex 登录态，或为了统计功能依赖不公开的账号接口。

## Solution

CoolSkill 是一个面向 Apple Silicon、运行于 macOS 15 及以上版本的原生桌面应用。它只读取 `~/.agents/skills`，依据 Skill 的 `name` 与 `description` 使用中英文规则分类；启动后展示左侧元素导航与右侧 Skill 列表。

用户可以通过全局三键组合 `Command + D + P` 在鼠标附近呼出临时面板，悬停元素图标切换列表，点击 Skill 后将 `$skill-name ` 智能插入当前 Codex 输入框的光标位置。面板也可以被 Pin 为当前 Space 内的常驻、可调整大小窗口。

CoolSkill 从本机 Codex 任务记录重建 Skill 使用事件，涵盖显式调用、自动加载、主代理和子代理，并在 Skill 卡片上展示累计次数。该数据源尽量贴近 Codex 的调用统计语义，但不访问 Codex 未公开的账号分析接口，因此不承诺与账号侧统计完全一致。

## User Stories

1. As a user, I want the library to read only my shared agents Skills directory, so that its source is predictable.
2. As a user, I want Codex and plugin directories excluded from the catalog and displayed statistics, so that unrelated Skills do not appear.
3. As a Codex user, I want project-only Skills excluded from V1, so that I do not accidentally invoke a Skill that the current Codex task cannot resolve.
4. As a Codex user, I want duplicate Skill names resolved according to Codex precedence, so that I see only the Skill that will actually be invoked.
5. As a Codex user, I want every Skill assigned to exactly one element, so that the panel remains spatially clear.
6. As a Codex user, I want Skills classified by their primary intent, so that the elements communicate how a Skill helps rather than which technology it uses.
7. As a Codex user, I want action, connection, navigation, and automation Skills grouped under Wind, so that operational tools are easy to recognize.
8. As a Codex user, I want creation, generation, transformation, and expression Skills grouped under Fire, so that generative tools have a clear home.
9. As a Codex user, I want exploration, understanding, research, and diagnosis Skills grouped under Water, so that investigative tools are easy to find.
10. As a Codex user, I want constraint, verification, review, and protection Skills grouped under Mountain, so that quality and safety tools are visually distinct.
11. As a Chinese-speaking user, I want classification rules to understand Chinese and English names and descriptions, so that mixed-language Skill libraries classify consistently.
12. As a privacy-conscious user, I want classification to use deterministic rules rather than an AI service, so that no Skill content must be sent to a model.
13. As a Skill author, I want classification to prioritize `name` and `description`, so that procedural keywords in the full instructions do not distort the Skill's main intent.
14. As a user, I want an unrecognized Skill to fall back to Wind with a low-confidence marker, so that every Skill remains accessible without creating a fifth category.
15. As a user, I want to drag a Skill card onto another element icon, so that correcting an automatic classification feels direct.
16. As a user, I want a context-menu alternative for moving a Skill, so that classification can still be changed when drag-and-drop is inconvenient.
17. As a user, I want my manual element choice to remain permanent, so that future scans never undo my mental model.
18. As a user, I want automatically classified Skills to be reconsidered when their name or description changes, so that updated Skills remain accurately grouped.
19. As a user, I want CoolSkill to leave every `SKILL.md` untouched, so that plugin updates and third-party files are not polluted by local metadata.
20. As a user, I want to update the Skill catalog manually, so that the panel does not change unexpectedly while I am working.
21. As a user, I want catalog refresh in the menu-bar menu and Settings rather than the Skill library, so that management controls do not clutter invocation.
22. As a user, I want the launcher to contain no search field, so that it behaves as an elemental spatial panel rather than a command palette.
23. As a mouse-first user, I want four vertically arranged element icons on the left, so that I can move directly toward a visual category.
24. As a mouse-first user, I want hovering an element icon to switch the right-hand list, so that I do not need an extra click.
25. As a user, I want the list to remain visible while moving the pointer from the element icon to a Skill card, so that hover navigation is reliable.
26. As a user, I do not want element-click locking, so that the element rail remains a simple hover-driven control.
27. As a user, I want a newly opened transient library to start without selecting any element, so that no category opens on my behalf.
28. As a user, I want hovering an element to reveal its Skills without preselecting the first row, so that navigation stays mouse-first.
29. As a user, I want the main list to show only each Skill name and nonzero usage count, so that the launcher remains visually quiet and dense.
30. As a user, I want descriptions and secondary metadata removed from the resting list, so that unfamiliar details appear only when I deliberately hover.
31. As a user, I want a delayed hover detail to show the full description, source, element, and usage count, so that compact cards do not hide important context.
32. As a user, I want Skill cards ordered by most recent use within each element, so that my current workflow naturally rises to the top.
33. As a user, I want cumulative usage counts displayed on Skill cards, so that I can understand which Skills I rely on.
34. As a user, I want zero usage counts omitted, so that unused Skills do not add visual noise.
35. As a user, I want deleted Skill statistics retained, so that reinstalling the same invocation name restores its history.
36. As a user, I want a renamed Skill treated as a new Skill, so that unrelated capabilities are not merged accidentally.
37. As a user, I want historical usage reconstructed on first launch, so that the initial panel reflects my existing Codex habits.
38. As a user, I want explicit `$skill-name` invocations counted regardless of whether they were typed, pasted, or inserted by CoolSkill, so that statistics reflect actual submitted usage.
39. As a user, I want automatically triggered Skills counted when Codex actually loads their instructions, so that usage is not limited to explicit syntax.
40. As a user, I want Skill use by Codex subagents counted, so that delegated work is represented.
41. As a user, I want multiple pieces of evidence for the same activation deduplicated, so that an explicit invocation followed by instruction loading does not inflate the count.
42. As a user, I want usage processing to be incremental after the initial history scan, so that opening the panel stays fast.
43. As a user, I want an explicit rebuild action, so that I can recover statistics if Codex history changes or an adapter needs to be reapplied.
44. As a privacy-conscious user, I want CoolSkill to save only derived events and counts rather than conversation text, so that the app does not create another copy of my chats.
45. As a user, I want statistics to avoid Codex's private account analytics endpoint, so that CoolSkill does not need to steal or store Codex credentials.
46. As a user, I want the known difference between local reconstruction and Codex account analytics stated honestly, so that the displayed number is not presented as authoritative when it cannot be.
47. As a user, I want to invoke CoolSkill with `Command + D + P`, so that the shortcut matches my chosen muscle memory.
48. As a user, I want the three-key shortcut recognized within a short chord window, so that simultaneous physical key events are handled reliably.
49. As a user, I want a lone `Command + D` returned to the current application after the chord window, so that existing application shortcuts continue to work.
50. As a user, I want the shortcut configurable, so that I can change it if the small `Command + D` delay conflicts with my workflow.
51. As a keyboard user, I want number keys 1 through 4 to switch elements, so that I can navigate without the pointer.
52. As a keyboard user, I want arrow keys and Return to select and invoke a Skill, so that the panel remains efficient from the keyboard.
53. As a keyboard user, I want Escape or the global chord to close a transient panel, so that dismissal is predictable.
54. As a user, I want the transient panel to appear near the current pointer and avoid screen edges, so that mouse travel is minimized.
55. As a user, I want the transient panel to use a consistent compact size, so that its layout remains familiar.
56. As a user, I want clicking outside a transient panel to close it, so that it behaves like a launcher.
57. As a user, I want a successful invocation to close a transient panel, so that I immediately return to Codex.
58. As a user, I want an insertion failure to keep the panel open, so that I can focus the correct Codex input and retry.
59. As a user, I want to Pin the panel, so that I can invoke several Skills without repeatedly reopening it.
60. As a user, I want a Pinned panel to remain open after invocation, so that it functions as a persistent palette.
61. As a user, I want a Pinned panel to be movable and resizable, so that it can fit beside my Codex window.
62. As a user, I want Pinned size and position remembered during the current app session, so that temporary layout adjustments remain stable.
63. As a user, I do not want Pinned state restored after restarting CoolSkill, so that the app always starts unobtrusively.
64. As a user, I want a Pinned panel to remain in the Space where it was pinned, so that it does not follow me across desktops.
65. As a user, I want the shortcut to open an additional transient panel in another Space, so that I am not forcibly navigated back to the Pinned panel.
66. As a user, I want CoolSkill to restore a Pinned panel to a visible screen area when monitor geometry changes, so that the panel cannot become stranded off-screen during a session.
67. As a user, I want clicking a Skill to insert `$skill-name ` at the current Codex cursor position, so that I can compose a natural prompt around it.
68. As a user, I want insertion to preserve existing text and selection context, so that CoolSkill never destroys my draft.
69. As a user, I want surrounding whitespace normalized, so that inserted syntax does not create awkward duplicate spaces.
70. As a user, I want insertion restricted to Codex in V1, so that a focused text field in another application is never modified accidentally.
71. As a user, I want a clear error when no writable Codex input is focused, so that I know how to recover.
72. As a user, I do not want insertion failure to copy text silently to the clipboard, so that my clipboard remains predictable.
73. As a user, I want CoolSkill to preserve the previous clipboard contents when a platform fallback temporarily requires paste semantics, so that invocation does not damage unrelated clipboard work.
74. As a user, I want CoolSkill to avoid stealing Codex keyboard focus while I browse the panel, so that insertion returns to the original input location.
75. As a user, I want CoolSkill to live in the menu bar without a Dock icon, so that it behaves like a lightweight system utility.
76. As a user, I want a left click on the menu-bar icon to open a native macOS command menu, so that CoolSkill remains quiet until I choose an action.
77. As a user, I want the menu to expose Show Skill Library, Show Pinned, Update Skills, Settings, and Quit, so that management stays outside the library itself.
78. As a user, I want CoolSkill not to enable login launch without my choice, so that it does not modify startup behavior implicitly.
79. As a user, I want a progressive first-run permission guide, so that I understand why global keyboard monitoring and Accessibility access are needed.
80. As a user, I want to browse, classify, and view statistics even when permissions are missing, so that only the dependent capabilities are disabled.
81. As a user, I want CoolSkill to take me to the relevant system settings when a permission is missing, so that recovery is straightforward.
82. As a user, I do not want to review every automatic classification during onboarding, so that first launch remains short.
83. As a user, I want the interface to follow macOS light and dark appearance automatically, so that CoolSkill feels native.
84. As a user, I want custom elemental icons rather than mixed system symbols, so that the four categories share a coherent visual language.
85. As a user, I want icons rather than Chinese element characters in the sidebar, so that the panel feels compact and branded.
86. As a user, I want accessible names and tooltips for element icons, so that the absence of visible labels does not reduce accessibility.
87. As a user, I want restrained elemental transition animations, so that category changes feel distinctive without becoming distracting.
88. As a user with Reduce Motion enabled, I want all elemental motion replaced by fades, so that CoolSkill respects system accessibility preferences.
89. As a user of a Pinned panel, I want no continuous idle animation, so that the panel does not distract me or waste power.
90. As a user, I want the Skill library to contain no toolbar or resting management controls, so that only elemental navigation and Skills remain visible.
91. As a user, I want the library to consist solely of a narrow four-element rail and a flat Skill list, so that its purpose is immediately obvious.
92. As a Chinese-speaking user, I want the V1 interface and permission explanations in Chinese, so that the utility is immediately understandable.
93. As a Skill user, I want Skill names and descriptions left in their authored language, so that CoolSkill does not mistranslate technical meaning.
94. As a user, I want settings limited to launch behavior, shortcut, permissions, and data maintenance, so that V1 does not become a configuration product.
95. As a user, I want destructive local-data clearing to require confirmation, so that manual classifications and statistics are not erased accidentally.
96. As the initial owner, I want V1 optimized for personal local use, so that the core workflow can be validated before public distribution work begins.
97. As an Apple Silicon Mac user, I want a native Swift application, so that the menu-bar utility remains lightweight and visually consistent with macOS.
98. As a user, I want the CoolSkill app icon to express four elements converging at one center, so that the brand communicates organization through a single entry point.

## Implementation Decisions

- CoolSkill will target Apple Silicon Macs running macOS 15 or later. Intel support is intentionally excluded.
- The application will be implemented natively with Swift and SwiftUI. AppKit will provide platform-specific behavior that SwiftUI does not model well, including a nonactivating floating panel, menu-bar integration, window placement, Space behavior, global event monitoring, and Accessibility coordination.
- V1 is a menu-bar application and will not display a Dock icon by default.
- The top-level architecture will separate platform adapters from deterministic application logic. The principal responsibilities are a Skill catalog, classification engine, usage reconstructor, launcher state coordinator, Codex insertion adapter, global chord monitor, persistence store, and settings/permission coordinator.
- The Skill catalog discovers only the shared agents Skills directory, including intentionally linked Skill directories within it. Codex-global, plugin-cache, and project directories are not discovery roots. Empty scans clear the library rather than keeping stale items or fixtures.
- Catalog refresh is user-initiated. CoolSkill will perform an initial scan when required and a full rescan when the user activates Update; it will not watch Skill directories continuously.
- Duplicate invocation names will be resolved using the effective Codex precedence rather than displayed as separate choices. The resolved source remains available in hover details.
- A Skill's stable identity is its normalized invocation name. Removing a Skill hides it but retains local metadata; reinstalling the same name restores metadata. Renaming creates a new identity.
- Classification is deterministic and local. It does not use Apple Intelligence, a bundled language model, an OpenAI API key, or a cloud classification service.
- Each Skill has exactly one primary element. Wind represents action, connection, navigation, and automation. Fire represents creation, generation, transformation, and expression. Water represents exploration, understanding, research, and diagnosis. Mountain represents constraints, verification, review, and protection.
- Automatic classification uses `name` and `description` as primary signals. If those signals are insufficient, document headings may be used as weak signals. The full procedural body is not keyword-scored by default.
- The rule set supports Chinese and English phrases. Phrase-level matches outrank isolated words, and name matches carry more weight than description matches. A no-match result falls back to Wind and is marked low confidence.
- Manual element assignment is stored separately from Skill files, always outranks automatic classification, survives Skill content changes, and has no "restore automatic" action.
- Automatically assigned Skills are reclassified on a manual catalog refresh when their name or description has changed. Manually assigned Skills retain their element.
- The primary panel is 360 by 430 points, borderless with rounded corners. The four-element rail contains a Pin toggle at its bottom; the remaining area is a flat Skill list. There is no settings window, toolbar, or onboarding overlay.
- The left rail contains four custom icons with no visible text labels. Accessibility names and delayed tooltips identify Wind, Fire, Water, and Mountain.
- Hovering a rail icon switches the right-hand list without click locking. Pointer travel from rail to list preserves the active element. A new transient presentation begins with no element selected; the persisted legacy selection is ignored.
- Skill rows are flat and show only name plus a compact lifetime usage count when nonzero. Resting rows have no card fill; only hover and keyboard selection add a subtle background. A hover detail appearing after roughly 500 milliseconds shows full description, source, element, confidence, and count.
- Skills within an element are sorted by most recent successful observed use, newest first. Usage counts do not control launcher ordering.
- The transient panel opens near the current pointer, clamps itself to visible screen bounds, closes on outside click, Escape, repeat chord, or successful insertion, and remains open after a recoverable error.
- The Pinned panel is movable, resizable, and remains open after Skill insertion. It stays in the Space where it was pinned and does not join all Spaces. Pin state does not survive application restart.
- If a panel is Pinned in another Space, invoking the global chord opens a separate transient panel in the current Space rather than switching Spaces or moving the Pinned panel.
- A left click on the menu-bar icon opens a native `NSMenu`: Show Skill Library, Show Pinned, Update Skills, and Quit. The process uses an AppKit entry point and retains its delegate and status item. No startup window is created.
- The default global trigger is the simultaneous chord `Command + D + P`. The chord monitor buffers the initial `Command + D` for approximately 150 milliseconds. If `P` arrives during that window, the chord is consumed and CoolSkill toggles; otherwise the original `Command + D` is forwarded to the active application.
- The shortcut is configurable. Keyboard interaction additionally supports 1 through 4 for elements, Up and Down for row selection, Return for invocation, and Escape for dismissal.
- CoolSkill only inserts into a verified, writable Codex composer in V1. It will not insert into terminals, browsers, text editors, or arbitrary focused controls.
- Insertion targets the original Codex selection or cursor, preserves existing content, inserts `$skill-name` with context-aware spacing, and restores focus without overwriting unrelated text.
- The preferred insertion path uses the macOS Accessibility API. If a platform-specific paste fallback is required during implementation, it must restore the user's prior clipboard content and must still verify the Codex target before writing.
- If no writable Codex composer is available, the panel remains visible, presents a concise Chinese recovery message, and performs no clipboard mutation.
- CoolSkill usage is reconstructed from local Codex task records rather than from launcher clicks. Submitted explicit invocation syntax, observable Skill-instruction loads, main-agent activity, and subagent activity contribute usage events.
- Explicit syntax and instruction-loading evidence representing the same activation are deduplicated. CoolSkill stores only derived event identity, timestamps, counters, and incremental scan cursors; it does not persist conversation bodies.
- First-run statistics processing scans the available historical Codex task records. Later processing consumes only records after the saved cursor when the panel opens and when a Codex turn completion becomes observable, without high-frequency polling.
- The Update action performs a catalog refresh. A separate Rebuild Statistics action discards derived statistics after confirmation and reconstructs them from available Codex task history.
- Usage displayed by CoolSkill is a local reconstruction. It intentionally does not read Codex cookies, tokens, or private account analytics. The UI and documentation must not claim exact equality with Codex account-side `invocation_counts`.
- Persistent state includes resolved Skill identity, element assignment source, confidence, manual override, usage count, most recent use time, scan cursors, last-used element, current-session Pinned geometry, shortcut, launch-at-login preference, and permission state cache.
- Persistent metadata lives in CoolSkill's application data store and never modifies installed Skill files.
- The interface follows system light and dark appearance. Element colors use separate accessible variants: teal-green for Wind, vermilion-orange for Fire, blue for Water, and low-saturation rock-gold for Mountain.
- Element transitions last approximately 180 to 240 milliseconds: Wind sweeps laterally, Fire briefly brightens, Water ripples, and Mountain settles vertically. Reduce Motion replaces them with fades, and no element animates continuously while idle.
- The brand retains the quarter-arc silhouette of 🌈 but uses exactly four elemental bands, outside to inside: fire (#ff6b4a), mountain (#c4a36b), wind (#61d6bd), and water (#5c9eff). Vector sources generate the App ICNS and a color 18pt menu-bar image. Element navigation glyphs remain unchanged.
- The V1 interface language is Chinese. Skill names and descriptions remain in their original authored language.
- First-run onboarding explains keyboard monitoring and Accessibility separately, requests each permission only after a user action, offers launch-at-login without enabling it automatically, and does not require classification review.
- Missing permissions disable only the dependent behavior. Catalog browsing, element reassignment, and existing statistics remain available.
- Settings contain four areas only: General, Shortcut, Permissions, and Data. Clearing all local CoolSkill data is destructive and requires an explicit confirmation.
- V1 is intended for the owner's local machine. Signing, notarization, public installers, update delivery, release automation, and distribution support are deferred.

## Testing Decisions

- Tests will assert user-observable behavior and durable domain decisions rather than SwiftUI view hierarchy, private framework calls, or internal collection types.
- Because the repository contains no implementation or prior tests, there is no existing seam to reuse. The primary new seam will be an application-level workflow boundary that accepts catalog snapshots, classification inputs, usage records, focus/selection state, and user actions, then produces panel state, persistence changes, and insertion requests.
- The highest-value acceptance flow will cover: discover effective Skills, classify them, hover an element, select a Skill, validate a Codex target, insert invocation text, close or retain the panel according to mode, record observed usage, and reorder the relevant element by recency.
- Skill catalog tests will cover global and plugin discovery, project-scope exclusion, duplicate-name precedence, malformed or missing metadata, deleted and reinstalled Skills, renamed Skills, and manual refresh behavior.
- Classification tests will use table-driven Chinese and English examples for all four elements, phrase-over-word precedence, name-over-description weighting, weak heading fallback, low-confidence Wind fallback, automatic reclassification, and permanent manual override.
- Launcher state tests will cover first-launch Wind selection, last-used element restoration, hover transitions without click locking, keyboard element switching, row selection, transient dismissal, Pinned persistence within the current session, non-persistence across relaunch, and independent transient panels across Spaces.
- Chord-monitor tests will use a fake event clock and event sink to verify successful `Command + D + P` recognition, timeout forwarding of lone `Command + D`, repeat-chord dismissal, unrelated key passthrough, configurable shortcut behavior, and absence of duplicate forwarded events.
- Insertion tests will use a fake Codex Accessibility target to cover empty composers, mid-text cursors, selected text, existing whitespace, Unicode text, multiline drafts, lost focus, non-Codex targets, read-only targets, permission denial, and clipboard restoration if fallback paste is used.
- Usage reconstruction tests will use sanitized synthetic Codex records and cover explicit invocations, automatic instruction loads, explicit-plus-load deduplication, multiple distinct activations, subagent activity, malformed records, archived records, first-run history reconstruction, incremental cursors, rebuilding, deletion/reinstallation history, and rename isolation.
- Persistence tests will cover restart survival for manual elements, statistics, shortcut, launch preference, and last-used element; they will also verify that Pinned state is deliberately not restored.
- UI behavior tests will cover compact name/count rows, zero-count omission, long-name truncation, delayed details, recent-use ordering, context-menu reassignment, drag reassignment, light/dark appearance, and Reduce Motion fallback.
- Permission onboarding tests will verify progressive requests, clear explanations, correct disabled states, settings deep links, and continued browsing when permissions are absent.
- Platform integration testing will remain thin and focused: one macOS integration seam for event monitoring and one for Accessibility insertion. Pure domain behavior will not require real system permissions.
- A real-device manual acceptance pass on macOS 15 or later and Apple Silicon is required before declaring the insertion feature complete. It must validate Codex focus retention, cursor-accurate insertion, clipboard preservation, transient positioning near screen edges, Pinned Space behavior, and the 150-millisecond chord experience.
- Visual verification will compare the panel in system light and dark modes, at minimum and expanded Pinned sizes, with long names/descriptions, large usage counts, empty element lists, Reduce Motion enabled, and external-display geometry changes.
- Performance acceptance will verify that panel presentation and element hover feel immediate after the initial history scan, that incremental usage processing does not block the main thread, and that a catalog of at least one hundred Skills remains smoothly scrollable.
- Failure tests will ensure malformed Skill files, unreadable history records, changed Codex record formats, missing source paths, and denied permissions produce visible recoverable states rather than silent data loss or insertion into an unsafe target.

## Out of Scope

- Intel Mac support.
- macOS versions earlier than 15.
- Search, fuzzy matching, or command-palette behavior.
- Project-scoped Skills or automatic detection of the current Codex project.
- More than one primary element per Skill.
- A fifth unclassified element.
- AI-based classification, Apple Intelligence, bundled language models, or cloud classification.
- User-editable keyword rules.
- Restoring automatic classification after a manual element change.
- Continuous Skill-directory monitoring or automatic catalog refresh.
- Modifying or adding metadata to installed `SKILL.md` files.
- Writing to applications other than Codex.
- Exact equality with Codex account-side usage analytics.
- Reading Codex cookies, credentials, tokens, or private analytics endpoints.
- OpenAI sign-in inside CoolSkill.
- Cloud synchronization, team sharing, or cross-device statistics.
- Usage trend charts, daily/weekly dashboards, or a separate analytics screen.
- Persisting Pinned state across application launches.
- Pinned panels that follow all Spaces.
- Custom appearance themes beyond following the macOS system appearance.
- English UI localization in V1.
- Public distribution, Developer ID signing, notarization, release packaging, automatic updates, or App Store delivery.
- Production deployment or any external publication of this spec.

## Further Notes

- The product name is CoolSkill.
- The core product value is fast Skill invocation; elemental organization and usage statistics support that value rather than becoming separate products.
- The chosen no-search interaction depends on stable element semantics, strong visual differentiation, recent-use ordering, and dense name-only rows. Descriptions remain available on deliberate hover. If real-device testing shows excessive pointer or scrolling cost with large catalogs, the first response should be layout tuning rather than adding search without a new product decision.
- The `Command + D + P` chord is intentionally nonstandard. Its buffering delay and event forwarding must be validated early because failure here would affect unrelated macOS shortcuts.
- Codex Accessibility structure and local task-record formats are external dependencies that may change. Both require versioned adapters, observable failure states, and fixtures representing supported formats.
- The local usage number is best understood as CoolSkill's reconstructed lifetime invocation count. It should remain clearly distinguished from Codex's server-side analytics if both are ever shown in the future.
- V1 no longer promises that the application must operate offline, but it has no account or network dependency in the confirmed design. A future official Codex usage API may replace or supplement local reconstruction through a separately approved decision.

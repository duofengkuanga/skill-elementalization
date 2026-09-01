# CoolSkill V1 Completion Audit

## Current result

Current revision follows the 2026-08-31 feedback: a standard AppKit desktop window opens at startup, with no menu-bar status item; there is no settings/onboarding window, no initial element selection, a Pin-as-window-level toggle in the rail, and agents-only catalog scope. Permission-dependent runtime behavior remains user-owned manual QA; it is not claimed as fully validated.

## Evidence by requirement area

### Build and application shell

- `Scripts/verify.sh` type-checks Core and SwiftUI/AppKit with warnings as errors, builds arm64 executables, and runs Core plus AppModel verification runners.
- `Scripts/build-app.sh` produces `.build/CoolSkill.app`, an ICNS asset, bundle-relative Core library linkage, and an ad-hoc signature.
- `plutil`, `codesign --verify --deep --strict`, `otool`, and `file` checks pass.
- The bundled executable remains running without an immediate crash during a timed process smoke test.
- AppKit event-loop verification proves that a visible standard CoolSkill main window opens at launch. The installed 0.3.0 build was also opened and inspected through its accessibility tree: it displayed 34 agents-only Skills, the four icon-only element controls, the empty no-selection state, and the Wind list after selection.
- The prior macOS 26 menu-bar blocking issue is no longer in product scope: the app does not create `NSStatusItem` or depend on Control Center.

### Catalog and elemental classification

- The current agents-only catalog reports 34 effective Skills and zero parse issues. A fixture containing agents, Codex, and plugin roots verifies that only the agents Skill enters the catalog.
- Synthetic verification covers precedence deduplication, malformed frontmatter, Chinese/English classification, all four elements, and low-confidence Wind fallback.
- A 150-Skill synthetic catalog completes within the five-second acceptance ceiling.

### Persistence and usage reconstruction

- Verification covers manual overrides, selected-element persistence, shortcut/onboarding persistence, legacy-state migration, and corrupt-state recovery.
- The real active plus archived Codex history is approximately 1.7GB across 1019 rollout files.
- Historical benchmark before source narrowing: 710 derived events in about 27 seconds. This is not the current agents-only usage total.
- An unchanged incremental pass completes in approximately 0.033 seconds and returns zero duplicate events.
- Synthetic records cover explicit invocation, instruction loading, per-activation deduplication, incremental cursor continuation, and malformed relevant record reporting.

### Insertion, shortcut, and windows

- Pure insertion tests cover Chinese, UTF-16 emoji positions, selected-text preservation, middle-of-line insertion, and whitespace normalization.
- Accessibility code restricts targets to the `com.openai.codex` bundle, writable text controls, and settable selection ranges; failed selection writes attempt rollback.
- The chord recognizer covers trigger, timeout replay, unrelated-key flush, and symmetric D/P key-up suppression.
- Panel geometry verification covers edge clamping; implementation separates transient and Pinned panels and does not use all-Spaces behavior.
- Permission-independent real-window checks covered onboarding, element switching, update, Pin/unpin, Escape behavior, no-permission insertion feedback, and the accessibility tree. Permission-dependent behavior is delegated to the user checklist.

### UI and accessibility

- Current offscreen renders use the real 360 × 430 pt size for dark, light, no-selection, long-name/large-count stress, empty-element, and Reduce Motion configurations. Pin remains in the rail.
- Visual inspection caught and fixed onboarding background bleed, incorrect system-blue selection, and an ambiguous blank empty state. The final library removes its toolbar, resting descriptions, card fills, background gradient, and persistent management notices.
- SVG assets pass XML validation, and the generated 1024px icon plus ICNS were inspected.
- Computer Use verified the unlocked app's real settings and Skill library accessibility trees, including all four element buttons. Pointer hover, drag/drop, context menus, and permission-dependent paths remain in the user manual checklist.

## Verification constraints

- The machine has Apple Swift 5.8 Command Line Tools but no full Xcode. SwiftPM fails before compilation because `xcrun` cannot resolve an SDK PlatformPath. XCTest source files are present, but `swift test`, `swift build`, and `xcodebuild` cannot be claimed as passing here.
- `Scripts/verify.sh` is the authoritative local automated gate until full Xcode is installed.
- Computer Use verified the unlocked app's real windows. The user elected to complete system authorization manually.

## Git delivery

- The repository has no commits, is on `main`, and reports a missing upstream (`origin/main [gone]`).
- Per engineering guardrails, no Commit or Push is performed from this state without a safer branch/upstream decision.

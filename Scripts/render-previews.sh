#!/bin/zsh

set -euo pipefail

repo_root=${0:A:h:h}
manual_build="$repo_root/.build/manual"
preview_build="$repo_root/.build/previews"

"$repo_root/Scripts/verify.sh"
mkdir -p "$preview_build"

swiftc \
  -warnings-as-errors \
  -I "$manual_build" \
  -L "$manual_build" \
  -lCoolSkillCore \
  "$repo_root/Sources/CoolSkill/CodexAccessibilityInserter.swift" \
  "$repo_root/Sources/CoolSkill/CoolSkillModel.swift" \
  "$repo_root/Sources/CoolSkill/CoolSkillPanel.swift" \
  "$repo_root/Sources/CoolSkill/ElementVisuals.swift" \
  "$repo_root/Sources/CoolSkill/SystemLifecycle.swift" \
  "$repo_root/Verification/RenderPreview.swift" \
  -Xlinker -rpath \
  -Xlinker @executable_path/../manual \
  -o "$preview_build/render-preview"

"$preview_build/render-preview" "$preview_build/panel-dark.png" dark
"$preview_build/render-preview" "$preview_build/panel-light.png" light
"$preview_build/render-preview" "$preview_build/unselected-dark.png" unselected
"$preview_build/render-preview" "$preview_build/stress-dark.png" stress
"$preview_build/render-preview" "$preview_build/empty-dark.png" empty
"$preview_build/render-preview" "$preview_build/reduce-motion-dark.png" reduce-motion
"$preview_build/render-preview" "$preview_build/list-dark.png" list-dark
"$preview_build/render-preview" "$preview_build/list-light.png" list-light
"$preview_build/render-preview" "$preview_build/list-stress-dark.png" list-stress-dark

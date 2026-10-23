#!/bin/zsh

set -euo pipefail

repo_root=${0:A:h:h}
manual_build="$repo_root/.build/manual"
swift_target="arm64-apple-macosx15.0"

mkdir -p "$manual_build"

swiftc -target "$swift_target" -typecheck "$repo_root"/Sources/CoolSkillCore/*.swift
swiftc -target "$swift_target" \
  -emit-library \
  -emit-module \
  -parse-as-library \
  -module-name CoolSkillCore \
  "$repo_root"/Sources/CoolSkillCore/*.swift \
  -emit-module-path "$manual_build/CoolSkillCore.swiftmodule" \
  -o "$manual_build/libCoolSkillCore.dylib"
swiftc -target "$swift_target" \
  -typecheck \
  -I "$manual_build" \
  "$repo_root"/Sources/CoolSkill/*.swift
swiftc -target "$swift_target" \
  -I "$manual_build" \
  -L "$manual_build" \
  -lCoolSkillCore \
  "$repo_root"/Sources/CoolSkill/*.swift \
  -Xlinker -rpath \
  -Xlinker @executable_path \
  -o "$manual_build/kcoisga"
swiftc -target "$swift_target" \
  "$repo_root"/Sources/CoolSkillCore/*.swift \
  "$repo_root"/Verification/CoreVerification.swift \
  -o "$manual_build/core-verification"
swiftc -target "$swift_target" \
  -I "$manual_build" \
  -L "$manual_build" \
  -lCoolSkillCore \
  "$repo_root/Sources/CoolSkill/CodexAccessibilityInserter.swift" \
  "$repo_root/Sources/CoolSkill/CoolSkillModel.swift" \
  "$repo_root/Sources/CoolSkill/SkillSummaryGenerator.swift" \
  "$repo_root/Sources/CoolSkill/SystemLifecycle.swift" \
  "$repo_root/Verification/AppModelVerification.swift" \
  -Xlinker -rpath \
  -Xlinker @executable_path \
  -o "$manual_build/app-model-verification"

"$manual_build/core-verification"
"$manual_build/app-model-verification"

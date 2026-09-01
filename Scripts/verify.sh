#!/bin/zsh

set -euo pipefail

repo_root=${0:A:h:h}
manual_build="$repo_root/.build/manual"

mkdir -p "$manual_build"

swiftc -typecheck "$repo_root"/Sources/CoolSkillCore/*.swift
swiftc \
  -emit-library \
  -emit-module \
  -parse-as-library \
  -module-name CoolSkillCore \
  "$repo_root"/Sources/CoolSkillCore/*.swift \
  -emit-module-path "$manual_build/CoolSkillCore.swiftmodule" \
  -o "$manual_build/libCoolSkillCore.dylib"
swiftc \
  -typecheck \
  -I "$manual_build" \
  "$repo_root"/Sources/CoolSkill/*.swift
swiftc \
  -I "$manual_build" \
  -L "$manual_build" \
  -lCoolSkillCore \
  "$repo_root"/Sources/CoolSkill/*.swift \
  -Xlinker -rpath \
  -Xlinker @executable_path \
  -o "$manual_build/CoolSkill"
swiftc \
  "$repo_root"/Sources/CoolSkillCore/*.swift \
  "$repo_root"/Verification/CoreVerification.swift \
  -o "$manual_build/core-verification"
swiftc \
  -I "$manual_build" \
  -L "$manual_build" \
  -lCoolSkillCore \
  "$repo_root/Sources/CoolSkill/CodexAccessibilityInserter.swift" \
  "$repo_root/Sources/CoolSkill/CoolSkillModel.swift" \
  "$repo_root/Sources/CoolSkill/SystemLifecycle.swift" \
  "$repo_root/Verification/AppModelVerification.swift" \
  -Xlinker -rpath \
  -Xlinker @executable_path \
  -o "$manual_build/app-model-verification"

"$manual_build/core-verification"
"$manual_build/app-model-verification"

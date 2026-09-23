#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
manual_build="$repo_root/.build/manual"

"$repo_root/Scripts/verify.sh"
swiftc -warnings-as-errors -D COOLSKILL_LIFECYCLE_TEST \
  -I "$manual_build" -L "$manual_build" -lCoolSkillCore \
  "$repo_root"/Sources/CoolSkill/*.swift \
  "$repo_root/Verification/LifecycleVerification.swift" \
  -Xlinker -rpath -Xlinker @executable_path \
  -o "$manual_build/lifecycle-verification"
"$manual_build/lifecycle-verification"

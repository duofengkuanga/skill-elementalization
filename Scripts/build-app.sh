#!/bin/zsh

set -euo pipefail

repo_root=${0:A:h:h}
build_root="$repo_root/.build"
app_bundle="$build_root/CoolSkill.app"
contents="$app_bundle/Contents"
resources="$contents/Resources"
frameworks="$contents/Frameworks"
iconset="$build_root/CoolSkill.iconset"
master_icon="$build_root/CoolSkill-1024.png"
signing_identity=${COOLSKILL_SIGNING_IDENTITY:--}

"$repo_root/Scripts/verify.sh"

mkdir -p "$contents/MacOS" "$resources" "$frameworks" "$iconset"
install -m 755 "$build_root/manual/CoolSkill" "$contents/MacOS/CoolSkill"
install -m 755 "$build_root/manual/libCoolSkillCore.dylib" "$frameworks/libCoolSkillCore.dylib"
install -m 644 "$repo_root/BuildSupport/Info.plist" "$contents/Info.plist"
install -m 644 "$repo_root/Assets/CoolSkillIcon.svg" "$resources/CoolSkillIcon.svg"

sips -s format png "$repo_root/Assets/CoolSkillIcon.svg" --out "$master_icon" >/dev/null
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$master_icon" --out "$iconset/icon_${size}x${size}.png" >/dev/null
  doubled=$((size * 2))
  sips -z "$doubled" "$doubled" "$master_icon" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$resources/CoolSkill.icns"

linked_core=$(otool -L "$contents/MacOS/CoolSkill" | awk '/libCoolSkillCore\.dylib/{print $1; exit}')
install_name_tool \
  -change "$linked_core" @executable_path/../Frameworks/libCoolSkillCore.dylib \
  "$contents/MacOS/CoolSkill"
codesign --force --deep --sign "$signing_identity" "$app_bundle" >/dev/null
touch "$app_bundle"

printf '%s\n' "$app_bundle"

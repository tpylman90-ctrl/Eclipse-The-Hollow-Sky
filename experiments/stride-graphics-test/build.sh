#!/usr/bin/env bash
set -euo pipefail

# Official Stride sample, generated independently from the Godot project.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$ROOT/.generated"
NAME="StrideGraphicsTest"
mkdir -p "$OUT"
if [ -e "$OUT/$NAME" ]; then
  echo "Refusing to overwrite an existing generated sample: $OUT/$NAME" >&2
  exit 2
fi

dotnet new install Stride.Templates.Games.Starters@4.4.3
# --platforms consumes repeated values; keep it LAST so the dotnet template
# parser does not misinterpret other flags as additional platforms.
dotnet new stride-fps -n "$NAME" -o "$OUT/$NAME" \
  --graphicsProfile 10.0 --orientation LandscapeLeft --platforms android

# Prefer the standard .Android.csproj suffix from Stride; fail explicitly if
# future templates change their project naming instead of silently building nothing.
mapfile -d '' android_projects < <(find "$OUT/$NAME" -type f -name '*.Android.csproj' -print0)
if [ "${#android_projects[@]}" -ne 1 ]; then
  echo "Expected exactly one Stride Android project, found ${#android_projects[@]}:" >&2
  find "$OUT/$NAME" -name '*.csproj' -print >&2
  exit 3
fi

echo "Building Stride Android project: ${android_projects[0]}"
dotnet build "${android_projects[0]}" -c Debug \
  -p:AndroidPackageFormat=apk \
  --nologo

echo "Produced APK files:"
find "$OUT/$NAME" -type f -iname '*.apk' -print
if ! find "$OUT/$NAME" -type f -iname '*.apk' | grep -q .; then
  echo "No APK found after build" >&2
  exit 4
fi

mkdir -p "$OUT/artifacts"
find "$OUT/$NAME" -type f -iname '*.apk' -exec cp -v {} "$OUT/artifacts/" \;
# Preserve generated scene/projects, but exclude bulky build caches.
(
  cd "$OUT"
  zip -qr "artifacts/stride-source.zip" "$NAME" \
    -x '*/bin/*' '*/obj/*' '*/.vs/*' '*/.git/*'
)

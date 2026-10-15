#!/usr/bin/env bash
# Checks built release APKs for the two defects v0.2.0 shipped with, both
# invisible in a debug build: android.permission.INTERNET, which Flutter's
# template declares only in the debug and profile manifests (without it every
# socket fails with errno 1), and the MaterialIcons font, bundled only when
# pubspec.yaml says `uses-material-design: true` (without it every icon is an
# empty box).
#
# Usage: scripts/check-release-apk.sh APK [APK...]
# Finds aapt2 as $AAPT2, else the newest build-tools under ANDROID_HOME or
# ANDROID_SDK_ROOT. Exits 0 when every APK passes, 1 when any check failed,
# 2 with no argument or no aapt2.
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "usage: $0 APK [APK...]" >&2
  exit 2
fi

aapt2="${AAPT2:-}"
if [ -z "$aapt2" ]; then
  sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [ -n "$sdk" ]; then
    aapt2=$(printf '%s\n' "$sdk"/build-tools/*/aapt2 | sort -V | tail -n 1)
  fi
fi
if [ -z "$aapt2" ] || [ ! -x "$aapt2" ]; then
  echo "aapt2 not found: set AAPT2, or ANDROID_HOME or ANDROID_SDK_ROOT to an SDK with build-tools" >&2
  exit 2
fi

# Output captured before grepping: `grep -q` on a pipe closes it early, and
# under pipefail the writer's SIGPIPE would read as a failed check.
failed=0
for apk in "$@"; do
  perms=$("$aapt2" dump permissions "$apk" 2>/dev/null) || perms=''
  if ! grep -qxF "uses-permission: name='android.permission.INTERNET'" <<<"$perms"; then
    echo "$apk: missing android.permission.INTERNET" >&2
    failed=1
  fi
  listing=$(unzip -l "$apk" 2>/dev/null) || listing=''
  if ! grep -qF 'assets/flutter_assets/fonts/MaterialIcons-Regular.otf' <<<"$listing"; then
    echo "$apk: missing MaterialIcons font" >&2
    failed=1
  fi
done

if [ "$failed" -ne 0 ]; then
  exit 1
fi
echo "ok: $# APK(s)"

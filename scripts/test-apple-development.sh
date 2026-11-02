#!/bin/bash
# Local Apple Development signing experiment. No private keys or login codes are exported.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: run this script on your Mac" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IDENTITY="93A7B24B7972673159533F9B5B84DA46273806C8"
if [[ $# -ge 1 ]]; then
  IDENTITY="$1"
fi

echo "Checking local Apple Development identity..."
if ! security find-identity -v -p codesigning | grep -Fq "$IDENTITY"; then
  echo "error: signing identity unavailable: $IDENTITY" >&2
  echo "Sign in through Xcode > Settings > Accounts and check the certificate." >&2
  security find-identity -v -p codesigning >&2
  exit 1
fi

WORK="$(mktemp -d /tmp/smalltools-appledev.XXXXXXXX)"
trap 'rm -rf "$WORK"' EXIT

echo "Building unsigned Release binary locally..."
xcodebuild \
  -project "$ROOT/Macchiato.xcodeproj" \
  -scheme Macchiato \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$WORK/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  build

SOURCE="$WORK/DerivedData/Build/Products/Release/Macchiato.app"
[[ -d "$SOURCE" ]] || { echo "error: missing build output" >&2; exit 1; }

# Never replace an installed app or any existing build artifact.
OUT_DIR="$ROOT/dist/AppleDevelopmentLocal/$(date -u '+%Y%m%dT%H%M%SZ')-$$"
mkdir -p "$OUT_DIR"
APP="$OUT_DIR/小工具.app"
ditto "$SOURCE" "$APP"
HELPER="$APP/Contents/MacOS/app.macchiato.Macchiato.PowerHelper"
[[ -x "$HELPER" ]] || { echo "error: helper missing" >&2; exit 1; }
[[ -f "$APP/Contents/Library/LaunchDaemons/app.macchiato.Macchiato.PowerHelper.plist" ]] || {
  echo "error: launchd plist missing" >&2; exit 1;
}
if find "$APP/Contents/MacOS" -maxdepth 1 -name '*.debug.dylib' | grep -q .; then
  echo "error: Release build contains a debug dylib" >&2
  exit 1
fi

echo "Signing nested code, Power Helper and main App..."
for dylib in "$APP"/Contents/MacOS/*.dylib; do
  if [[ -f "$dylib" ]]; then
    codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$dylib"
  fi
done
# Apple's development certificate must be the leaf, not the trust root.
# Auto-generated DRs can incorrectly say 'certificate root = <leaf SHA-1>'.
# An explicit requirement also makes codesign --verify --strict meaningful.
APP_DR="=designated => identifier \"app.macchiato.Macchiato\" and anchor apple generic and certificate leaf = H\"$IDENTITY\""
HELPER_DR="=designated => identifier \"app.macchiato.Macchiato.PowerHelper\" and anchor apple generic and certificate leaf = H\"$IDENTITY\""
codesign --force --options runtime --timestamp=none \
  --identifier "app.macchiato.Macchiato.PowerHelper" \
  --requirements "$HELPER_DR" --sign "$IDENTITY" "$HELPER"
codesign --verify --strict --verbose=2 "$HELPER"
codesign --force --options runtime --timestamp=none \
  --identifier "app.macchiato.Macchiato" \
  --requirements "$APP_DR" --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign --verify --strict --verbose=2 "$HELPER"

for target in "$APP" "$HELPER"; do
  echo "Signature for: $target"
  info="$(codesign -dv --verbose=4 "$target" 2>&1)"
  printf '%s\n' "$info" | grep -E '^(Identifier|Authority|TeamIdentifier)=' || true
  if printf '%s\n' "$info" | grep -Fq 'TeamIdentifier=not set'; then
    echo "warning: TeamIdentifier is not set; this is not a codesign verification failure." >&2
    echo "warning: verify actual LaunchDaemon approval/startup on this Mac." >&2
  fi
done

echo
echo "SUCCESS: locally signed test App (NOT installed):"
echo "$APP"
echo
echo "Quit and back up the current app before manually installing this copy."
echo "Never run two copies with the same Bundle ID at the same time."

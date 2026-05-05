#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Autoclicker"
APP="$ROOT/$APP_NAME.app"

INSTALL=0
SIGN_IDENTITY="-"   # ad-hoc by default

for arg in "$@"; do
    case "$arg" in
        --install)
            INSTALL=1
            ;;
        --identity=*)
            SIGN_IDENTITY="${arg#--identity=}"
            ;;
        -h|--help)
            cat <<EOF
Usage: ./build.sh [options]

Builds Autoclicker.app at the project root.

Options:
  --install             Also copy the resulting bundle to /Applications.
  --identity=<name>     Codesign with the given Keychain identity instead of
                        ad-hoc. Use this with a self-signed certificate so that
                        Accessibility permission survives rebuilds.
                        Example: --identity="Autoclicker Self-Signed"
  -h, --help            Show this help.
EOF
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            exit 1
            ;;
    esac
done

if ! command -v xcrun >/dev/null 2>&1; then
    echo "ERROR: 'xcrun' not found. Install Xcode Command Line Tools:" >&2
    echo "       xcode-select --install" >&2
    exit 1
fi
if ! xcrun --find swift >/dev/null 2>&1; then
    echo "ERROR: Swift toolchain not found. Install Xcode Command Line Tools:" >&2
    echo "       xcode-select --install" >&2
    exit 1
fi

echo "==> Building $APP_NAME (release) ..."
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="$BIN_DIR/$APP_NAME"
if [[ ! -x "$BIN_PATH" ]]; then
    echo "ERROR: Built binary not found at $BIN_PATH" >&2
    exit 1
fi

echo "==> Assembling $APP ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Strip stray extended attributes that codesign refuses to sign over.
xattr -cr "$APP" 2>/dev/null || true

echo "==> Codesigning ($SIGN_IDENTITY) ..."
codesign --sign "$SIGN_IDENTITY" \
         --identifier com.user.autoclicker \
         --entitlements "$ROOT/Resources/entitlements.plist" \
         --options runtime \
         --force \
         --deep \
         --timestamp=none \
         "$APP"

if [[ $INSTALL -eq 1 ]]; then
    echo "==> Installing to /Applications ..."
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" "/Applications/$APP_NAME.app"
    echo "    Installed: /Applications/$APP_NAME.app"
fi

echo ""
echo "Build complete: $APP"
echo ""
echo "  Run with: open \"$APP\""
echo ""
echo "  First run: macOS will require Accessibility permission."
echo "  Grant in:  System Settings > Privacy & Security > Accessibility"
echo ""

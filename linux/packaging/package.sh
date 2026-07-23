#!/usr/bin/env bash
# Packages the Linux release bundle (flutter build linux --release) into a
# .deb and a .rpm using fpm. Run from the repository root:
#
#   flutter build linux --release
#   bash linux/packaging/package.sh
#
# Requires: fpm (gem install fpm), imagemagick (for icon resizing).
# Output: dist/premflix_<version>_amd64.deb, dist/premflix-<version>.x86_64.rpm

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

BUNDLE_DIR="build/linux/x64/release/bundle"
APP_NAME="premflix"
VERSION="${PKG_VERSION:-$(grep -E '^version:' pubspec.yaml | head -1 | sed -E 's/version:[[:space:]]*//; s/\+.*//')}"

if [ ! -d "$BUNDLE_DIR" ]; then
  echo "error: $BUNDLE_DIR not found — run 'flutter build linux --release' first" >&2
  exit 1
fi

STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT

# App payload under /opt, matching how most third-party Linux apps ship a
# bundled runtime rather than fighting distro dependency resolution.
INSTALL_DIR="$STAGE_DIR/opt/premflix"
mkdir -p "$INSTALL_DIR"
cp -r "$BUNDLE_DIR"/. "$INSTALL_DIR/"

# Desktop entry + icon, so the app appears in application launchers.
mkdir -p "$STAGE_DIR/usr/share/applications"
cp linux/packaging/premflix.desktop "$STAGE_DIR/usr/share/applications/premflix.desktop"

mkdir -p "$STAGE_DIR/usr/share/icons/hicolor/512x512/apps"
magick assets/logo.png -resize 512x512 \
  "$STAGE_DIR/usr/share/icons/hicolor/512x512/apps/premflix.png"

# Launcher shim on PATH.
mkdir -p "$STAGE_DIR/usr/bin"
cat > "$STAGE_DIR/usr/bin/premflix" <<'EOF'
#!/bin/sh
exec /opt/premflix/premflix "$@"
EOF
chmod +x "$STAGE_DIR/usr/bin/premflix"

mkdir -p dist

fpm -s dir -t deb \
  -n "$APP_NAME" -v "$VERSION" \
  --license "MIT" \
  --description "A beautiful, fast, cross-platform Jellyfin client" \
  --url "https://github.com/premflix/premflix" \
  --maintainer "PremFlix" \
  --category video \
  --depends libgtk-3-0 \
  --deb-no-default-config-files \
  -C "$STAGE_DIR" \
  -p "dist/${APP_NAME}_${VERSION}_amd64.deb" \
  .

fpm -s dir -t rpm \
  -n "$APP_NAME" -v "$VERSION" \
  --license "MIT" \
  --description "A beautiful, fast, cross-platform Jellyfin client" \
  --url "https://github.com/premflix/premflix" \
  --maintainer "PremFlix" \
  --category video \
  --depends gtk3 \
  -C "$STAGE_DIR" \
  -p "dist/${APP_NAME}-${VERSION}.x86_64.rpm" \
  .

ls -la dist

#!/bin/sh
set -uo pipefail

echo "[CI] post-clone started"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="${CI_WORKSPACE:-$(dirname -- "$SCRIPT_DIR")}"

# ── 1. XcodeGen ──────────────────────────────────────────────────────────────
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "[CI] Installing XcodeGen via Homebrew"
  brew install xcodegen
else
  echo "[CI] XcodeGen already available: $(xcodegen --version)"
fi

cd "$REPO_ROOT"

echo "[CI] Generating Ba6Ai.xcodeproj at repository root from ios/project.yml"
xcodegen generate --spec ios/project.yml --project .

echo "[CI] Generated project contents:"
ls -la Ba6Ai.xcodeproj/

# ── 2. Force-enable automatic SwiftPM resolution ─────────────────────────────
# Xcode Cloud disables automatic dependency resolution by writing
# IDEDisableAutomaticPackageResolution to the com.apple.dt.Xcode defaults
# domain on the build agent. With it disabled, Xcode insists on a
# pre-existing Package.resolved — which we can't commit because the
# .xcodeproj itself is generated.
#
# Override that default before resolving, and also drop a
# WorkspaceSettings.xcsettings with the same flag so the workspace
# itself agrees once the project opens.
echo "[CI] Overriding Xcode defaults to allow automatic package resolution"
defaults write com.apple.dt.Xcode IDEDisableAutomaticPackageResolution -bool NO    || true
defaults write com.apple.dt.Xcode IDEPackageOnlyUseVersionsFromResolvedFile -bool NO || true
defaults write com.apple.dt.Xcode IDEPackageSupportUseBuiltinSCM -bool YES         || true

WS_DIR="Ba6Ai.xcodeproj/project.xcworkspace/xcshareddata"
mkdir -p "$WS_DIR/swiftpm"
cat > "$WS_DIR/WorkspaceSettings.xcsettings" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>IDEDisableAutomaticPackageResolution</key>
    <false/>
    <key>IDEPackageOnlyUseVersionsFromResolvedFile</key>
    <false/>
</dict>
</plist>
PLIST

# ── 3. Resolve packages ──────────────────────────────────────────────────────
echo "[CI] Resolving SwiftPM dependencies"
RESOLVE_LOG="$REPO_ROOT/resolve.log"
set +e
xcodebuild \
  -resolvePackageDependencies \
  -project Ba6Ai.xcodeproj \
  -scheme Ba6Ai \
  -clonedSourcePackagesDirPath "$REPO_ROOT/SourcePackages" \
  > "$RESOLVE_LOG" 2>&1
RESOLVE_RC=$?
set -e

echo "[CI] xcodebuild resolve exit code: $RESOLVE_RC"
echo "[CI] ── resolve log (tail) ───────────────────────────────────────────"
tail -n 80 "$RESOLVE_LOG" || true
echo "[CI] ─────────────────────────────────────────────────────────────────"

RESOLVED="Ba6Ai.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [ -f "$RESOLVED" ]; then
  echo "[CI] Package.resolved present at $RESOLVED"
  echo "[CI] Contents:"
  cat "$RESOLVED"
else
  echo "[CI] ERROR: Package.resolved was not produced."
  echo "[CI] If the resolve log above complains about automatic resolution"
  echo "[CI] still being disabled, the workflow image may be enforcing it"
  echo "[CI] at a level we can't override — in that case commit a"
  echo "[CI] Package.resolved generated locally on your Mac."
  exit 1
fi

echo "[CI] post-clone finished"

#!/bin/sh
set -uo pipefail

# ─── Xcode Cloud: post-clone script (ios/ project root variant) ─────────────
# Used when the Xcode Cloud workflow points at ios/Ba6Ai.xcodeproj rather
# than the repo-root project. The repo-root variant lives in
# /ci_scripts/ci_post_clone.sh.
# ─────────────────────────────────────────────────────────────────────────────

echo "[CI] post-clone started (ios/ variant)"

REPO_ROOT="${CI_WORKSPACE:-.}"
IOS_DIR="$REPO_ROOT/ios"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "[CI] Installing XcodeGen via Homebrew"
  brew install xcodegen
else
  echo "[CI] XcodeGen already available: $(xcodegen --version)"
fi

echo "[CI] Generating Ba6Ai.xcodeproj"
cd "$IOS_DIR"
xcodegen generate --spec project.yml --project .

echo "[CI] Generated project:"
ls -la Ba6Ai.xcodeproj/

# Override Xcode Cloud's blanket disable of automatic package
# resolution. See /ci_scripts/ci_post_clone.sh for the full rationale.
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

echo "[CI] Resolving SwiftPM dependencies"
RESOLVE_LOG="$IOS_DIR/resolve.log"
set +e
xcodebuild \
  -resolvePackageDependencies \
  -project Ba6Ai.xcodeproj \
  -scheme Ba6Ai \
  -clonedSourcePackagesDirPath "$IOS_DIR/SourcePackages" \
  > "$RESOLVE_LOG" 2>&1
RESOLVE_RC=$?
set -e

echo "[CI] xcodebuild resolve exit code: $RESOLVE_RC"
echo "[CI] ── resolve log (tail) ───────────────────────────────────────────"
tail -n 80 "$RESOLVE_LOG" || true
echo "[CI] ─────────────────────────────────────────────────────────────────"

RESOLVED="Ba6Ai.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [ -f "$RESOLVED" ]; then
  echo "[CI] Package.resolved present"
  cat "$RESOLVED"
else
  echo "[CI] ERROR: Package.resolved was not produced."
  echo "[CI] Commit a Package.resolved generated locally if Xcode Cloud"
  echo "[CI] continues to refuse automatic resolution."
  exit 1
fi

echo "[CI] post-clone finished"

#!/bin/sh
set -euo pipefail

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

# Xcode Cloud disables automatic SwiftPM resolution and demands a
# pre-existing Package.resolved. Since the .xcodeproj is generated
# (not committed), resolve packages here so the file exists before
# the build phase starts.
echo "[CI] Resolving SwiftPM dependencies"
xcodebuild \
  -resolvePackageDependencies \
  -project Ba6Ai.xcodeproj \
  -scheme Ba6Ai \
  -clonedSourcePackagesDirPath "$IOS_DIR/SourcePackages"

RESOLVED="Ba6Ai.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [ -f "$RESOLVED" ]; then
  echo "[CI] Package.resolved created at $RESOLVED"
else
  echo "[CI] WARNING: Package.resolved was not produced — build will likely fail"
fi

echo "[CI] iOS deployment target: $(grep 'IPHONEOS_DEPLOYMENT_TARGET' Ba6Ai.xcodeproj/project.pbxproj | head -1 | tr -d ' ;')"

echo "[CI] post-clone finished"

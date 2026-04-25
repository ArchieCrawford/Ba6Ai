#!/bin/sh
set -euo pipefail

echo "[CI] post-clone started"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="${CI_WORKSPACE:-$(dirname -- "$SCRIPT_DIR")}"

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

# Xcode Cloud disables automatic SwiftPM resolution — it expects a
# Package.resolved already on disk. Since we generate the .xcodeproj at
# build time (no .xcodeproj is committed), we also have to resolve the
# packages at build time. This produces:
#   Ba6Ai.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
#
# Without this step the build fails with:
#   "a resolved file is required when automatic dependency resolution
#    is disabled"
echo "[CI] Resolving SwiftPM dependencies"
xcodebuild \
  -resolvePackageDependencies \
  -project Ba6Ai.xcodeproj \
  -scheme Ba6Ai \
  -clonedSourcePackagesDirPath "$REPO_ROOT/SourcePackages"

RESOLVED="Ba6Ai.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [ -f "$RESOLVED" ]; then
  echo "[CI] Package.resolved created at $RESOLVED"
else
  echo "[CI] WARNING: Package.resolved was not produced — build will likely fail"
fi

echo "[CI] post-clone finished"

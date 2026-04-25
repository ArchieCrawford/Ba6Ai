#!/bin/sh
set -euo pipefail

# ─── Xcode Cloud: post-clone script ─────────────────────────────────────────
# Runs after the repo is cloned but before Xcode Cloud resolves packages or
# builds. Its job is to generate Ba6Ai.xcodeproj from project.yml via
# XcodeGen. SPM packages declared in project.yml are resolved automatically
# by Xcode Cloud after this script exits.
# ─────────────────────────────────────────────────────────────────────────────

echo "[CI] post-clone started"

# CI_WORKSPACE is set by Xcode Cloud to the root of the cloned repo.
REPO_ROOT="${CI_WORKSPACE:-.}"
IOS_DIR="$REPO_ROOT/ios"

# ── 1. Install XcodeGen ───────────────────────────────────────────────────────
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "[CI] Installing XcodeGen via Homebrew"
  brew install xcodegen
else
  echo "[CI] XcodeGen already available: $(xcodegen --version)"
fi

# ── 2. Generate .xcodeproj ───────────────────────────────────────────────────
echo "[CI] Generating Ba6Ai.xcodeproj"
cd "$IOS_DIR"
xcodegen generate --spec project.yml --project .

echo "[CI] Generated project:"
ls -la Ba6Ai.xcodeproj/

# ── 3. Verify deployment target matches Xcode Cloud image ────────────────────
# project.yml targets iOS 26 (beta). Ensure the image supports it; if not,
# update the workflow in App Store Connect to use a Xcode 26 beta image.
echo "[CI] iOS deployment target: $(grep 'IPHONEOS_DEPLOYMENT_TARGET' Ba6Ai.xcodeproj/project.pbxproj | head -1 | tr -d ' ;')"

echo "[CI] post-clone finished"

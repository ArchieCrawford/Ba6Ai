#!/bin/sh
set -euo pipefail

echo "[CI] post-clone started"

REPO_ROOT="${CI_WORKSPACE:-$(pwd)}"

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

echo "[CI] post-clone finished"
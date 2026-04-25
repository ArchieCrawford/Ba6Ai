#!/bin/sh
set -euo pipefail

echo "[CI] Xcode Cloud post-clone started"

# Print versions for easier debugging in build logs
xcodebuild -version || true
ruby -v || true
pod --version || true
node --version || true
npm --version || true
yarn --version || true

# If you need a specific Node version, you can install it here via Homebrew or your preferred tool.
# Be mindful that installing during CI can slow builds; prefer using the Xcode Cloud image default when possible.
# Example (commented out):
# brew update && brew install node@18
# echo 'export PATH="/opt/homebrew/opt/node@18/bin:$PATH"' >> "$HOME/.zprofile"
# export PATH="/opt/homebrew/opt/node@18/bin:$PATH"

# Install JS dependencies
if [ -f package-lock.json ]; then
  echo "[CI] Installing JS dependencies with npm ci"
  npm ci
elif [ -f yarn.lock ]; then
  echo "[CI] Installing JS dependencies with yarn --frozen-lockfile"
  yarn install --frozen-lockfile
elif [ -f package.json ]; then
  echo "[CI] Installing JS dependencies with npm install"
  npm install
else
  echo "[CI] No package.json found, skipping JS dependency install"
fi

# Install iOS dependencies via CocoaPods (if ios directory exists)
if [ -d ios ]; then
  echo "[CI] Installing CocoaPods in ios/"
  cd ios

  if [ -f Gemfile ] && command -v bundle >/dev/null 2>&1; then
    echo "[CI] Using Bundler for CocoaPods"
    bundle install
    bundle exec pod install
  else
    echo "[CI] Using system CocoaPods"
    pod install
  fi

  cd - >/dev/null 2>&1
else
  echo "[CI] No ios directory found, skipping CocoaPods"
fi

echo "[CI] Xcode Cloud post-clone finished"

#!/bin/bash
set -euo pipefail

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Installing pods..."
pod install

echo "==> Done! Open WeChatSwift.xcworkspace"

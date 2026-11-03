#!/bin/bash
# Build and install capsled to ~/bin/capsled (macOS only).
set -e
cd "$(dirname "$0")"
xcode-select -p >/dev/null 2>&1 || { echo "Installing Xcode Command Line Tools first..."; xcode-select --install; exit 1; }
mkdir -p ~/bin
clang -O2 -framework IOKit -framework CoreFoundation capsled.c -o ~/bin/capsled
echo "Installed ~/bin/capsled. Testing 3 blinks on any connected keyboard..."
CAPSLED_DEBUG=1 ~/bin/capsled 3 "${1:-}" 0

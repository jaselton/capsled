#!/bin/bash
# Build capsled on macOS and install capsled + capsled-alert into ~/bin.
set -e
cd "$(dirname "$0")"
mkdir -p "$HOME/bin"
cp capsled-alert "$HOME/bin/capsled-alert"
chmod 755 "$HOME/bin/capsled-alert"
if [ "$(uname -s)" != "Darwin" ]; then
  echo "Installed $HOME/bin/capsled-alert."
  echo "The capsled binary is built on macOS (it needs IOKit)."
  exit 0
fi
xcode-select -p >/dev/null 2>&1 || { echo "Install the Xcode Command Line Tools first: xcode-select --install"; exit 1; }
clang -O2 -framework IOKit -framework CoreFoundation capsled.c -o "$HOME/bin/capsled"
chmod 755 "$HOME/bin/capsled"
echo "Installed $HOME/bin/capsled and $HOME/bin/capsled-alert."
echo "Testing 3 blinks..."
CAPSLED_DEBUG=1 "$HOME/bin/capsled" 3 "${1:-}" 0

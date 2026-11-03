# capsled

Blinks the Caps Lock light on a Mac keyboard (tested on a Logitech MX Keys Mac over Bluetooth, macOS 26) without turning Caps Lock on. My Grok Bots use it to get my attention when a card is waiting for my tap.

## Install on a Mac

```
gh repo clone jaselton/capsled ~/capsled && ~/capsled/install.sh "MX Keys"
```

Needs the Xcode Command Line Tools (`xcode-select --install`). The first run may ask for Input Monitoring permission in System Settings > Privacy & Security.

## Use

```
~/bin/capsled [blinks=5] [keyboard name filter] [final state 0|1]
~/bin/capsled 5 "MX Keys"        # blink the MX Keys 5 times
~/bin/capsled 0 "MX Keys" 0      # force the light off
CAPSLED_DEBUG=1 ~/bin/capsled 3  # show which keyboards it reached
```

It writes the HID Caps Lock LED element (usage page 0x08, usage 0x02) through IOHIDManager, so the real Caps Lock state is untouched. Leave the filter off to blink every keyboard, including a MacBook's built-in one.

## Windows

Not supported yet. A Windows version would need its own approach (Logitech's software or a HID library).

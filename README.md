# capsled

Blinks the Caps Lock light on a Mac keyboard without turning Caps Lock on. Tested with a Logitech MX Keys Mac keyboard. Use a short one-shot blink, or a durable blink that keeps going until you stop it.

This writes the Caps Lock LED only. It does not turn Caps Lock itself on or off.

## Install on a Mac

Install the Xcode Command Line Tools first (`xcode-select --install`). The first time the light is changed, macOS may ask for Input Monitoring permission under System Settings > Privacy & Security.

```
gh repo clone jaselton/capsled ~/capsled && ~/capsled/install.sh "MX Keys"
```

That builds `~/bin/capsled` and installs `~/bin/capsled-alert` beside it. The install blinks three times so you can see that it works. The optional argument is a keyboard name; leave it off to blink every attached keyboard during that test.

## One-shot blink

```
~/bin/capsled [blinks=5] [keyboard name filter] [final state 0|1]
~/bin/capsled 5 "MX Keys"        # blink the MX Keys 5 times
~/bin/capsled 0 "MX Keys" 0      # force the light off
CAPSLED_DEBUG=1 ~/bin/capsled 3  # show which keyboards it reached
```

It writes the HID Caps Lock LED element (usage page 0x08, usage 0x02) through IOHIDManager. Leave the filter off to blink every keyboard, including a MacBook's built-in one.

## Durable blink

`capsled-alert` keeps blinking until you stop it. Each pass runs `capsled` for 3 blinks, waits 4 seconds, and repeats while that alert is still on.

```
~/bin/capsled-alert start              # blink until stop (tag: default)
~/bin/capsled-alert status
~/bin/capsled-alert stop

~/bin/capsled-alert start oven         # a named alert
~/bin/capsled-alert stop oven          # stop only oven
~/bin/capsled-alert stop               # stop every alert
```

Starting a tag that is already running refreshes it and does not start a second copy. Tags are separate: stopping one leaves the others running. The light is turned off only when no alert is still running.

The keyboard defaults to `MX Keys`. A forgotten alert stops itself after 12 hours. Set either limit when you start it:

```
CAPSLED_KB="MX Keys" CAPSLED_MAX_HOURS=12 ~/bin/capsled-alert start
```

`CAPSLED_MAX_HOURS` is a whole number of hours. Alert state is stored under `~/.capsled-alert/`.

## Bots

Nothing here starts or stops the light on its own. After a bot shows a question card, have it run:

```
~/bin/capsled-alert start question
```

When that question is answered, have it run:

```
~/bin/capsled-alert stop question
```

Use a tag for that question. Stopping it does not clear other tags.

## Windows

Not supported yet. A Windows version would need its own approach (Logitech's software or a HID library).

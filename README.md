# ClickGuard

A lightweight macOS menu bar app that fixes the common **double-click problem** found in Logitech mice (and other mice with worn switches), where a single physical click registers as two.

## Download

Grab the latest **ClickGuard.dmg** from the [Releases page](https://github.com/officenotfound/Clickguard/releases/latest), open it, and drag ClickGuard to your Applications folder.

> This build is ad-hoc signed. On first launch, right-click the app and choose **Open** to get past the Gatekeeper warning, then grant Accessibility access when prompted.

## The Logitech double-click problem

If your Logitech mouse has started registering double-clicks when you only clicked once — dragging files you meant to select, opening things twice, breaking text selection — you're hitting one of the most widely reported issues in modern mice.

**What's actually happening:** Logitech mice use mechanical micro-switches (typically Omron) under each button. Every click is a tiny metal contact physically closing a circuit. Over tens of thousands of clicks, those contacts wear down — they oxidize and the actuation spring loses tension. When the contact is no longer clean, a single press makes the circuit "bounce": it opens and closes several times in a few milliseconds, and the mouse reports it as **two or more separate clicks**. This is known as **switch bounce**.

A few things make it worse on Logitech hardware specifically:

- It usually appears first on the **left button**, because that's the most-used switch and wears fastest.
- Many recent models ship with cheaper Omron **D2F-C** switches (often China-made) that are widely reported to fail sooner than the older Japanese-made switches.
- Logitech exposes a firmware **debounce** setting on some gaming models (**G502, G Pro Wireless, G403, G703**) — but **not** on popular productivity mice like the **MX Master** and **MX Anywhere**, leaving no built-in fix.

Affected models include the **G502 / G502 Lightspeed**, **G Pro Wireless**, **G403**, **G703**, **MX Master** series, **MX Anywhere**, and many others — but the same wear-and-bounce failure happens to almost any aging mouse.

## How ClickGuard fixes it

ClickGuard installs a low-level mouse event tap and applies **software debouncing**: when a second click arrives on the same button faster than a human possibly could (within a configurable threshold, default **50 ms**), it's recognized as bounce and silently discarded. Your intentional clicks pass through untouched; the phantom second click never reaches your apps.

This means you keep using the mouse you have. It's the same principle behind Logitech's own firmware debounce, brought to **every** mouse and every button at the OS level — including the MX Master models that have no built-in setting.

If a click is being filtered that you actually meant, just lower the threshold. If phantom clicks still slip through, raise it. Most worn switches settle out somewhere between 40–90 ms.

> **Note:** This is a software workaround that masks the symptom and extends the usable life of the mouse. The underlying switch will keep degrading; the only *permanent* hardware fix is to replace the micro-switches (e.g. desolder and swap in Kailh GM 8.0 or fresh Omron switches), or replace the mouse. ClickGuard buys you time — often a lot of it.

## Features

- **Double-click filtering** — configurable bounce threshold (default 50 ms), per-button (left, right, middle). Suppresses the bounced click *and* its orphaned release so apps never see a stray event.
- **Scroll wheel fix** — suppresses spurious reverse-direction scroll jitter on both vertical and horizontal wheels, while leaving intentional fast scrolling untouched. Off by default.
- **Drag & drop fix** *(experimental)* — absorbs momentary glitch-releases during a drag so a faulty switch can't drop the item you're moving. Off by default.
- **Live activity log** — shows exactly which clicks, scrolls, and drags were filtered, in real time.
- **Launch at login**
- Tiny footprint — runs entirely in your menu bar, no dock icon

### How each fix works

- **Click debounce:** when a button is pressed again sooner than a human realistically could after releasing it (under the threshold), the press is treated as switch bounce and discarded.
- **Scroll fix:** the app tracks the last scroll direction per axis; a scroll tick that reverses direction within the threshold window is treated as jitter and dropped.
- **Drag fix:** once you've held a button and moved past a few pixels, ClickGuard briefly delays the button release. If a fresh press arrives during that window, it was a glitch — the release is cancelled and the drag continues uninterrupted.

## Requirements

- macOS 13 (Ventura) or later
- Apple Silicon or Intel

## Build from source

```bash
bash build-app.sh
cp -r ClickGuard.app /Applications/
open /Applications/ClickGuard.app
```

Grant Accessibility access when prompted in **System Settings → Privacy & Security → Accessibility**.

To package a distributable disk image:

```bash
bash make-dmg.sh   # produces ClickGuard.dmg
```

## License

MIT

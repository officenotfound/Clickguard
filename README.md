# ClickGuard

A lightweight macOS menu bar app that prevents accidental double-clicks caused by aging or faulty mouse hardware.

## How it works

ClickGuard installs a low-level event tap and suppresses any mouse button click that arrives faster than a configurable threshold on the same button. Clicks within that window are treated as hardware bounce and silently discarded.

## Features

- Configurable threshold (default 50ms)
- Per-button filtering — left, right, and middle
- Live activity log showing filtered clicks
- Launch at login
- Tiny footprint — runs entirely in your menu bar

## Requirements

- macOS 13 or later
- Apple Silicon or Intel

## Build & install

```bash
bash build-app.sh
cp -r ClickGuard.app /Applications/
open /Applications/ClickGuard.app
```

Grant Accessibility access when prompted in System Settings → Privacy & Security → Accessibility.

## License

MIT

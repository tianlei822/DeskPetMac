# DeskPetMac

可互动的 macOS 桌面宠物。它会悬浮在桌面上，点击会回应，根据本地天气切换动画，养成与你的羁绊，在你离开时打盹，还能在连续工作后提醒你站立休息。

Interactive macOS desktop pet. It floats on the desktop, reacts to clicks, changes animation based on local weather, grows a bond with you, naps when you step away, and reminds you to stand after focused work.

## Features

- Transparent floating pet window, draggable by background.
- Click-to-pat interaction with lively bobbing, blinking, tail wagging, and weather accessories.
- **Pat combos** — rapid taps build a multiplier, shown as a `×N combo!` badge.
- **Floating heart particles** burst out when you pat or make the pet dance.
- **Bond / affection system** — pats and play grow affection through five levels (New Friend → Soulmate), with hearts and a progress bar in the status bubble. Bond, pet choice, and reminder interval all persist across launches.
- **Dance action** — tap the ♪ button (or `Cmd+D`) and the pet wiggles, tilts, and earns affection.
- **Sleep mode** — when you go idle for a while the pet closes its eyes and drifts off with floating `z`s, then wakes the moment you interact.
- Local weather via CoreLocation + Open-Meteo. If permission or network fails, it falls back to a cozy neutral state.
- Weather moods: sunny, cloudy, foggy, rainy, snowy, stormy, cozy.
- Active-work tracking based on local idle time.
- Stand reminder bubble, macOS notification, `Done` and `10m` snooze actions.
- Popover setting for reminder interval, from 20 to 90 minutes.

## Shortcuts

- `Cmd+P` pat · `Cmd+D` dance · `Cmd+B` take break · `Cmd+R` refresh weather · `Cmd+1`/`Cmd+2` switch pet · `Cmd+Q` quit.

## Run

```bash
cd /Users/tianlei/Documents/codex/DeskPetMac
scripts/run-app.sh
```

The script builds and opens:

```text
.build/release/DeskPetMac.app
```

第一次运行时，macOS 可能会请求位置和通知权限。

On first launch, macOS may ask for location and notification permissions.

## Verify

```bash
swift test
swift build
scripts/package-app.sh
```

## Release

Package a distributable DMG locally:

```bash
scripts/make-dmg.sh 0.1.0   # -> dist/DeskPetMac-0.1.0.dmg
```

Or let CI do it: pushing a `v*` tag runs `.github/workflows/release.yml`, which
tests, builds the DMG, and publishes a GitHub Release with the DMG attached.

```bash
git tag v0.1.1
git push origin v0.1.1
```

# DeskPetMac

可互动的 macOS 桌面宠物。它会悬浮在桌面上，点击会回应，根据本地天气切换动画，养成与你的羁绊，在你离开时打盹，还能在连续工作后提醒你站立休息。

Interactive macOS desktop pet. It floats on the desktop, reacts to clicks, changes animation based on local weather, grows a bond with you, naps when you step away, and reminds you to stand after focused work.

## Features

- Transparent floating pet window, draggable by background.
- **Multi-display continuity / 多显示器连续性** — each display keeps its own safe normalized position; resizing or disconnecting a display preserves the companion’s relative placement and migrates older screen-number preferences automatically.
- **Context-aware autonomy / 情境自主行为** — energy, curiosity, social need, local time, weather, bond, and your current focus streak influence whether each pet explores, self-grooms, watches the weather, seeks attention, rests, or stretches with you.
- **Character motion / 角色动作** — Cat, Pauli, and Dog use one canonical layered rig for locomotion, autonomous idle gestures, direct-touch weight shifts, and remembered-preference body language, with grounded feet, safe interruption, and escalating pat-combo bracing; topology-changing poses keep explicit artwork fallbacks.
- **Staged attention / 分阶段注意力** — when the pointer approaches, the eyes react first, ears or sensors orient next, then the head and body follow at character-specific tempos; crossing into the pet window continues the same response instead of restarting it.
- **Natural wake-up / 自然苏醒** — returning after idle triggers a quiet, bubble-free stretch and orient sequence; direct interaction interrupts it immediately, while Reduce Motion uses one short orienting pose.
- **Observation-driven weather / 实况天气** — real precipitation, cloud cover, humidity, visibility, wind, gusts, and day/night observations drive layered clouds, fog, rain, snow, moonlight, splashes, wet reflections, and storm illumination.
- **Treat interaction / 投喂互动** — use the gift control or `Cmd+T` for a complete toss, watch, approach, sniff, eat, and satisfied response instead of an instant particle effect.
- **Spatial touch / 空间触摸** — pat the head, boop a nose or sensor, hold for a nuzzle, make a natural back-and-forth scratch near an ear or chin, or quickly swipe to ruffle the pet in that direction; responses also reflect touch position/speed, interrupted activity, stormy mood, familiarity, bond, and character voice.
- **Relationship memory / 关系记忆** — each companion remembers its own nickname, bond, preferred interactions, familiar hours, recent moments, and time apart; those memories shape autonomous behavior, tiered welcome rituals, and distinct invite-touch, lean-close, shared-sway, or anticipate-play body language.
- **Optional interaction feedback / 可选互动反馈** — character-specific short sounds and system-respecting trackpad taps are off by default and always suppressed by Quiet Mode.
- **System accessibility / 系统辅助功能** — Reduce Motion and Increase Contrast are honored automatically; higher contrast strengthens bubble borders, supporting text, reminder buttons, and menu selection without relying on color alone.
- **Pat combos** — rapid taps build from a soft bounce into a 5+ hit starburst celebration, with a longer-lived `×N` badge.
- **Floating heart particles** burst out when you pat or make the pet dance.
- **Bond / affection system** — pats and play grow affection through five levels (New Friend → Soulmate), with hearts and a progress bar in the status bubble. Bond, pet choice, and reminder interval all persist across launches.
- **Dance action** — tap the ♪ button (or `Cmd+D`) and the pet wiggles, tilts, and earns affection.
- **Personality moments / 个性时刻** — every so often the pet quietly shares a short, contextual thought without stealing focus or sending a notification.
- Three distinct companions: a mischievous realistic Cat, curious PBR robot Pauli, and enthusiastic realistic Dog.
- Choose Cat, Pauli, or Dog from the picker or with `Cmd+1`, `Cmd+2`, and `Cmd+3`.
- **Distinct voices / 鲜明个性** — Cat is lazy and mischievous, Pauli is earnest and curious, and Dog is enthusiastic and loyal.
- **Sleep mode** — when you go idle for a while the pet closes its eyes and drifts off with floating `z`s, then wakes the moment you interact.
- Local weather via CoreLocation + Open-Meteo. If permission or network fails, it falls back to a cozy neutral state.
- Weather moods: sunny, cloudy, foggy, rainy, snowy, stormy, cozy.
- Active-work tracking based on local idle time.
- Stand reminder bubble, macOS notification, `Done` and `10m` snooze actions.
- Popover setting for reminder interval, from 20 to 90 minutes.

## Shortcuts

- `Cmd+P` pat · `Cmd+D` dance · `Cmd+T` treat · `Cmd+B` take break · `Cmd+R` refresh weather · `Cmd+1`/`Cmd+2`/`Cmd+3` switch pet · `Cmd+Q` quit.

## Run

```bash
cd /Users/tianlei/Documents/codex/DeskPetMac
scripts/run-app.sh
```

The script builds and opens:

```text
.build/release/DeskPetMac.app
```

The transparent desktop window uses a compact `260 x 290` canvas so weather can render behind and in front of the pet.

第一次运行时，macOS 可能会请求位置和通知权限。

On first launch, macOS may ask for location and notification permissions.

## Verify

```bash
swift test
scripts/verify-visual-baselines.sh
swift build
scripts/package-app.sh
```

当且仅当视觉变化已经人工审定、需要接受当前渲染结果时，显式更新紧凑视觉基线：

```bash
scripts/update-visual-baselines.sh --accept-current-rendering
```

Only update the compact visual baseline after intentionally reviewing and accepting the current rendering.

Preview a motion event in a debug build:

```bash
DESKPET_MOTION_PREVIEW=walk swift run DeskPetMac
```

Supported values: `walk`, `idleAction1`, `idleAction2`, `lookAround`, `stretch`, and `perkUp`.

Preview a weather mood in a debug build:

```bash
DESKPET_WEATHER_PREVIEW=rainy swift run DeskPetMac
```

Supported preview values: `sunny`, `cloudy`, `foggy`, `rainy`, `snowy`, `stormy`, and `cozy`.

Export the six representative side-mounted speech layouts for visual review:

```bash
scripts/export-side-bubble-snapshots.sh
```

Export the staged stretch-then-prompt break ritual for all three companions:

```bash
scripts/export-break-ritual-snapshots.sh
```

Export standard/increased contrast previews for personality, reminder, status, and menu surfaces:

```bash
scripts/export-accessibility-contrast-snapshots.sh
```

Export first-meeting, welcome-back, and long-reunion rituals for all three companions:

```bash
scripts/export-greeting-ritual-snapshots.sh
```

Export sleep, wake-stretch, and wake-orient sequences for all three companions:

```bash
scripts/export-wake-ritual-snapshots.sh
```

Export the longest contextual touch callouts for all three companions:

```bash
scripts/export-touch-callout-snapshots.sh
```

Export eye-lead, head-follow, and settled attention stages for all three companions:

```bash
scripts/export-attention-response-snapshots.sh
```

Export enter/hold/settle stages for all four remembered-preference gestures:

```bash
scripts/export-relationship-gesture-snapshots.sh
```

Export all 36 root-motion transition clip frames for visual review:

```bash
scripts/export-transition-clip-snapshots.sh
```

Export the canonical pat/combo/scratch/swipe rig sequence for all three companions:

```bash
scripts/export-direct-touch-rig-snapshots.sh
```

## Release

Package a distributable DMG locally:

```bash
scripts/make-dmg.sh 0.1.0   # -> dist/DeskPetMac-0.1.0.dmg
```

Or let CI do it: pushing a `v*` tag runs `.github/workflows/release.yml`, which
tests, verifies the visual baseline, builds the DMG, and publishes a GitHub Release with the DMG attached.

```bash
git tag v0.1.1
git push origin v0.1.1
```

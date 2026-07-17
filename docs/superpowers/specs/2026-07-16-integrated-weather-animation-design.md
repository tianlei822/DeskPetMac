# Integrated Weather Animation Design

**Date:** 2026-07-16
**Status:** Approved and implemented
**Scope:** DeskPetMac weather presentation for Cat, Pauli, and Dog

## Goal

Replace weather text and floating weather-badge presentation with subtle, continuous weather animation integrated around and into the pet. The weather must remain recognizable without obscuring the realistic artwork or competing with interactions.

## Product Decisions

- Use subtle, continuous weather motion.
- Remove weather descriptions, location, and temperature from the upper status bubble.
- Keep focus progress, bond information, weather refresh, and the cozy fallback.
- Use common environmental effects with small character-specific reactions.
- Do not generate additional weather-specific pet raster assets.
- Preserve the current `220 x 250` window size.

## Architecture

Weather continues to flow from Open-Meteo through `PetViewModel.mood`. Presentation splits into three coordinated layers:

```text
Open-Meteo -> PetViewModel.mood
                         |-> WeatherBackdrop
                         |-> pet-specific weather reaction
                         `-> WeatherForeground
```

`WeatherBackdrop` renders light, shadow, distant rain or snow, and storm dimming behind the pet. `WeatherForeground` renders nearby precipitation, fog, and ground ripples above the pet. Both remain non-interactive.

`RealisticPetBody` and `VectorPetBody` receive `PetWeatherMood`. Their weather reaction is lower priority than sleeping, personality poses, pat response, hover, and dance. Weather must not replace the selected artwork pose or recolor the full realistic image.

## Weather Behavior

Weather changes cross-fade over approximately 0.6 seconds.

### Sunny

- A low-opacity warm halo breathes behind the pet.
- A restrained warm rim light touches the artwork edge.
- Cat settles into a relaxed, slightly narrowed expression through gentle scale and tilt.
- Pauli's antenna/status light gains a warm glow.
- Dog occasionally lifts its posture slightly.

### Cloudy

- A soft translucent cloud shadow crosses the pet every 10-16 seconds.
- Idle motion amplitude becomes slightly quieter for all pets.
- The artwork retains its canonical color.

### Foggy

- Two low fog bands drift near the feet at different speeds.
- Fog never covers the face.
- Cat makes a small observing tilt, Pauli's status light becomes clearer, and Dog makes a restrained side-to-side look.

### Rainy

- Fine rain is split between background and foreground layers.
- A small low-opacity ripple occasionally appears near the feet.
- Cat slightly contracts its posture.
- Pauli receives a cool visor reflection.
- Dog performs one small shake every 12-20 seconds.

### Snowy

- Snowflakes of two sizes fall at different speeds in front of and behind the pet.
- A faint cool ground glow appears near the feet.
- Cat motion slows, Pauli's light shifts cooler, and Dog occasionally lifts its nose.

### Stormy

- The local pet area is gently dimmed.
- A short, low-opacity flash occurs every 16-28 seconds; repeated strobing is prohibited.
- Cat makes one brief startle tilt, Pauli's antenna brightens with the flash, and Dog briefly becomes alert before returning to idle.
- Lightning and startle displacement are disabled when Reduce Motion is enabled.

### Cozy

- A small warm local halo and slow breathing remain.
- No precipitation is rendered.
- This is the fallback when location or weather retrieval fails.

## Motion and Rendering Constraints

- Use deterministic particle placement so particles do not jump between frames.
- Keep foreground and background weather to approximately 12-16 rendered particles total.
- Run continuous atmosphere at no more than the existing 24 fps weather cadence.
- Restrict effects to the pet window and primarily to the area around the pet.
- Avoid full-image recoloring, face obstruction, sustained flashing, and large continuous displacement.
- Weather layers must use `allowsHitTesting(false)` and must not interfere with hover, pat, controls, popovers, bubbles, or window dragging.
- Existing realistic artwork loading, downsampling, and bounded caching remain unchanged.

## Reduce Motion

With Reduce Motion enabled:

- Disable moving rain, snow, fog, cloud shadows, character weather displacement, and lightning flashes.
- Keep only static low-opacity atmosphere, such as a warm halo, dim storm tint, sparse rain/snow marks, or a still fog band.
- Preserve blink and other existing subtle state feedback already allowed by the application.

## UI Changes

- Remove the legacy `MoodAccessory` weather badge.
- Remove mood description, location, and temperature from `StatusBubble`.
- Keep the pet name, focus progress, and bond readout in the status bubble.
- Keep the weather refresh control. A successful refresh transitions directly into the new atmosphere without showing weather text.
- Keep reminder bubbles, personality bubbles, heart particles, combo badge, and control-strip layering unchanged.

## Code Boundaries

- Add `Sources/DeskPetMac/WeatherAtmosphere.swift` for backdrop, foreground, deterministic particle layout, and shared weather visual configuration.
- Update `Sources/DeskPetMac/RealisticPetBody.swift` to accept `PetWeatherMood` and apply low-priority character reactions and artwork-local lighting.
- Update `Sources/DeskPetMac/PetWindowView.swift` to place weather layers around the pet, simplify `StatusBubble`, remove `MoodAccessory`, and pass mood into both realistic and vector rendering.
- Add core-testable weather presentation configuration only if it can remain free of SwiftUI/AppKit types; otherwise verify visual configuration through focused source and runtime checks.
- Update `README.md` to describe integrated animated weather instead of weather accessories/text.

## Error Handling

- Failed location or weather retrieval continues to map to `.cozy`.
- Weather animation must never block pet rendering.
- Missing realistic artwork continues to use the vector fallback with the same weather mood.
- An unknown future weather code continues to use `.cozy` until explicitly mapped.

## Verification

- Verify all seven `PetWeatherMood` cases are handled exhaustively.
- Add unit coverage for any extracted core weather-presentation mapping.
- Run `swift test` and `swift build -c release`.
- Run `scripts/package-app.sh`, verify all 27 pet PNGs remain packaged, and run strict deep codesign verification.
- Inspect Cat, Pauli, and Dog under all seven weather moods in the real `220 x 250` window.
- Confirm weather remains recognizable, faces and controls are unobstructed, silhouettes are not cropped, and no new color fringe appears.
- Confirm sleep, pat, hover, dance, personality poses, weather refresh, bubbles, and vector fallback retain their existing priority and behavior.
- Confirm Reduce Motion removes continuous weather movement and lightning.

## Out of Scope

- New weather-specific pet raster images.
- Full-window desktop weather effects outside DeskPetMac.
- Additional weather providers or forecast views.
- Changes to location permission, refresh cadence, bond progression, personality scheduling, or reminder behavior.

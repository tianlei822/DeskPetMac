# Rich Pet Motion and Realistic Weather Design

**Date:** 2026-07-16
**Status:** Approved
**Scope:** DeskPetMac Cat, Pauli, and Dog motion plus weather presentation

## Goal

Make the desktop pets feel alive between interactions and make every weather mood read as a real atmospheric condition rather than a simple overlay. Pets should occasionally perform short, convincing walk cycles and character-specific idle actions. Weather should gain depth, environmental lighting, and ground feedback without obscuring the pet or becoming visually noisy.

## Approved Product Decisions

- Pets walk occasionally rather than continuously.
- Each walk lasts 2–4 steps and returns naturally to idle.
- Cat, Pauli, and Dog use distinct motion vocabularies.
- Add real gait artwork instead of simulating leg motion by transforming a single image.
- Use a hybrid renderer: raster gait frames for the pets and procedural SwiftUI Canvas effects for weather.
- Weather intensity is medium: clearly recognizable and more cinematic than the current version, but still suitable for an always-on desktop companion.
- Expand the transparent window from `220 x 250` to approximately `260 x 290` so weather has room for depth.
- Keep controls compact and preserve click, hover, drag, shortcut, reminder, bond, and personality behavior.
- Do not add sound, browser components, downloaded runtime animation, or weather-specific full-pet raster sets.

## Motion Experience

### Scheduling

A pure `PetMotionDirector` derives the current low-priority motion state from time, pet kind, and a stable schedule seed. A normal idle window lasts approximately 12–30 seconds before a short motion event. The director chooses either a 2–4 step walk or a character-specific micro-action, then returns to idle.

The schedule must be stable across SwiftUI body updates. Re-rendering the view cannot restart a walk, change the selected action, or jump to another frame.

### Motion Priority

From highest to lowest priority:

1. Sleep
2. Pat response
3. Dance
4. Personality pose
5. Hover and pointer tracking
6. Strong weather reaction
7. Short walk or character micro-action
8. Breathing, gaze, and ordinary idle motion

Starting a higher-priority state immediately suppresses the walk or micro-action. Returning to idle starts from a stable neutral pose instead of resuming midway through an interrupted step.

### Character Motion Vocabulary

#### Cat

- Light, quiet steps with restrained vertical movement.
- Weight shift before the first step and a soft tail counter-swing.
- Character idle actions: paw grooming and alert ear/head tracking.
- Stops with a small settling motion rather than an abrupt freeze.

#### Pauli

- Precise mechanical steps with alternating foot contact.
- Small torso stabilization and counter-rotation during each step.
- Character idle actions: environmental scan and antenna calibration.
- Stops with a short posture correction.

#### Dog

- Energetic steps with a forward body bias.
- Head, tail, and shoulder motion follow the gait rather than moving as one rigid image.
- Character idle actions: head tilt and raised-paw anticipation.
- Stops with a friendly weight shift and tail finish.

### Motion Artwork

Each pet receives:

- Six transparent gait frames: `walk1` through `walk6`.
- Two character-specific idle-action frames: `idleAction1` and `idleAction2`.

All frames must preserve the approved identity, camera angle, scale, lighting direction, transparent background, and contact point of the current base artwork. The current base image is the visual reference for every generated frame.

Expected additional packaged size is approximately 20–30 MB.

### Gait Rendering

The gait loop uses discrete artwork frames with short, non-blurred transitions. Body translation, scale, tilt, and contact shadow are synchronized with the frame phase:

- Horizontal displacement remains subtle so the pet appears to take steps in place rather than slide across the desktop.
- Vertical movement is driven by foot contact and is lower than the current generic bob.
- The contact shadow narrows, widens, and shifts with weight transfer.
- Frame timing can vary slightly by pet while remaining within a natural 6–10 FPS gait cadence.

## Realistic Weather Experience

Weather renders in three coordinated layers inside the expanded transparent window.

### 1. Background Atmosphere

This layer establishes depth and overall weather identity behind the pet:

- Soft cloud masses and cloud shadows.
- Volumetric fog bands at multiple depths.
- Sunlight beams, warm air light, and subtle dust motes.
- Storm dimming and broad cloud illumination.

Background elements use different speeds, blur radii, scales, and opacity to create parallax. Weather transitions crossfade over approximately 0.8 seconds.

### 2. Artwork-Local Lighting

Lighting is masked to the pet artwork so it changes the perceived environment without recoloring the entire image:

- Sunny: warm rim light and slowly shifting soft illumination.
- Cloudy: cooler contrast and moving soft shadow.
- Foggy: reduced lower-body contrast and diffused light.
- Rainy: cool reflections and a restrained wet sheen near the lower body.
- Snowy: cool top light and pale ground bounce.
- Stormy: dim ambient light with brief broad illumination during lightning.
- Cozy: warm radial light and stable contact warmth.

Lighting must preserve fur, eye, plastic, and metal material detail. No green fringe or full-artwork color wash is allowed.

### 3. Foreground and Ground Feedback

#### Rain

- Three perceived depth bands with different drop lengths, opacity, blur, and speed.
- A consistent wind direction with limited natural variation.
- Near-ground splashes and expanding ripples around the pet’s feet.
- Cool reflected light and subtle wet-ground sheen.

#### Snow

- Different flake sizes, focus levels, drift amounts, and fall speeds.
- Slow foreground flakes and smaller background flakes establish depth.
- A pale accumulated-light cue near the ground, without drawing a literal snow platform.

#### Fog

- At least two noise-shaped, horizontally drifting bands at different depths.
- Foreground fog occasionally crosses the lower legs while leaving the face readable.
- Fog cannot look like a fixed capsule or ordinary contact shadow.

#### Storm

- Rain plus a darker atmospheric layer.
- Lightning is a short, broad environmental flash with an optional procedural branch near the window edge.
- Remove the `bolt.fill` symbol.
- Flashes are rare and use a soft two-stage envelope rather than a single hard blink.

#### Cloudy

- Use soft, irregular cloud masses and moving shadows.
- Remove the `cloud.fill` symbol.

#### Sunny and Cozy

- Sunny adds warm directional light, faint rays, and a small number of illuminated dust motes.
- Cozy uses softer warm ambient light and slower motes so it remains visibly distinct from sunny.

### Weather Intensity and Readability

The selected medium intensity must be recognizable without weather text on both light and dark desktop backgrounds. Faces, eyes, controls, status information, personality bubbles, reminders, and heart particles remain readable.

The strongest weather uses at most approximately 32–40 Canvas particles across all depth layers and renders at no more than 30 FPS.

## Architecture

### DeskPetCore

#### `PetMotionDirector.swift`

Contains pure, testable motion scheduling:

- `PetMotionState`
- stable idle duration selection
- event selection
- step count and frame phase
- per-pet cadence
- priority eligibility rules that do not depend on SwiftUI

#### `PetArtworkManifest.swift`

Extends the manifest with the complete gait and idle-action resource names. It exposes an all-or-nothing gait availability contract so callers never alternate between present and missing gait frames.

#### `WeatherSceneProfile.swift`

Defines deterministic weather budgets and visual parameters:

- particle counts per depth layer
- wind, speed, blur, and opacity ranges
- ground-feedback availability
- lightning timing
- transition duration
- Reduce Motion behavior

### DeskPetMac

#### `RealisticPetBody.swift`

Composes the selected artwork frame, synchronized transforms, contact shadow, local weather lighting, and interaction priority. It does not own random scheduling.

#### `WeatherParticleField.swift`

Draws deterministic Canvas particle fields for rain, snow, dust, and ground feedback. A stable seed produces repeatable positions without allocating random values each frame.

#### `WeatherAtmosphere.swift`

Coordinates background and foreground weather layers, crossfades between moods, clips to the expanded scene, and remains non-interactive.

#### `PetWeatherLighting.swift`

Owns artwork-masked lighting and Pauli-specific accent effects.

#### `PetWindowView.swift`

Expands the window composition to approximately `260 x 290`, preserves the compact control strip, and provides the current mood and priority gates to motion and weather renderers.

## Asset Loading and Failure Handling

- Preload the selected pet’s gait and idle-action frames when that pet becomes active.
- Use a cache with a bounded memory cost rather than the current six-image count limit.
- Decode at the existing 512-pixel thumbnail ceiling unless visual QA proves it insufficient.
- If any gait frame is missing or fails to decode, disable the entire gait sequence for that pet and stay on realistic idle artwork.
- If base realistic artwork is unavailable, use the existing vector pet fallback.
- Missing weather resources cannot break the app because the enhanced weather remains code-rendered.
- Debug preview and packaged-app notification behavior retain the existing safe bundle guard.

## Reduce Motion

When macOS Reduce Motion is enabled:

- Do not play gait loops, repeated micro-actions, precipitation, fog drift, cloud drift, moving light, ground ripples, or lightning.
- Keep one static, low-opacity cue for the current weather.
- Preserve static character identity and permitted state feedback such as a direct pat pose.
- Avoid continuous transform changes in both realistic and vector fallbacks.

## Accessibility and Interaction

- Weather remains excluded from the accessibility tree and disables hit testing.
- Expanded transparent regions do not create unexpected interactive blockers.
- The pet button retains its existing accessible label and shortcuts.
- The control strip remains keyboard accessible and visually separated from weather effects.
- Pat, hover, window drag, reminder, settings, and quit behavior remain unchanged.

## Testing and Verification

### Automated Tests

- Motion schedules stay within the 12–30 second idle interval.
- Walks contain 2–4 steps and valid gait-frame indices.
- Each pet receives distinct cadence and event mappings.
- Higher-priority states suppress and reset low-priority motion.
- Gait manifests are exhaustive and detect partial availability.
- Weather particle generation is deterministic for a fixed seed and time.
- Particle budgets remain within the approved maximum.
- Only applicable weather creates splashes, accumulation light, or lightning.
- Reduce Motion returns static motion and weather states.
- Base-artwork and partial-gait fallback rules remain valid.

### Real-Window QA

- Observe each pet for at least three minutes and confirm multiple natural motion events without repetitive looping or frame jumps.
- Inspect Cat, Pauli, and Dog in all seven weather moods.
- Repeat key weather checks on both light and dark desktop backgrounds.
- Verify rain, snow, and fog do not block pat or hover.
- Verify walk interruption by pat, dance, personality, hover, and sleep.
- Verify missing gait-frame and missing base-artwork fallbacks.
- Verify Reduce Motion with rainy, snowy, foggy, and stormy moods.
- Confirm no clipping inside the expanded `260 x 290` window and no green fringe or full-artwork recoloring.

### Release Verification

- Run the complete test suite.
- Build the Release product.
- Package and ad-hoc sign the app.
- Count and validate all original and new pet assets in the packaged resource bundle.
- Run strict signature verification.
- Restart the packaged local app and confirm the final window.

## Out of Scope

- Sound effects or ambient weather audio.
- True movement across the desktop or autonomous window repositioning.
- Physics-based fur or cloth simulation.
- 3D skeletal models or a game engine dependency.
- Runtime-downloaded animation or weather assets.
- Forecast UI, provider changes, or additional weather data.
- Browser-based companions or controls.

## Success Criteria

The feature is successful when each pet visibly performs convincing short walks and distinct idle actions, all seven weather moods are recognizable as atmospheric scenes rather than icons or flat overlays, interaction priority remains reliable, the expanded window stays unobtrusive, and automated plus real-window verification passes without increasing animation instability or resource-loading failures.

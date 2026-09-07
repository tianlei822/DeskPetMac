# Continuous character rendering — 2026-09-07

猫狗保留写实素材；Pauli 改为 CyboPal 六轴机械臂屏幕机器人的紧凑形象。
Cat and Dog retain realistic artwork; Pauli becomes a compact CyboPal arm-and-screen robot.

## Changes

- `RealisticPetBody` routes the live character into `PetContinuousArtwork`. Explicit artwork overrides remain available for inspecting legacy assets.
- Animal movement uses a single inverse deformation field. There are no cut-out limbs, body-image swaps, or detached tail layers in the live renderer. Fur and silhouettes retain the source image. Head orientation, weight shift, eyelids, and paws vary continuously.
- A critically damped presentation controller retains position and velocity when targets change. Feeding and stroke responses enter the same controller instead of transforming the whole pet window.
- Pauli has six serial rotation axes and rigid links, with a stationary base. Motion is projected into Canvas; this is a stylized robot rendering, not a CAD replica. The reference is the [official CyboPal ONE product imagery](https://cybopal.com/), specifically its silver articulated arm, landscape display, and companion display on the base.
- Pauli explores with an in-place observation gesture. Cat and Dog retain roaming. Motion cadence is 30 fps at rest and 60 fps while active; Reduce Motion and visibility controls remain in place.
- Visual snapshot scenes now exercise the production renderer rather than forcing old artwork overrides.

## Verification

- Full Swift test suite: 361 tests passing after the final hit-region correction.
- New tests cover frame-rate-independent spring settling, interruptions, invalid samples, six-axis rigid-link lengths, presentation continuity, actual deformation output, and transparent image borders.
- Visual review caught vertical edge streaks caused by a warp ROI that did not match the complete input extent. The renderer now supplies the full extent and the border regression test covers this failure.
- Review exports include rest, attention, touch, sleep, and production window scenes. Export with `DESKPET_CONTINUOUS_OUTPUT=/tmp/deskpet-review-new swift test --filter PetContinuousArtworkTests`; use a fresh destination because exports do not overwrite files.
- The signed macOS review build was launched. Cat and Pauli were inspected in the live window, and Pauli's Look Around action produced an articulated response with a fixed base.
- `scripts/verify-visual-baselines.sh` fails against the pre-redesign fingerprints, as expected. The old baseline is intentionally preserved; accepting a new baseline remains a separate visual review step.

## Limits

动物目前是连续的 2.5D 写实图像变形，并非完整三维蒙皮动物。大幅转身、真实侧向步态和蜷卧仍受单视角素材限制；睡眠表现为闭眼低头休息。不能把这次修改描述为已达到完整三维动物的真实性。

Animals remain continuously deformed 2.5D images, not fully skinned 3D animals. Large turns, anatomically accurate side-on gait, and curled-up sleeping remain limited by the single-view source. Sleep is expressed as closed eyes and a lowered head.

The animal GPU renderer currently uses the deprecated but available `CIWarpKernel(source:)` API on the macOS 14 deployment floor. It produces a build warning. A compiled Metal kernel is the follow-up path if this renderer is retained; if kernel/image creation fails, the canonical still image remains visible.

No legacy assets were deleted, and no commit or push was performed.

## CyboPal client motion reference

The follow-up arm implementation was checked against the local
`/Users/tianlei/Documents/codes/cybopal-client` checkout at `a46060a8`:

- `desktop/ui/tauri/src/pages/Interaction.tsx`: `createWallsScene` has a static three.js arm illustration; it does not animate six live joints. `ArmPose`, quaternion rotation, and `wallValueFromArmPose` describe end-effector orientation and projecting screen corners into the workspace.
- `desktop/ui/tauri/src/domain/positionPresets.ts`: sitting, reclined, standing, and portrait semantics, including a 90-degree display roll.
- `desktop/app_shell/src/cybopal/step_arm.rs`: newer targets can preempt earlier motion rather than queueing stale movement.

Pauli adapts those concepts into a local presentation model. `CyboPalArmMotion` provides observation, reach, lift, portrait, celebration, and folded-rest sequences. Each finite sequence anticipates, moves, briefly holds, and settles back to sitting using quintic interpolation. The existing velocity-preserving presentation controller handles interruption. Hidden-window gaps pause the action clock; Reduce Motion suppresses the large sequences.

The shoulder and elbow solve a desired wrist reach/height together, with wrist compensation for the screen. Presentation joint limits and projected screen-corner bounds constrain the target without moving the base. The current compact link proportions, IK approximation, and limits are DeskPet-specific, not calibrated CyboPal hardware kinematics. No device connection or robot command was added, and the client checkout was not modified.

Interruption tests exposed a further issue: interpolating valid joint-angle endpoints can still swing the display outside the canvas between them. The final controller smooths wrist position and screen orientation first, then solves and constrains the joints on every frame. It preserves the motion history while keeping intermediate screen corners in bounds.

`Look Around` now reliably selects an observation gesture rather than a random personality pose. Feeding/nuzzling trigger reach, reminders trigger lift, autonomous actions can explore or roll the screen, and sleep folds the arm down.

Verification includes action selection, neutral sequence boundaries, finite bounded joints, screen-corner visibility, suspension, and rapid interruption with a grounded base. A 120-frame, 30 fps preview and pose contact sheet are exported with `DESKPET_ARM_OUTPUT=/tmp/deskpet-arm-new swift test --filter CyboPalArmMotionTests` (fresh output directory required). The pre-redesign visual baseline remains unchanged.

Final follow-up verification: 368 tests in 79 suites passed; the release app built and passed strict code-signature verification using the existing local identity. The animal renderer's previously documented Core Image deprecation warning remains. The rendered motion preview is four seconds at 30 fps.

## Merge verification — 2026-09-07

The earlier baseline-preservation notes describe the development checkpoint. Before merging, the character contact sheet, arm action sheet, and representative production scenes were reviewed again, and all 1,638 visual baseline records were regenerated for the production renderer. The test thresholds remain unchanged.

The full suite again passed all 368 tests in 79 suites. An isolated release app passed strict signature verification with `Jarvis Codex Local Development` outside the sandbox, where the login keychain is accessible.

Local packaging now requires the existing development signing identity. The GitHub Release workflow does not provision a distribution identity; tagged public releases require a separately configured, authorized distribution signing identity. The local certificate must not be exported or used for public distribution.

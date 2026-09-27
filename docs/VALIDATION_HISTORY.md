# Historical validation (superseded by VALIDATION.md)

These results describe earlier revisions, including the rejected illustrated interior. Current 3D results are in `VALIDATION.md`.

# Validation evidence

Validation date: 2026-09-27. Godot 4.7 stable (`5b4e0cb0f`). Native rendering: Metal 4 / Forward+, Apple M4 Pro.

## Functional suite

The current interior revision passes **200 existing checks, 0 failures**, plus **80 interior checks, 0 failures**. `docs/test-results/suite.log` contains no engine warnings or errors. Tests use an isolated checkpoint and remove it on completion.

Coverage includes:

- Campaign gates, sale prices, upgrades, corruption rejection, combat damage, swept projectiles, victory, death and checkpoint retry.
- Mouse selection, independent craft orders, stopping, arrival braking, obstacle clearance, pursuit and camera-depth picking.
- Reverse-direction box selection, Shift-additive boxes/clicks, empty-box clearing, click jitter, group movement/3D altitude/Stop/Recall, compatible group resource jobs, and distinct arrival berths at the sector rim.
- Drag cancellation through Escape, management views and focus loss; preserved live orders; orbit/HUD input ownership; exclusion of hidden, destroyed and behind-camera craft.
- Full three-dimensional courses, altitude limits, vertical detours, climbing/diving, pitch/bank, orbital camera gestures, draft cancellation and modal input isolation.
- Physical bay footprints, mass limits, partial ore pods, reservations, delivery commit, overlapping/invalid manifests, version-two restoration and legacy-save migration.
- Rejection of unknown payloads, invalid quantities, missing source identities, mismatched reservations, duplicate delivery and partial sealed freight.
- Actual tug travel, attachment, visible moving tow, retained payload after Stop, return and unloading; no salvage credit before delivery.
- Actual drone travel, extraction into a carried pod, retained payload after Stop and delivery; no ore credit at extraction time.
- Direct resource interaction cannot bypass workers. Two crew leave the interior when Latch deploys.
- Fleet recovery at the flight ceiling and sector rim, repeated recall during unloading, held station interaction completing recovery and docking, and cancellation of movement previews on recall.
- Shared geometry dimensions and mesh preservation during material batching.

The implementation agent ran this revision. The adversarial critic read the final logs and reviewed the regression cases; it did not independently execute this revision.

## Complete automated flight

The current interior revision’s complete campaign runs are recorded in `docs/test-results/pilot-headless.log` and `pilot-rendered.log`. Both record:

```text
PILOT freight: 3
PILOT ferrite: 24
PILOT act: 1
PILOT combat: kills=3 hull=160.0
PILOT RESULT: mode=won simulated_seconds=209 failures=[]
```

The pilot uses selection/movement commands, dispatches the working craft, waits for actual deliveries and returns, trades at the station, fights with real projectiles, recovers the core and opens the corridor. It also exercises a climb and a below-plane transit. It does not teleport the ship, grant resources, override weapon aim, directly destroy enemies or bypass contract gates. Both runs use an isolated save and 4× simulation speed. Both logs are free of engine warnings/errors. `docs/screenshots/won.png` comes from the rendered completion.

This verifies a completable loop, not a human completion-time estimate or broad balance testing.

## Native-window checks

The rebuilt application was launched from `/tmp` using its embedded PCK and inspected through computer use. Confirmed:

- Pressing 4 launches/selects Latch; clicking freight sends the tug to recover it.
- Delivery adds 12 t and occupies four cells. C shows the corresponding physical container and 2×2 manifest footprint.
- Relaunching Latch changes the interior to five crew aboard and two on the tug, with the two figures removed from the interior.
- Pressing 2 launches/selects Mole 01. Clicking space gives that drone its own route; it reaches the destination while the mothership remains stationary. R recalls it.
- Closing the native window exits cleanly. `docs/test-results/native-operations.log` has no warnings/errors.
- `codesign --verify --deep --strict builds/Wayfarer.app` succeeds.

Screenshots: `native-delivered-cargo.png`, `native-crew-away.png`, and `native-drone-control.png` in `docs/screenshots/`.

Earlier native checks covered click navigation, wheel-adjusted 3D move previews, climb/arrival, draft cancellation, interior/watch controls, chart, pause, manual and settings. Their screenshots remain historical evidence of those revisions; they are not current art captures.

## Native drag-selection follow-up

The drag-selection bundle was launched from `/tmp` with an isolated capture checkpoint. Native mouse input deployed both drones, dragged a box around them and the mothership, and selected all three with matching rings and fleet-button indicators. One click produced three routes; all craft arrived at distinct positions. `native-drag-selected.png` and `native-group-arrival.png` record the selected fleet and arrival. The window closed cleanly; `docs/test-results/native-drag-selection.log` has no warnings/errors, and bundle signature verification succeeds.

The final 200-check suite also closes without warnings/errors. An intermediate run concurrent with project import reported resource cleanup warnings; a separate verbose run and the final ordinary run were clean. No source workaround was needed. The critic found the radial-boundary berth overlap, reviewed its fix and regression, and identified no further concrete source-level defect within the drag-selection review scope.

## Working-fleet visual and performance evidence

These actual engine captures were inspected at 1440×900. Their `.log` files record local rendering samples:

| View | File | FPS | Draw calls | Primitives |
| --- | --- | ---: | ---: | ---: |
| Revised hull | `ship-detail.png` | 120 | 327 | 152,241 |
| Nine-facility interior | `interior-operations.png` | 120 | 203 | 135,666 |
| Two deployed mining drones | `mining-operations.png` | 120 | 405 | 179,183 |
| Latch towing freight | `tow-operations.png` | 145 | 420 | 177,753 |
| Physical cargo inspection | `cargo.png` | 120 | 104 | 12,816 |
| Updated flight manual | `manual.png` | 119 | 142 | 104,936 |

Mining, towing and cargo captures were produced by the rebuilt standalone application from `/tmp`. The other captures use the same source revision through the installed engine. Capture modes stage an initial location or manifest for visual inspection. Mining and towing captures wait for the real workers to reach their operating states. They are distinct from the unstaged campaign pilot and the interactive native checks.

These short local samples are not minimum frame-rate guarantees or frame-time percentiles. Intel, low-end hardware, prolonged thermal load and other operating systems were not tested. Small secondary text at 720p remains a readability limitation.

## Build and review outcome

`tools/build_macos.sh` produces `builds/Wayfarer.app` and `builds/Wayfarer-macOS.zip`; `docs/test-results/build.log` records the build. The bundle includes its PCK, matching universal Godot runtime, icon, font license and engine notices. It is ad-hoc signed, not notarized. It uses the installed editor-capable runtime because matching native export templates were not installed. The source tree is not a runtime dependency.

The fleet review found four concrete issues: repeated recall resetting unloading, unreachable recovery points at sector limits, overwritten failure explanations, and inconsistent payload validation. All were fixed, with reviewed regression evidence. The critic's bounded follow-up identified no further concrete runtime blocker in these paths. See `CRITIC_REVIEW.md` for scope and attribution.

The hull remains procedural 3D. The new interior is an interactive illustrated adaptation of the reference with live crew; it closely preserves room composition but does not claim exact pixel identity or a 3D interior reconstruction. Towing is a kinematic attachment with a visible cable and wider navigation clearance; it is not a rigid-body rope or wreck-cutting simulation. The seven named crew are individually selectable and assignable; Latch still uses its fixed named pilot/rigger pair. Broad playtesting and production art remain outstanding. **AAA quality is not approved or claimed.**

## Functional illustrated interior — current revision

`tests/interior_suite.gd` passes **80 checks**. It covers:

- All seven crew selected through the actual deck input path; all nine rooms opened by their mapped art positions; a GUI assignment button changing a real job; interior input preserving the exterior course.
- Six-second travel, rejection of midwalk retarget without a sprite jump, native/cross-trained staffing, station capacity, away tug crew, incapacitation, rest, medical care and security injury reduction.
- Frame-subdivision determinism, finite reserves, real crop/meal production, water/medicine conservation near empty stores, ration fatigue, power failure/restart, load shedding, disabled reactor wear, filter replacement and repair-kit consumption.
- Powered/operator-dependent fabrication, one-time charging/refunds, full-locker cancellation rejection, pending output capacity and resupply without overflow.
- Four tonnes removed from real cargo pods before parts are credited, retained delivery progress and reservations, rejected partial transactions.
- Version-three JSON round-trip, legacy migration, malformed identity/station/quantity/recipe rejection; production/crew/resource state persists.
- Interior pause and settings, cargo/chart/pause return origins, docked interior return, paid resupply and free recovery from a destroyed reactor with no battery or kits.

The same external test harness was run against the standalone application's **embedded PCK from `/tmp`**, headlessly and with Metal rendering. Both pass **80/0** in `interior-packaged-suite.log` and `interior-packaged-rendered.log`. These are automated Godot input events and domain assertions, not a human playtest. The test script is outside the bundle; all game resources and scenes it loads come from the PCK.

An intermittent teardown warning was traced with verbose output to active `dock.wav` and `adrift.wav` audio playbacks, not crew/cargo objects. The new test harness now shuts audio down and waits for the mix thread before freeing the scene, matching the application's existing orderly quit path. The final source run, packaged headless run, packaged rendered run and verbose diagnostic run close without cleanup warnings/errors. This changes test cleanup only; it does not mask failed assertions or disable sound in the shipped game.

### Current visual evidence

- `native-interior-final.png`: final rebuilt standalone PCK from `/tmp`, **1440×900**, 120 FPS sample, 98 draw calls, 9,201 primitives; capture exited successfully.

- `interior-live-v2.png`: actual engine output at **1440×900**, 120 FPS sample, 98 draw calls, 9,201 primitives.
- `interior-720p.png`: standalone PCK capture from `/tmp`, actual output **1152×720**, 119 FPS sample, 98 draw calls, 9,201 primitives. The engine maintained the project's 16:10 aspect ratio. Secondary labels are small at this size; station buttons and the crew roster remain readable.
- The screenshot's asymmetric nine-room arrangement, warm engineering/fabrication, cyan bridge/medbay, crop beds, bunks, central tables and hull outline are closely preserved by the edited plate. Crew are separate, selectable live sprites with selection rings and station travel. Persistent room outlines identify the currently inspected facility. The selected sprite is mipmapped for clean reduction.

The final computer-use mouse/keyboard pass was **blocked by the locked Mac**. The user was asked to unlock it; no desktop security setting was changed. Earlier native-window checks above describe preceding revisions. Current packaged rendering, scripted input and signature checks succeeded, but are not labeled as a completed hands-on desktop check.

Source review closed the resource-overflow, material-refund, broken-reactor recovery, mode-return, disabled wear, finite-input output and midwalk jump findings. The independent critic reviewed source, screenshots and logs; it did not execute the tests. Exact pixel parity, orbitable interior geometry, unique character sprite art and AAA production quality are not asserted. Asset prompts/provenance, domain invariants and architecture choices are documented separately.


## Archived 3D interior validation before frontier expansion

# Validation — modeled 3D interior

Revision tested: 27 September 2026. Godot 4.7 stable (`5b4e0cb0f`), macOS Apple M4 Pro, Metal Forward+. Historical results, including the retired 2D interior, are in `VALIDATION_HISTORY.md`.

## Executed checks

| Test | Result | Evidence |
| --- | --- | --- |
| Existing campaign/fleet/cargo suite | 200 passed / 0 failed | `test-results/suite.log` |
| Crew, resources, station controls and persistence | 80 passed / 0 failed | `test-results/interior-suite.log` |
| New 3D geometry, movement and animation suite | 61 passed / 0 failed | `test-results/interior-3d-geometry.log` |
| Standalone PCK, headless 3D suite from `/tmp` | 61 passed / 0 failed | `test-results/interior-3d-packaged.log` |
| Standalone PCK, Metal-rendered 3D suite from `/tmp` | 61 passed / 0 failed | `test-results/interior-3d-packaged-rendered.log` |
| Standalone PCK, existing interior suite | 80 passed / 0 failed | `test-results/interior-packaged-suite.log` |
| Full campaign, headless and rendered | Both won in 209 simulated seconds; failures empty | `test-results/pilot-headless.log`, `pilot-rendered.log` |

These final logs have no engine error or warning. Tests/captures use isolated checkpoint paths. The critic independently executed the current 61-check 3D suite with a clean result; see `CRITIC_REVIEW.md` for scope and attribution.

The 3D suite checks modeled fixture/actor presence, all 81 room-to-room routes with samples every 0.1 m against wall/furniture footprints, three reachable bed approaches, physical door motion, actual leg-joint transform changes, work clips, orbit projection, direct orders removing staffing, arrival holding position, return to work, mid-route reassignment, fractional-tick command continuity while paused, saved route restoration, corrupted path rejection, stable shared workstations, raised bridge arrival, old dormitory migration, incapacitated poses, and both settled and mid-transfer crew departures/returns on Latch.

The campaign pilot uses actual ship routes, drone extraction/return/unload, crewed towing, cargo delivery, station trades/upgrades, projectile combat, core retrieval and beacon completion. Both runs finish with three freight deliveries, 24 ferrite, three kills and 160 hull. No progression grants or teleportation bypass the campaign. This proves reachability, not human pacing or difficulty.

## Native interaction

Launched the standalone bundle from `/tmp`. Native computer input selected an actual 3D engineer and assigned quarters while paused. A subsequent input-delivery interruption prevented completing that first window's test; no game or tooling cause was established from that run.

A fresh standalone run loaded the same PCK with a temporary external input probe. The probe only logged mouse/key events; it did not issue orders or change game rules. Native clicks then successfully paused/resumed, selected Nia, issued a right-click floor order, waited for physical arrival with `AWAITING ORDERS`/zero hydroponics staffing, reassigned Hydroponics, and observed walking followed by `ON DUTY`/restored staffing. Native wheel input zoomed the 3D camera. Tab returned to flight and back. The window closed cleanly through its ordinary close control. `test-results/native-interior-3d-probe.log` records the delivered input and contains no errors/warnings.

`native-3d-manual-arrival.png` and `native-3d-duty-restored.png` record that interaction. No complete broad human playtest or all-platform input certification is implied.

## Visual and motion evidence

- `screenshots/native-interior-3d-final.png`: final embedded PCK, 1440×900 actual renderer capture from `/tmp`. The smaller `native-interior-3d-720p.png` verifies the layout at 1152×720; secondary text is small but controls remain visible.
- `interior-3d-default.png` and `interior-3d-reverse.png`: opposite camera angles of the same modeled room geometry.
- `interior-3d-engineering.png` and `interior-3d-crew.png`: equipment and jointed-character closeups.
- `interior-3d-motion.mp4`: 22.8 seconds at 1440×900/30 FPS, actual Godot movie recording. It shows Ivo leaving Engineering, walking through opening doors, approaching/resting at a bed, and camera orbit revealing model backs. It contains no image-generation or post-render animation; FFmpeg only encodes the engine AVI to H.264/AAC.

`tests/interior_showcase.gd` reproduces these views and the recording. It sends a genuine assignment command and changes the inspection camera. It is staged visual evidence, distinct from the unstaged campaign pilot.

The final native capture sampled 120 FPS, 5,235 draw calls and 9,836,894 submitted primitives including shadow/outline passes. This is a brief local observation on the M4 Pro, not a sustained benchmark. Multiple shadow passes and detailed modeled foliage remain costly; no low-end or Intel performance promise is made.

## Packaging and scope

`tools/build_macos.sh` produced `builds/Wayfarer.app` and `Wayfarer-macOS.zip`. `codesign --verify --deep --strict` succeeds. The native app contains the matching universal runtime, PCK, fonts/license notices and `INTERIOR_3D.md`. The source archive contains editable source, tests, docs and final media; caches and native binaries are excluded. The retired image assets under ignored documentation are absent from the PCK; `test-results/pack-contents.log` independently confirms the 3D model exists and both old image paths do not.

The active interior is actual 3D throughout, with seven articulated crew and all nine functional stations. No reviewed movement defect remains open after the critic's fixes. Art fidelity remains below exact reference parity: industrial geometry, materials and rigid articulated people are stylized interpretations. Crew routes avoid static objects but do not dynamically avoid each other. The critic has not approved an AAA-quality or exact-match claim.

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

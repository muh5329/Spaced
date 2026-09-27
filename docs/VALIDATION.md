# Validation — frontier expansion 1.1.0

Tested 27 September 2026 with Godot 4.7 stable (`5b4e0cb0f`), Apple M4 Pro and Metal Forward+. Earlier interior validation is retained in `VALIDATION_HISTORY.md`.

## Executed checks

| Test | Result | Evidence |
| --- | --- | --- |
| Original campaign, fleet, cargo, selection and spatial flight | 200 passed / 0 failed | `test-results/core-frontier.log` |
| Crew, resources, station controls and saves | 80 passed / 0 failed | `test-results/interior-frontier.log` |
| Modeled 3D interior, routes, articulated animation | 61 passed / 0 failed | `test-results/interior-3d-frontier.log` |
| New frontier domain and runtime suite | 142 passed / 0 failed | `test-results/frontier-suite.log` |
| Final standalone PCK, headless frontier suite from `/tmp` | 142 passed / 0 failed | `test-results/frontier-packaged.log` |
| Final standalone PCK, rendered frontier suite from `/tmp` | 142 passed / 0 failed | `test-results/frontier-packaged-rendered.log` |
| New multi-system pilot, headless | 3 commissions, 4 jumps, 170 simulated seconds, zero failures | `test-results/frontier-playthrough.log` |
| New multi-system pilot, Metal rendered | Same complete loop, zero failures | `test-results/frontier-playthrough-rendered.log` |
| Original story pilot after expansion | Victory in 209 simulated seconds, zero failures | `test-results/story-frontier-playthrough.log` |

The four source suites total **483 passing checks**. Standalone runs repeat the frontier checks; they are not counted as additional unique coverage. All listed final logs are free of engine errors/warnings. Tests use isolated save paths and do not overwrite the player's expedition.

Frontier coverage includes graph connectivity, bidirectional routes, reproducible generation, changed seeds, disconnected jump rejection, all nine systems, three-contract limit, issuer-only deliveries, exact physical ore/freight removal, duplicate payment rejection, named-patrol progress, story isolation, survey data, abandonment, office rotations, resolved-target suppression, exhausted-world supply availability, legacy migration, malformed save rejection, unsafe/deployed/empty-battery/pursued jump rejection, hull/resource continuity, single signal wiring after rebuilding, arrival saves and Continue, hazard telegraph/discharge/altitude avoidance, persistent kills/deposits, stable rock geometry after salvage, risk-scaled populations, safe arrivals, and actual flight courses issued from local-chart clicks.

## Gameplay reachability

`frontier_playthrough.gd` uses ordinary movement, dispatch, attack, interaction and station commands. Starting with the base ship, it flies to Meridian, accepts a 16 t procurement job, has a drone physically mine/return/unload the ore, docks and delivers, buys weapon/shield upgrades, accepts patrol and survey commissions, jumps to Cinder Reach, destroys its patrol with real projectiles, travels through Orison to Glasswake, decodes its relay, returns to Meridian and claims both payments. A saved snapshot confirms all three completed commissions and the home-system location. No teleports, granted resources, direct kills or forced objectives are used. Both headless and rendered versions finish in 170 simulated seconds at 4× time.

The original pilot still performs climbs/dives, three crewed salvage deliveries, 24 t of drone mining, trades/upgrades, all three authored raiders, core towing and the story beacon. It reaches victory in 209 simulated seconds. These automated pilots prove reachability, not human difficulty balance or pacing.

## Native controls and visual inspection

The bundled engine/PCK launched from `/tmp` using an isolated external setup/probe script. The fixture only opened a seeded docked expedition; subsequent game actions came from native computer mouse/keyboard input. The probe logged mode, system, active jobs, tracking and navigation state without issuing commands.

Native input accepted a bounty, pressed J for the chart, clicked its jump button, arrived in Cinder Reach, pressed L for the active log, returned with Escape, opened M and clicked the transit relay. The log records `navigator=true`, followed by arrival (`false`), in the generated system. The window closed normally. See `test-results/native-frontier.log`.

Native inspection found a notification/toolbar overlap. Notifications now wrap below the toolbar and danger banners move below active notices; world-input blocking matches the drawn rectangles. The final packaged build repeated native acceptance, J, jump and arrival after this change (`native-frontier-final.log`). The full core suite was rerun successfully after the notification changes.

The actual engine renders under `screenshots/frontier-*.png` show the network, four station offers, animated departure/transition, generated Cinder/Veil scenes, arrival guidance, and a local chart. `frontier-playthrough-complete.png` records the rendered pilot's completed board. `tests/frontier_showcase.gd` reproduces the staged views. Short capture FPS samples include shader/startup warmup and are not a sustained benchmark. Existing `interior-3d-motion.mp4` and the 61-check interior suite remain evidence for the real 3D crew/interior.

## Review and packaging

The independent adversarial critic found three concrete issues: unsafe flight-log checkpointing, salvage-dependent RNG drift, and impossible delivery offers after depletion. All were fixed and rechecked. The critic's second source/visual pass found no additional critical blocker; it reviewed the implementation-agent logs rather than independently executing them. See `CRITIC_REVIEW.md` for attribution and scope.

`tools/build_macos.sh` produces the standalone 1.1.0 bundle/ZIP with the matching universal engine, PCK, icon, licenses, `INTERIOR_3D.md` and `FRONTIER.md`. `codesign --verify --deep --strict` passes. Actual packaged tests run from `/tmp`, independent of a source-directory working path. The editable source archive excludes native builds/caches and includes code, tests, decisions, validation and media. `builds/SHA256SUMS.txt` records archive hashes.

The implemented frontier is nine finite systems with four commission types, three generated hostile roles and timed ion hazards. It is not an infinite/replenishing universe or a faction simulator. Art fidelity remains a stylized reconstruction, not exact reference parity or an AAA endorsement. Intel/low-end hardware and broad human playtesting remain untested.

# Adversarial quality review

Final review date: 2026-09-27. Reviewer: independent adversarial critic agent. Engine: Godot 4.7 stable (`5b4e0cb0f`).

This is a chronological review record. Earlier verdicts describe their respective candidates; the latest real-3D interior section below governs the current interior review and any outstanding findings.

## Verdict

**Small-game acceptance: passes within the tested macOS, keyboard-and-mouse scope.** The candidate is a complete compact expedition with a taught beginning, resource collection, docking/trade/upgrades, combat, mission recovery, victory, postgame exploration, death/retry, and checkpoint persistence. No unresolved P0/P1/P2 defect or campaign deadlock was found in the reviewed candidate. This is bounded acceptance, not a guarantee that no undiscovered defect exists.

**AAA quality: rejected.** The implementation does not satisfy the user's requested AAA quality bar. The supplied concept has substantially richer industrial surface detail, materials, lighting, environmental composition, and interior activity. The delivered game has one belt, three raiders, three short contracts, procedural low-poly models, synthesized audio, and a crew-priority screen. Functional completeness and attractive UI do not erase that production gap. The user should receive the working game and this verdict without an AAA endorsement.

## Independently verified evidence

- Read the campaign model, coordinator, input, persistence, spatial queries, ships, projectiles, harvestables, UI, architectural documentation, and test sources.
- Authored and ran 25 initial domain/actor checks, then 14 regressions for persistence, manual navigation, and paused simulation. These exposed and verified fixes for actual defects; their coverage overlaps the final suite below.
- Independently reran `tests/test_suite.gd`: **77 passed, 0 failed**, exit code 0, with no engine errors or shutdown warnings. Coverage includes cargo limits, duplicate rewards, invalid saves, upgrades, real movement/projectile collisions, interaction cancellation, partial depletion, crew restoration, all act gates, victory persistence, paused modes, death/retry, and mixed-mesh batching.
- Independently reran `tests/playthrough.gd`: **victory reached, zero failures**, with 3 freight recovered, 24 ferrite mined, and 3 raiders defeated. The pilot completed in 70 simulated seconds at 4× time. It uses thrust/boost/brake/action input and real projectiles; it does not teleport or grant progression. It supplies deterministic world-space aim and invokes station commands directly. This establishes mechanical reachability, not human combat difficulty or usability.
- Launched the packaged `builds/Wayfarer.app` from `/tmp`, using its bundled engine and PCK. The game reached `menu` with 15 world contacts and exited through the normal application quit command with no engine warnings/errors. No source-directory working path was required.
- Verified the bundle's ad-hoc signature using `codesign --verify --deep --strict`. The engine binary contains arm64 and x86_64 slices; this does not establish Intel hardware compatibility.
- Visually inspected final title, flight, salvage at 1280×720, combat, dock, interior, map, and victory captures. The captures show consistent layout and a functional industrial visual identity. Staged ending captures intentionally have zeroed statistics and are not evidence of the pilot's ending state.
- Read the final native capture logs: successful image saves, no warning/error lines, and sampled rates of 119–120 FPS on the tested machine. These brief samples are not a sustained performance benchmark or evidence for other hardware.
- Reviewed README, domain vocabulary/invariants, and architecture decisions. They accurately disclose checkpoint semantics, the management-only interior, the compact scope, native-bundle construction, and untested platforms.

Tests use isolated save paths. The critic modified only this review in the project. Native GUI interactions reported by the implementation agent are supplementary evidence; the critic independently checked code, headless execution, packaged startup/quit, and final images.

## Defects found and resolved

| Initial severity | Finding | Resolution and verification |
| --- | --- | --- |
| P2 | Flight Manual could return to pause from the title, or to the title from pause, because its return state was stale. | Explicit `open_manual(from)` records the caller. Both paths pass independent regressions and the final suite. |
| P2 | Crew priority was stored only as metadata and was neither serialized nor restored consistently. | Crew priority is persisted in the domain and applied when rebuilding the world. Disk/domain/world restoration checks pass. |
| P2 | Partially mined deposits replenished on checkpoint reload while collected totals persisted. | Per-deposit remaining quantities are persisted and restored. Partial-depletion regressions pass. |
| P2 | The survey pulse promised to reveal contacts but only drew a cosmetic ring. | It now adds nearby individual world labels and remaining ore quantities. Code inspection confirms the effect. |
| P2 | A presentation iteration omitted large armor surfaces when batching mixed indexed and nonindexed meshes. | Geometry is indexed before batching. The final regression preserves all faces; final screenshots show intact armor. |
| P3 | A vertical drone beam supplied colinear look/up vectors when the ship overlapped freight. | Near-vertical beams use an alternate up axis. The final overlap test runs without the warning. |
| P3 | Rapid shutdown reported retained ambient audio playback resources. | Explicit stream shutdown and a short normal-quit cleanup interval were added. Final suite, pilot, native capture logs, and packaged normal quit are clean. Engine-forced `--quit-after` can bypass that normal shutdown interval and still report queued audio resources. |

## Why the small-game acceptance passes

- The full campaign can be reached through its actual movement, collection, combat, and interaction rules.
- Free repairs, rechargeable boost, cumulative contract progress after sales, and a dedicated mission-item slot avoid obvious economic deadlocks.
- Death is recoverable and checkpoint restoration retains the relevant domain state, rather than trying to serialize transient combat nodes.
- The `SpaceEntity → Ship → PlayerShip/PirateShip` and `SpaceEntity → Harvestable → OreAsteroid/SalvageCache` hierarchies share real behavior. Persistent rules, visuals, UI, and systems have identifiable responsibilities.
- The HUD, station, chart, crew screen, and ending share clear typography and color conventions. Freight is scattered, the derelict is visibly damaged and unpowered, and the final background has more depth than the first implementation.
- A self-contained native application, source project, executable tests, and domain/decision documentation are present. This is more than a folder of unbuilt scripts or disconnected mockups.

## Remaining limits and nonblocking polish

- **Art fidelity:** plain material regions, faceted rocks/planet rim, simple station architecture, sparse interiors, and basic character shapes remain far below the reference's detail and AAA expectations.
- **Content and tuning:** the campaign is short and authored around one encounter group. The deterministic pilot took no hull damage after its shield upgrade. Broader human playtesting is needed to judge challenge, pacing, aiming feel, and replay value.
- **Legibility/accessibility:** primary 1280×720 information is readable, but footer controls and secondary labels are small. There is no independent UI/text scaling, key rebinding, controller support, localization, or comprehensive accessibility validation.
- **Platform/performance:** only the documented native Mac setup is tested. No Intel, low-end GPU, Windows, Linux, Web-release, thermal soak, or sustained frame-pacing certification is claimed.
- **Distribution:** the bundle is locally ad-hoc signed, not Apple notarized, and contains the larger editor-capable engine runtime. It is suitable as the documented local deliverable, not a certified public-store release.
- **Production scope:** no large universe, deep market, systemic crew simulation, extensive enemy roster, professional voice/music production, or extended narrative campaign is present.

There are no remaining concrete release blockers identified for the documented small-game scope. The AAA request remains unfulfilled and must be stated plainly in the delivery.

## Click-command follow-up — 2026-09-27

This bounded follow-up reviews the replacement of direct WASD flight with ship selection and click-issued move/attack orders. It does not reopen or alter the production-quality verdict above. The critic reviewed source and regression cases, and did not run concurrent suites or rebuild the application during this follow-up.

The input and state design is coherent: an unselected ship rejects movement orders; clicking the ship selects it; world clicks are processed after GUI handling and rejected over HUD panels; X cancels orders; paused/management screens retain but suspend a route; docking/undocking clear transient movement and attack orders; checkpoint load creates an unselected ship with no stale course.

Four findings from the review have been addressed in source and have matching regression cases:

| Finding | Fix and reviewed evidence |
| --- | --- |
| Navigation diamonds could overlap blocked radar/hostile-banner regions. | Drawing and picking share `navigation_marker`, now clamped to HUD y=265…720, keeping its 24-pixel hit disc outside both reserved regions. Tests cover northern and southern markers. |
| Close-range pursuit could repeatedly choose a berth on the wrong side of a rock. | Obstructed pursuit now routes toward the target itself, then returns to ordinary standoff behavior after line of sight clears. The regression uses a radius-3 rock, player 8 m to one side, and enemy 7 m to the other, and requires a route to the far side. |
| Approaching clicked freight could make E recover a nearer neighboring crate. | The coordinator retains an interaction preference for the clicked contact while it is available and in range. World orders, Stop, docking, death, and world reconstruction clear that preference. A regression reproduces the actual freight layout with a nearer neighbor. |
| Automatic fire reused padded ship clearance and could suppress an unobstructed shot near a rock. | Firing now uses the sector's projectile collision query; navigation retains its larger hull margin. The regression places the target 5 m and shooter 15 m from the same side of a radius-3 rock and requires firing without a detour. |

**Bounded source-review verdict:** no unresolved concrete defect was identified in the reviewed click-command flow after these fixes. Selection, input isolation, obstacle routing, stopping, automatic engagement, and pause/dock/resume responsibilities are explicit. The new interaction preference is transient and does not enlarge the save model.

**Final execution evidence:** the implementation agent ran the updated suite and both rendered/headless pilots. The critic read the resulting `docs/test-results/suite.log`, `pilot-rendered.log`, and `pilot-headless.log`: **105 tests passed, 0 failed**; both pilots reached `won` in 84 simulated seconds with 3 freight recovered, 24 ferrite mined, 3 raiders defeated, hull 160, and empty failure lists. These logs contain no warnings/errors. This is reviewed execution evidence from the implementation agent, not a claim that the critic independently reran the follow-up suite. The implementation agent also reports rebuilding the native bundle and passing signature verification; the earlier native-bundle evidence above applies to the prior control revision.

## Homeworld-style spatial-control follow-up — 2026-09-27

This bounded follow-up covers the user's request for 3D ship movement and control: altitude orders, volumetric obstacle routes/collisions, pitch/bank/heading changes, perspective camera orbit, and spatial picking. It does not claim feature equivalence with Homeworld or change the earlier production-quality verdict.

The critic reviewed `FlightNavigator`, `TacticalCamera`, `MoveOrderPreview`, `WorldPicker`, shared ship attitude, player/enemy flight, coordinator input, HUD projection, and the corresponding regression cases. No suites or builds were launched by the critic in this follow-up, and only this review document was edited.

The implementation now has actual volumetric movement rather than only a camera change. Orders preserve a full X/Y/Z destination within the ±60 m altitude envelope; navigation can route above/below obstacles; collision resolution retains vertical separation; enemies chase elevated targets. Flight uses a perspective orbit camera. G creates a draft course, Shift/mouse or the wheel sets altitude, a click commits it, and Escape cancels the draft without replacing the current order. Heading alignment, acceleration, pitch, and bank provide visible ship attitude during turns, climbs, and dives.

All six findings from the first spatial review are addressed:

| Finding | Fix and reviewed regression evidence |
| --- | --- |
| Releasing a pending RMB click after Escape/X could issue a new order after cancellation. | Draft cancellation and Stop now end the pending camera gesture. Tests send the complete press → cancel → release sequence and check that flight does not restart or replace the retained order. |
| Any player ray hit took priority over a nearer overlapping ship. | Player and contacts participate in one nearest-distance decision. A foreground-enemy regression places the enemy along the player's screen ray and requires an attack on that enemy. |
| Behind-camera contacts could produce mirrored scan/hostile HUD labels. | Scan contacts and hostile labels now reject behind-camera entities; navigation markers explicitly classify them as offscreen. The test also verifies that a behind-camera ship cannot be selected through its mirrored projection. HUD rejection was checked in source. |
| LMB or a second orbit button could interfere with an active RMB/MMB gesture. | The initiating orbit gesture owns mouse buttons until release. Regressions require that LMB cannot confirm a draft and MMB cannot replace an active RMB gesture. |
| Docking froze the ship's flight pitch and bank in the berth. | Docking explicitly zeros model attitude. The regression docks a ship with nonzero pitch/bank and verifies a level berth pose. |
| Height-limit overshoot accumulated invisibly and delayed reversal. | Wheel adjustments advance the anchor only by the applied clamped delta; drag saturation rebases its anchor. A regression reverses immediately after both drag and wheel overshoot at the altitude ceiling. |

**Bounded source-review verdict:** no unresolved concrete defect was identified in the reviewed spatial-control flow after these fixes. Drafts remain separate from live orders, orbit owns its gesture, perspective selection respects depth, and modal transitions discard unfinished input. The reviewed tests also cover direct travel above an asteroid, vertical detours, altitude bounds, actual climbs/dives, attitude changes, raised enemy pursuit, and station approaches from altitude.

**Execution evidence reviewed:** the implementation agent's updated `docs/test-results/suite.log` reports **139 passed, 0 failed**. Its updated headless pilot log records a real below-plane transit at approximately −15.8 m, 3 freight, 24 ferrite, 3 raider kills, hull 160, and victory in 106 simulated seconds with an empty failure list. The pilot source additionally performs a +24 m climb and starts combat from +22 m. These logs contain no warnings/errors. This is reviewed evidence from the implementation agent; the critic did not independently rerun this revision. Final rendered/native usability checks and packaging are owned by the implementation agent and are not inferred from source review.

## Working fleet and physical cargo follow-up — 2026-09-27

This bounded source review covers the user's request for controllable mining drones, a two-person salvage tug, cargo carried back to the Wayfarer, and finite bay space. It covers domain consistency, reservations, work/return/stop transitions, selection, checkpoint safety, and the shared cargo geometry. It does not endorse the concurrent ship/interior art revision or change the earlier AAA verdict. The critic did not launch tests, builds, or game windows in this pass, and edited only this document.

The implementation separates a work site from its worker. `Harvestable` holds site data; `SupportCraft` owns work progress and launch/return/unloading phases; `MiningDrone` extracts and carries a bounded ore pod; `SalvageTug` marks freight as in tow and moves the visible container behind a cable. Direct site collection methods have been removed. The shared `CommandShip` base supplies movement orders and steering without coupling the persistent expedition to scene nodes. Latch accounts for two crew away from the mothership.

`CargoBay` checks both mass and contiguous footprints across 4×5-cell rack decks. A work order reserves its load before departure. Stopping an empty craft releases its claim/reservation; stopping a loaded craft retains the payload and its promised space. Delivery consumes that reservation before awarding ore, salvage, or core progress. Selling clears ordinary manifest entries while retaining the core. Version-two restoration validates geometry and reconciles manifest mass with numeric cargo; legacy cargo migrates into slots. Docking, checkpoint writes, and opening the corridor require the whole fleet aboard, so an in-transit payload is not silently dropped by a new checkpoint. `CargoContainerModel` supplies the same dimensions for loose freight, drone pods, and the exterior cargo hold; enlarged inspection views are presentation transforms.

All four findings from the first fleet review are addressed:

| Finding | Fix and reviewed regression evidence |
| --- | --- |
| Holding E at a station or beacon repeatedly recalled the fleet and reset unloading every frame. | Recall is idempotent during return/unloading: it cancels repeating work without resetting arrival or transfer progress. The regression holds E throughout recovery and requires docking with every craft aboard. |
| Recovery points could lie above the +60 m flight ceiling or outside the sector rim. | Recovery uses a constrained, obstacle-safe staging point consistently for navigation, arrival, and transfer checks. A regression returns a drone with the Wayfarer at x=258 m and y=60 m. |
| A generic wrong-worker toast replaced useful bay-full, retained-load, or encrypted-core explanations. | The generic hint is emitted only for an incompatible worker type; an accepted worker's own failure message remains visible. This fix was checked in the coordinator and craft source. |
| Payload kind/amount could disagree with its reservation and corrupt manifest/counter consistency. | Kind, permitted amount, source identity, and reservation agreement are checked before receiving or incrementing counters/serials. Regressions reject unknown types, negative amounts, empty sources, and partial sealed freight, and preserve reservations after rejection. |

**Bounded source-review verdict:** no further concrete runtime blocker was identified in the reviewed fleet/cargo paths after these fixes. The tow is a kinematic attachment with a visible cable and a larger navigation margin, not a rigid-body rope simulation. Reservations and footprint/mass limits are actual domain rules. Broad human testing of fleet pacing and usability remains outside this source-only pass.

**Final execution evidence reviewed:** the critic read the replacement `docs/test-results/suite.log`, `pilot-headless.log`, and `pilot-rendered.log` for the final revision. The suite reports **179 passed, 0 failed**; both pilots reach victory in **211 simulated seconds**, with 3 freight, 24 ferrite, 3 raiders defeated, hull 160, and empty failure lists. All three logs contain no warnings or errors. The rendered pilot identifies Forward+ on an Apple M4 Pro. These final runs supersede the earlier results and the intermediate interior parse failure. Cargo validation is now local to the domain, and shared container dimensions live in `CargoBay`, avoiding the prior script dependency cycles.

The implementation agent additionally reports testing the rebuilt native application from `/tmp`: selecting Latch, clicking freight, and receiving 12 t in four cells; inspecting that physical crate with C; relaunching Latch and seeing five crew aboard/two away in the interior; and commanding a drone to a clicked destination and recalling it. The agent reports successful `codesign --verify --deep --strict` verification. Those native checks are attributed reports, while the suite/pilot logs above were read directly by the critic. No independent execution or build of this revision is claimed here.

## Drag-selection follow-up — 2026-09-27

This bounded review covers `SelectionBox`, coordinator input and group commands, HUD selection drawing/isolation, and `test_drag_selection`. The critic reviewed source only, launched no tests or game windows, and edited only this document. This pass does not change the earlier production-quality verdict.

Selection starts on an unhandled world press and defers an ordinary click until release. A drag selects visible, live friendly craft whose projected centers lie inside the rectangle and outside blocked HUD regions. Reverse rectangles, additive selection, and empty rectangles have explicit behavior. Selection membership changes preserve live courses. Escape, right-button cancellation, Stop, Recall, mode changes, and window focus loss clear unfinished gestures; orbit and selection own their mouse events. Camera following pauses during selection so its screen-space rectangle remains stable. Group movement, altitude confirmation, Stop, compatible work dispatch, and Recall address the selected craft, with the existing mothership-selected fleet-recall rule retained.

**Finding resolved:** independently clamping raw group berths could stack two drones at the sector rim. For example, a request at `(400, 12, 0)` produced two arrival points at `(258, 12, 0)`. `move_selected` now constrains the group center and keeps it 8 m inside the radial boundary before applying its ±4 m berth offsets. The reviewed regression repeats that request and requires separated endpoints inside the sector.

**Bounded source-review verdict:** no further concrete defect was identified in the reviewed drag-selection paths after this fix. Regression source covers order preservation, reverse/additive/empty selection, group movement and stopping, shared altitude, HUD-start isolation, orbit ownership, Recall, cancellation, and focus/mode transitions. Execution was still in progress when this section was written; no final pass count or independent runtime validation is claimed for this revision.

**Implementation-agent completion note:** the subsequent final suite reports 200 passed, 0 failed, with no warnings/errors. Native mouse testing selected three deployed craft by dragging and sent them to distinct arrival positions with one click; screenshots and the clean native log are recorded in `VALIDATION.md`. The rebuilt bundle passed signature verification. These are implementation-agent results, not independent critic execution.

## Historical: functional illustrated interior follow-up — 2026-09-27

This illustrated implementation was subsequently rejected by the user and replaced. Its image-backed deck and sprite findings are historical, not a description or acceptance of the current renderer. See the real-3D review below.

The critic inspected the user's Desktop reference, the generated interior/crew assets, `docs/screenshots/interior-live-v1.png` and `interior-live-v2.png`, and the crew/resource domain, checkpoint integration, room controls, and regression source. No tests, builds, or game windows were launched by the critic. Only this review document was edited.

**Visual finding:** the v2 illustrated deck closely preserves the reference's compact diagonal cutaway, varied compartments, dark hull, orange machinery, cyan bridge/medical equipment, and green planting beds. Its seven state-driven crew replace the painted-in people. Filtering removes the conspicuous sprite stippling seen in v1, and a persistent room outline links the selected facility to its controls. This is an interactive illustrated cutaway with 2D sprites, not a newly modeled 3D interior. The altered people, selection graphics, layout framing, and regenerated plate do not establish exact pixel parity. This feature review does not change the earlier rejection of an AAA-quality claim.

The nine facilities have identifiable domain effects and reachable controls:

| Facility | Reviewed function |
| --- | --- |
| Bridge | Captain staffing changes flight speed and nearby job-dispatch range; command/chart actions retain their return context. |
| Crew quarters | Assigned crew rest after travel, lowering fatigue and slowly recovering health when supplies permit. |
| Mess hall | Staffed cooking consumes crops and water to produce meals; ration policy trades meal use against fatigue. |
| Medbay | Medical coverage consumes finite medicine to heal actual crew; explicit first aid provides an emergency treatment path. |
| Engineering | Reactor generation, battery demand, water recycling, oxygen filtering, system condition and maintenance affect the simulation. |
| Fabrication | Staff/power-dependent timed recipes allocate parts and output capacity; cancellation preserves material accounting. |
| Storage | Quartermaster staffing reduces waste; physical ore can become parts atomically; cargo inspection and paid port resupply are available. |
| Hydroponics | Staffed growth spends available water to produce crops and proportional oxygen within storage limits. |
| Airlock | Security affects oxygen loss and impact protection; Latch deployment removes its two named crew from aboard staffing and blocks remote reassignment. |

The requested seven specialties have stable named crew records and individual assignments. Travel, injury, fatigue, absence and station capacity affect contribution. Life-support simulation runs in flight and the live interior; explicit pauses suspend it. Food, water, oxygen and battery reserves are shown in both modes, with shortage feedback during flight. Version-three checkpoints retain assignments, supplies and fabrication state, and version-two checkpoints receive coherent defaults without losing cargo. The old global watch is metadata rather than a second source of stacking bonuses.

**Review findings resolved in source:** resupply accounts for queued medicine before filling its locker; cancellation rejects an overflowing material refund; free port service can recover a broken reactor without a kit; a disabled reactor no longer incurs overdrive wear; gardening/healing cannot award output beyond their paid inputs; map/pause/cargo/dock transitions and their labels preserve context; selected rooms remain highlighted; facility status and dispatch-range labels describe their actual behavior; flight displays shortage telemetry. Corresponding domain and transition regressions were inspected.

**Bounded verdict:** no remaining concrete accounting, recovery, save, or screen-transition blocker was identified in this pass. The mid-walk reassignment defect is closed in the reviewed source: `InteriorState.assign` rejects a changed duty until arrival, preserves the existing route and assignment, and provides explicit feedback. Repeating the same duty remains idempotent. The regression checks that a rejected reassignment leaves both destination and previous station intact. This closes the identified sprite jump without granting staffing during travel.

**Final execution evidence read:** `docs/test-results/suite.log` reports **200 passed, 0 failed**. The source `interior-suite.log` and both packaged interior logs (`interior-packaged-suite.log`, `interior-packaged-rendered.log`) each report **80 passed, 0 failed**. Both `pilot-headless.log` and the Metal/Forward+ `pilot-rendered.log` finish in **209 simulated seconds**, reaching `mode=won`, three freight deliveries, 24 ferrite, three kills and 160 hull with `failures=[]`. All six final logs are free of warnings and errors. The earlier cleanup diagnostics no longer occur in these results. The implementation agent traced them to active dock/music WAV playback; the critic inspected the harness change, which calls the existing `audio.shutdown()` and waits 0.25 seconds before freeing the scene, consistent with the application's existing orderly quit path. The implementation agent also reports a clean verbose diagnostic run; that separate verbose log was not inspected here.

**Validation limits:** the packaged harness exercises game resources from the embedded PCK through automated input and assertions. It is not a completed hands-on desktop test: the final mouse/keyboard pass remains blocked by the locked Mac. The rebuilt bundle's packing log completes successfully. The inspected v2 image is native engine output at 1440×900; the implementation agent records the smaller standalone PCK capture at its actual **1152×720** dimensions. The recorded 120/119 FPS samples and 98 draw calls are short local observations, not sustained performance certification. These results were read from implementation-agent logs and validation records; no independent execution is claimed here. The bounded source/functionality verdict stands, while the illustrated-art, visual-fidelity and AAA limitations above remain unchanged.

## Current: modeled 3D interior follow-up — 2026-09-27

**Scope and method:** the critic compared the original Desktop reference with the updated `interior-3d-default.png`, `interior-3d-reverse.png`, `interior-3d-engineering.png` and `interior-3d-crew.png`. It inspected the supplied movement/door frame and extracted frames at 8, 12 and 17 seconds from the recorded engine output `interior-3d-motion.mp4`. Source review covered the modeled deck, articulated crew, route generation, crew state, assignments, picking and regression tests. The critic independently ran `tests/interior_3d_suite.gd` headlessly at 59 checks, then repeated it after the two return-route fixes: **61 passed, 0 failed**, process exit 0 and no logged warnings or errors. No game window, build or longer regression suite was launched by the critic in this pass.

**Actual 3D requirement:** the reviewed implementation uses an independent SubViewport 3D world, modeled floors, walls, armor and room equipment, seven articulated mesh actors, nine AnimationPlayer clips, and an orbit/pan/zoom camera. The reference plate and crew sprites do not supply the deck or people in this renderer. Reverse and close views expose actual fixture backs, wall thickness and limbs. The sampled recording shows Ivo advancing along the corridor, traversing an open pressure doorway and reaching quarters while the door subsequently closes. This establishes modeled motion and changing poses; sparse frame inspection does not certify polished animation at every instant.

**Reference comparison:** all nine room identities and their major fixtures are recognizable. The updated bed arrangement, larger armor panels, asymmetric reactor fittings, localized orange lighting, drill/circuit-work/vice/motor bench details and populated planting beds improve the reconstruction. The result remains a stylized low-poly interpretation: the reference has richer machinery density, more irregular surface construction, subtler materials and lighting, and more natural character proportions. Repeated wall treatments and simple equipment/character forms remain visible, especially close up. Exact geometric or pixel parity and AAA production quality are **not approved**.

**Movement and domain findings closed:** free orders now normalize the destination to the raised deck height; route initialization accounts for the current fractional simulation tick so paused orders and retargets begin at the visible position; ordinary station assignments reserve free destinations and retain existing residents' positions. The corresponding regressions exercise raised-bridge arrival, fractional-tick orders and checkpoint validation, crossing the next tick, mid-route reassignment, shared stations and departing colleagues. Navigation tests check all room-to-room approaches against obstacle footprints. Direct movement removes a worker's station contribution until reassignment and arrival; version-four saves retain world-space paths and positions, with legacy crew-capacity migration.

**Shared-berth finding closed:** ordinary assignments and fallback return routes now use the same `InteriorNavigation.work_position` berth selection. Returning tug crew invalidate their pre-departure deck position, choose an unoccupied work position and receive a distance-timed airlock route. The added regression assigns Mara beside Nia, deploys and returns the tug, and checks that their final positions remain distinct while Nia stays fixed. This regression passed in the critic's final independent 61-check run.

**Departure-during-transfer finding closed:** `CrewActor3D.sync` now rebuilds whenever the domain `transfer_path` is empty, regardless of a retained local route or unchanged station. The new regression departs during an active transfer, recalls the tug and verifies that the new persisted route begins at the airlock. The critic inspected this condition and independently verified the full **61/0** result. No concrete source-level movement finding remains open from this bounded review.

**Other execution evidence read:** current source logs report **200/0** for the broader suite and **80/0** for the existing interior suite. Both headless and rendered campaign logs reach `mode=won` in **209 simulated seconds**, with three freight deliveries, 24 ferrite, three kills, 160 hull and `failures=[]`. The final embedded-PCK 3D suites from `/tmp` report **61/0** headlessly and **61/0** with Metal rendering; the packaged interior suite reports **80/0**. All these inspected logs contain no warning or error. These are implementation-agent runs, distinct from the critic's independent 61-check execution.

**Native interaction follow-up:** the implementation agent completed a fresh launch of the final PCK from `/tmp` using a temporary external probe that logged delivered mouse/key events. The critic read `native-interior-3d-probe.log` and inspected `native-3d-manual-arrival.png` and `native-3d-duty-restored.png`. The screenshots show Nia at a manually ordered location with `AWAITING ORDERS` and zero hydroponics staffing, then back at the planting bed with `ON DUTY` and 100% staffing. The log records native click, right-click, wheel and Tab events without engine warnings/errors. The implementation agent reports successful pause/resume, roster selection, floor movement, station reassignment, wheel zoom, Tab to flight and back, and ordinary window close. This completes that bounded native interaction pass; the cause of the earlier window's intermittent input delivery remains unestablished. The critic did not perform these OS interactions independently, and this is not a broad human playtest.

**Current bounded verdict:** the modeled-interior and reviewed movement requirements pass the source, regression and supplied native-evidence assessment. No concrete movement finding remains open from this review. Sustained performance and all-platform input certification remain outside its scope; the visual-fidelity limits above are unchanged.

## Frontier travel and commissions follow-up — 2026-09-27

The independent critic reviewed the new network/domain, generated sectors, voyage commands and station UI, then inspected the network, commission board, Cinder and local-chart captures. This was source/visual review, with no independent test execution or file edits. It does not change the prior art/AAA verdict.

Three initial findings were fixed and rechecked:

| Finding | Correction |
| --- | --- |
| Tracking or abandoning a job in flight could checkpoint combat progress and allow reload at a safe station. | Flight-log changes remain in memory until a safe checkpoint. Only docked job actions write immediately. Version 5 also retains hull/shield/boost at jump arrivals and on Continue. |
| Skipping consumed freight altered later seeded asteroid geometry. | Each indexed freight rotation draw occurs before the consumed check; revisit tests compare all surviving asteroid seeds, radii and positions. |
| Finite depleted systems could continue offering impossible supply jobs. | Acceptance checks all remaining world stock plus onboard cargo, minus active commitments. Resolved patrols and decoded relays also cannot generate repeat-paid commissions. |

The final recheck reported no additional critical correctness or UX blocker in the reviewed scope. The critic read implementation-agent evidence of 135 frontier checks and 200 core checks passing, plus a no-teleport/grant/direct-kill pilot completing three commissions across four jumps in 170 simulated seconds. The later frontier suite adds seven local-chart course checks (142 total). Rendered playthrough/native input and final packaging were performed by the implementation agent, not inferred as independent critic execution. Native testing subsequently exposed a notification/toolbar overlap, corrected by moving/wrapping notices and keeping danger banners below them.

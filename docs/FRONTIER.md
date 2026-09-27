# Frontier travel and station commissions

Implemented 27 September 2026 in Godot 4.7. This expands the existing fleet, cargo and crew game. It does not replace the original Meridian story or interior.

## Play loop

1. Approach a station and hold E. All drones and the tug must return before docking.
2. Open Station Commissions (L), choose up to three jobs, and fit the ship using station services.
3. Open the star network (J). Select a destination; the graph highlights a shortest path. Jump to the next system from a dock, station approach or transit relay.
4. In the destination, M opens the local chart; clicking a contact plots a mothership course. The flight HUD follows the tracked commission. L changes the tracked job.
5. Dispatch the existing drones/tug for physical cargo, fight the named patrol, or approach a survey relay and hold E. Ion volumes make altitude and timing useful.
6. Return to the issuing station and deliver. Supply jobs consume pods/containers; bounty and survey data remain recorded. Rewards buy the existing ship and interior improvements.

Travel is available at the beginning. There is no need to complete the three-act Meridian story first. Completing that story still opens its original corridor and ending; continuing exploration retains the new network.

## Domain and ownership

| Owner | Responsibility |
| --- | --- |
| `Expedition` | Aggregate for credits, physical cargo, original story, crew, network and contract ledger. |
| `StarNetwork` | Nine named systems, connected lanes, risk, shortest routes, seeded layout and patrol specifications, current/visited/surveyed state. Scene-free. |
| `StationContracts` | Four canonical offers per office rotation; three active contracts overall; progress, availability, consumption, once-only payment, abandoned/paid states. Scene-free. |
| `CargoBay` | Exact cell placement, reservations, mass and atomic removal of ore/whole freight containers. |
| `Sector` → `FrontierSector` | Real inheritance: share collision/contact queries, gate construction and background geometry; specialize generated frontier population and hazard handling. The home sector retains authored IDs and coordinates. |
| `Ship` → `PirateShip` | Shared damage/shields/weapons with parameterized interceptor, raider and gunship behavior. Separate empty subclasses for data-only roles would add no useful behavior. |
| `SpaceEntity` → `SurveyBeacon`, `IonStorm` | Spatial contacts and procedural presentation. Relay decoding belongs to the coordinator; ion timing and volume membership belong to the hazard. |
| `VoyageController` | Application commands, travel guards, four-second departure/transition/arrival, station job actions and mission navigation. Connects scenes to the domain. |
| `VoyageUI` | Scale-aware star chart, offers, active log and transition presentation; invokes application commands, never awards rewards itself. |

## Generation and persistence

The lane graph, system names and broad biome/risk identities are authored for route readability. Each new game rolls a 31-bit seed. Per-system seeded generators place stations, wrecks, ore, survey relays and threats; enemy roles/altitudes vary by risk and seed. Presentation uses different nebula/planet tints. This is bounded procedural population, not arbitrary solar-system simulation.

Home resources keep legacy IDs (`ore_0`, `freight_0`, `raider_0`). Frontier IDs include their system (`1/ore/0`, `1/freight/0`, `1/hostile/0`). Generated geometry cannot depend on which entities remain: freight's rotation RNG draw occurs even for consumed containers. Rebuilding thus preserves surviving transforms and all rock geometry.

Nine offices each save only a rotation number and four statuses. Canonical target, amount and reward derive from the voyage seed/office/rotation/slot; they are not arbitrary trusted values from a save. Payment changes an active offer to paid before future calls can repeat it. A patrol or survey completed before accepting a new offer cannot yield another commission for the same resolved target. Supply availability accounts for recoverable universe stock and other active commitments, preventing new impossible jobs after depletion.

Version 5 adds the network, offices, tracked contract, completed count and checkpoint hull/shield/boost. Versions 1–4 still migrate to a fresh home network while retaining their existing cargo, economy, story and crew state. Invalid ranges, office states, excessive active contracts, malformed tracked IDs, destroyed-ship checkpoints and invalid network flags are rejected.

Dock transactions and completed jumps save atomically. A flight-log track/abandon action changes in-memory state and saves at the next safe checkpoint; it cannot save cargo/kills during combat and then reload at a safe station. Jump arrival preserves hull/shield/boost and stores their ratios, so Continue is not a repair shortcut. The arrival checkpoint intentionally resumes in that system's safe station approach, with all work craft aboard.

## Threats and counterplay

- Interceptors: 52 hull, 13 m/s, close orbit, 6 damage at 0.8 s interval.
- Raiders: 80 hull, 9 m/s, wider orbit, 12 damage at 1.45 s interval.
- Gunships: 145 hull plus 40 shield, 5 m/s, 34 m preferred range, 22 damage at 2.5 s interval.
- Ion shear: radius 20 m, half-height 9 m, seven seconds quiet, three charging, four discharging; 8 damage/second during discharge. The visible cylinder marks the actual volume. It affects mothership/pirates, while support craft keep the existing noncombat lifecycle.

Arrival areas lie beyond patrol activation. Docking, jumping and decoding require breaking hostile contact. Fields can be avoided horizontally or vertically using G and Shift. M chart marks their locations. Interior/cargo/log/chart screens freeze combat and life support, consistent with the original management-mode design; the interior has its separate explicit simulation pause.

## Deliberate limits

Nine finite systems, four job types, three enemy roles, one hazard family, fixed station services and the existing upgrades are implemented. No generated dialog tree, faction reputation unlocks, escort AI, courier inventory type, procedural quest language, fuel market or endlessly respawning universe was added. The completion counter is a record of successful commissions; no unimplemented reputation reward is implied. When the frontier is exhausted, a new expedition changes the seed. Visuals remain stylized procedural geometry; exact reference fidelity/AAA quality is not asserted.

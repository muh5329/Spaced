# Domain: the Wayfarer's working expedition

## Boundary and vocabulary

Persistent rules live in `Expedition`, which owns a `CargoBay` and an `InteriorState`. Scene objects cannot award progress simply by approaching a resource. The campaign is one authored belt with salvage, mining, trade, combat and a final recovery.

| Term | Meaning / owner |
| --- | --- |
| Expedition | Credits, delivered resource totals, contracts, upgrades, outcomes, crew/survival aggregate and checkpoint data |
| Cargo bay | Fixed 4×5 grid per deck, stored rectangular items, inbound reservations and mass limit |
| Cargo item | Stable ID, kind, amount, X/Z/deck placement, width and length |
| Reservation | Transient allocation owned by a work craft; excludes competing cargo before departure |
| Command ship | Selected order recipient with a 3D navigator, velocity and attitude |
| Wayfarer | Mothership, weapon platform and recovery airlock |
| Mole 01 / 02 | Independent mining drones; one 1×1 pod of at most 4 t each |
| Latch | Salvage tug carrying Mara Voss (pilot) and Ivo Renn (rigger); one attached freight/core load |
| Work site | Ore deposit or recoverable freight; work progress belongs to the assigned craft |
| Ore extraction | Removes material from a deposit into a drone's pending payload; does not yet increment delivered ore |
| Salvage attachment | Secures and claims a container for towing; does not award cargo or progress |
| Delivery | Completed physical return and unload, converting a reservation into a stored item atomically |
| Crew away | Two while Latch is deployed, zero when berthed; seven total crew |
| Move preview | Uncommitted horizontal footprint and altitude; confirmation replaces orders for every selected craft |
| Selection box | Transient screen rectangle; selects deployed friendly craft without changing live orders |
| Camera orbit | Viewpoint intent independent from ship orders |
| Checkpoint | Versioned persistent state written only with all work craft recovered |

## Cargo geometry and constraints

A cell is 0.58 world units wide and long. Each fixed deck has four columns and five rows. Freight occupies 2×2 cells and weighs 12 t; ore uses a 1×1 pod holding 1–4 t; the mission core occupies 2×1 and weighs 8 t. Cargo rack upgrades unlock one, two or three decks with structural mass caps of 80/120/180 t. Higher racks occupy the existing hold volume; they do not magically enlarge the hull.

The same `CargoContainerModel` is used for floating freight, the drone's pod and the actual mothership hold, with identical dimensions. The standalone C view magnifies the real compartment and draws every occupied and reserved rectangle. The modeled storage room opens that view; its fixed supply containers do not duplicate or allocate trade cargo.

Placement is deterministic first fit without rotation: deck, row, column. A reservation counts against both geometry and mass. Partial ore still occupies one whole pod cell. Every freight container remains a sealed 12 t rectangle; partial freight/core delivery is invalid. Failed allocation never removes cargo or spends resources. Removing cargo through a station sale frees its exact cells and retains the core.

## Invariants

- Cargo amount, money, counters and upgrade levels are bounded; cargo must satisfy both mass and nonoverlapping geometry.
- Stored item IDs are unique. A recovered freight ID and defeated raider ID can be credited only once.
- Delivery kind must match its reservation, amount must fit it, and the source must be identified. Reject before any counter or manifest mutation.
- Mining only credits ore and contract progress after unloading. Freight remains a visible claimed world object until delivery completes.
- Canceling an empty job releases its reservation. A loaded worker retains both payload and reservation when stopped, redirected or recalled.
- Concurrent drone jobs cannot reserve the same cells. A sealed freight target has one claimant.
- Recall is idempotent during return/unload. Holding E cannot restart the unloading clock.
- Recovery points are constrained to the same flight cylinder used by navigation, including altitude and horizontal limits.
- Transfer requires a nearby stationary mothership. Moving the Wayfarer makes the craft resume its return approach.
- All deployed craft and crew must be recovered before docking, winning or writing a checkpoint.
- Management screens suspend the sector, including work progress, tow motion and drones. In-flight selection changes preserve other craft's live orders.
- Manual move replaces the selected worker's job; Stop retains a load; Recall returns it. A fresh move preview cannot change an order before confirmation.
- Selection, live orders, reservations, payloads in transit and crew deployment are transient. Dock checkpoints contain none of them.
- Shield damage precedes hull damage. Death pays a bounty at most once. Only mothership attack orders authorize automatic fire.
- Altitude is actual position for navigation, pursuit, weapons, interaction reach and picking; the cylinder is 258 m radius, −60…+60 m altitude.
- Only contract gates advance acts; selling delivered resources does not erase cumulative progress.

## Work lifecycle

```text
DOCKED → launch → IDLE
IDLE → reserve bay / accept work → OUTBOUND → WORKING
WORKING → extract pod or attach tow → RETURNING → UNLOADING
UNLOADING → commit delivery → DOCKED
Mining only: successful delivery → reserve next pod → OUTBOUND

Any deployed phase → R → RETURNING
Manual course or X → IDLE (retain any existing load)
Pause / chart / interior / cargo view → freeze, retain phase
```

The tug reduces cruise speed while loaded and follows obstacle routes with larger clearance. Its cargo follows behind a visible cable and enters the airlock during transfer. This is deterministic kinematic towing rather than a rigid-body rope solver. Workers are operational craft; this scope has no separate worker-combat damage/replacement economy.

## Campaign and persistence

| Act | Gate | Result |
| --- | --- | --- |
| 0 | Deliver 3 freight and 24 t ore; turn in at Meridian | 650 CR and raiders |
| 1 | Destroy 3 unique raiders; turn in at Meridian | 90 CR each + 1,100 CR; core unlocks |
| 2 | Latch delivers core; fleet recovered; charge beacon | Persistent victory and postgame exploration |

Initial credits: 200. Ore sells for 8 CR/t, freight for 12 CR/t. Two upgrade tiers cost 240/520 CR. First-contract cargo uses 18 cells and 60 t, yielding 624 CR on sale. Repairs are free and boost recharges, preventing permanent stranding. The mission core now needs physical cargo capacity.

Version 4 snapshots add world-space crew position and route persistence to the version 3 individual interior aggregate and version 2 exact item rectangles and verify numeric cargo totals against them. Malformed/overlapping/out-of-bounds layouts fail closed. Version 1 migration packs the prior numeric load and grants sufficient rack decks if its formerly legal load needs extra physical space. Reservations are never serialized. On death or quit, work after the last checkpoint is lost consistently with other in-flight progress; restoring recreates the prior resources, cargo and all workers aboard.

## Useful inheritance and composition

```text
SpaceEntity : Node3D
├── Ship
│   ├── CommandShip
│   │   ├── PlayerShip
│   │   └── SupportCraft
│   │       ├── MiningDrone
│   │       └── SalvageTug
│   └── PirateShip
└── Harvestable
    ├── OreAsteroid
    └── SalvageCache
```

`Ship` shares damage, shields, weapons and attitude. `CommandShip` shares selection, route commands and steering. `SupportCraft` shares launch, return, reservation and delivery rules; workers specialize accepted targets, extraction and payload presentation. `Harvestable` only defines work-site data; there is no direct collect/work API on resources.

`FleetOperations` builds and dispatches the three workers and accounts for deployed crew. `FlightNavigator`, `MoveOrderPreview`, `SelectionBox`, `TacticalCamera` and `WorldPicker` are focused collaborators. `IndustrialDetail` and the small presentation models share fittings and cargo dimensions. The coordinator connects commands and transitions; UI reads the resulting state. No generic job language, fleet ECS, branching crafting tree or multiplayer layer is introduced.

## Individual crew and interior resources

`InteriorState : RefCounted` owns seven `CrewMember : RefCounted` instances, nine station records, bounded stores, machine condition, ration/reactor settings and a small fabrication queue. It uses one-second fixed steps, independent of frame subdivision. `CrewMember` owns stable identity, native specialty, assigned/previous station, remaining travel/duration, an optional world-space position and route, off-station status, health, fatigue and transient deployment. A uniform crew type is sufficient: roles are data rather than seven empty subclasses.

- A station change removes previous output immediately. The 3D controller supplies a walkable route and a duration from distance / 1.55 m/s. A new order starts at the visible world position, including mid-walk reassignment. Legacy domain-only transfers retain a six-second fallback until a world route is available. A route reserves a distinct destination work position; existing residents do not move when someone joins or leaves.
- Direct floor orders set `off_station`: the person retains their assignment identity but contributes no work and cannot remotely rest or receive accelerated bedside care. Reassigning a station routes them back to equipment.
- Commands include the current fractional tick in remaining travel, so a command issued between fixed ticks does not count that earlier fraction as elapsed movement. Rendering samples the same path between ticks. Checkpoints retain the accumulator and route so partial travel survives restoration.
- A specialist's base efficiency is 100%; a cross-trained crew member's is 60%. Fatigue and health scale it. Walking, away or incapacitated people produce nothing. At health ≤15, only rest/medical assignments are allowed.
- Work stations have two assignment slots; quarters have three bed berths. Away crew retain their home slots, so return cannot overbook a station. Latch uses exactly Mara and Ivo; they cannot be reassigned until aboard.
- Enabled equipment creates electrical demand. Reactor condition, its mode and engineering staffing determine generation; the battery absorbs the balance. Empty batteries shed load in explicit life-support priority order. An operational reactor can restart without battery energy.
- All seven people consume expedition provisions, including Latch's crew. Crops cost actual water; meal production costs crops/water; medical healing costs actual fractional medicine. Power, operator availability, condition and store capacity constrain production. No negative reserves or overflow.
- Fabrication allocates parts once and reserves finite output space, including queued output when resupplying. Cancellation refunds once; a full parts locker rejects cancellation rather than dropping materials. No offline-clock catch-up occurs.
- Station wear and impacts lower condition. Engineers maintain machines; kits restore condition; filters restore life-support efficiency. Dock service provides reactor/medical recovery even with no kits, medicine or stored power.
- Food/water shortages and low oxygen injure people. Injury/fatigue reduce performance. Crew at zero health are incapacitated, not removed from the roster; emergency care and port stabilization permit recovery.
- Supply lockers have separate fixed capacities from the trade cargo grid. Refining four tonnes of ore consumes real stored pods before adding four spare parts. Delivered mission progress and other craft's reservations stay intact.

The resource clock runs during flight and interior management. The interior's PAUSE SYSTEMS affects only its management clock; resuming flight resumes life support. Cargo/chart/pause/settings freeze both simulation contexts. Exterior workers freeze while the cutaway is open. Going from a docked interior to cargo/chart and back preserves dock origin; launching/recalling workers explicitly undocks. New/load/retry resets transient modal state.

Version 4 includes all supplies, station switches/condition, crew identity/duties/health/fatigue/travel, queue/progress, filter, ration/reactor mode and fixed-tick accumulator. Invalid or duplicate people, unknown stations/recipes, nonfinite/out-of-range numbers, overstaffing and overbooked output reject a snapshot. Version 1/2 migrations add initial crew and stores. The old `crew_role` string remains legacy checkpoint metadata and does not supply a global watch bonus.

Version 3 migration retains the first three assigned sleepers and returns additional sleepers to available specialist/other duty slots without changing health, fatigue, supplies or cargo. World routes validate finite bounded 3D coordinates and at most 256 points. The domain owns saved travel; `InteriorNavigation` owns geometry-specific route construction. Static furniture and walls constrain pathfinding; crew do not currently perform dynamic avoidance of each other.

## Frontier extension (save version 5)

`Expedition` now composes `StarNetwork` and `StationContracts`. `StarNetwork` owns route topology, immutable seeded sector/patrol descriptions and exploration state. `StationContracts` owns canonical offers, the three-contract limit, progress, cargo-consuming fulfillment and once-only rewards. The scene-derived `FrontierSector` specializes `Sector` while retaining its collision/contact implementation. `VoyageController` coordinates safe transition guards and station commands; `VoyageUI` only presents state. `IonStorm` owns timed spatial discharge, and `SurveyBeacon` is a normal addressable 3D contact.

Contracts distinguish historical achievements (specific kills/decoded relays) from deliverable stock (actual ore/freight still aboard). Supply acceptance checks finite uncommitted recoverable stock. Original Choir progress counts its three authored enemy IDs, so unrelated frontier kills cannot skip the story. See `FRONTIER.md` for the full rules, schema and ownership table.

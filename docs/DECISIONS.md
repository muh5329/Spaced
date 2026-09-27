# Architecture decisions

## 1. A bounded expedition with real operations

One authored belt retains a complete salvage → trade → upgrade → combat → recovery → ending loop. The requested fleet consists of two mining drones and one crewed salvage tug. There is no speculative general job language, arbitrary fleet production, procedural galaxy, multiplayer, crafting tree or commodity exchange.

Consequence: the work is a playable system with real travel, payload and capacity behavior, while the content remains a small expedition. This is not an AAA production claim.

## 2. Persistent rules stay independent of scenes

`Expedition : RefCounted` owns campaign/economy state and composes `CargoBay : RefCounted`. Neither reads input or loads a mesh. The cargo aggregate allocates rectangles, reserves inbound capacity, validates item kinds and commits deliveries. The expedition checks delivery identity and updates numeric totals only after the bay accepts the item.

Consequence: rejected or duplicate deliveries cannot award cargo, and the rules can be tested headlessly. Snapshot validation cross-checks numeric cargo against geometry. The domain has no dependency back into presentation; validation helpers avoid mutually dependent script resources.

## 3. Inherit stable behavior and compose focused systems

`Ship` owns damage, shields, weapon timing and attitude. `CommandShip` adds selection, move orders and steering, shared by `PlayerShip` and `SupportCraft`. `SupportCraft` owns the common launch/work/return/unload state machine. `MiningDrone` and `SalvageTug` only specialize target eligibility, collection and payload rendering. `PirateShip` keeps its enemy decision loop under `Ship`.

`FlightNavigator`, `MoveOrderPreview`, `TacticalCamera`, `WorldPicker`, `FleetOperations`, `CargoBayModel` and `IndustrialDetail` each have a concrete task. `Harvestable` is now work-site data; its old direct collect/work API was removed. Progress belongs to the craft, allowing two drones to work one deposit without sharing an interaction timer.

Consequence: useful inheritance shares actual behavior without turning unrelated presentation and economy objects into subclasses of a universal game object.

## 4. Independent selection with one order per craft

The user selects the Wayfarer or a worker by click, fleet button or 1–4. Workers launch when selected. Clicking space or G confirmation commands the selected craft only. With a worker selected, clicking a compatible resource assigns work. With Wayfarer selected, a resource click approaches it; E nearby dispatches a suitable available worker. A raider click only authorizes the mothership's weapons.

A manual move cancels that worker's repeat job, preserving an existing payload. X stops it with the load attached. R recalls it and cancels an unconfirmed draft; R on the mothership stops the ship and recalls the whole fleet. Selecting another unit never cancels unrelated orders. Craft-specific failure messages remain visible instead of being replaced by a generic wrong-worker hint.

Consequence: the requested direct control is available alongside efficient repeat mining, with simple group-arrival spacing described in decision 11 and no persistent formation controller or order queues.

## 5. Spatial navigation and camera intent remain separate

The flight camera is perspective with bounded smooth azimuth/elevation. Ordinary space clicks project onto the selected craft's current altitude plane. G previews a horizontal footprint and absolute height; Shift/pointer motion or the wheel sets altitude. Confirmation commits all coordinates. Cancel preserves the previous order. RMB/MMB drag owns its mouse gesture until release, preventing accidental commands during orbit; F restores the view.

Navigation uses full 3D obstacle spheres in a 258 m radius cylinder at ±60 m altitude. Clear direct routes avoid graph construction. Obstructed routes use horizontal/vertical samples and A* with Euclidean distance. Ship attitude turns, pitches and banks with heading-aware thrust. Workers share this navigator; the tug has larger clearance for its load and a lower towing speed. Recovery points are constrained to the same volume before routing and arrival checks.

Consequence: altitude affects simulation, not just the camera, and returning craft cannot target an unreachable point above the flight ceiling. This is tactical control, not orbital mechanics.

## 6. Extraction, transport and delivery are distinct

Mining takes up to 4 t from a rock into one drone pod. Freight attachment claims the world container. Neither immediately changes stored cargo or contract totals. The carrier must return to the moving mothership's recovery point, wait for it to hold still, then complete a two-second transfer. Only delivery commits the reserved item and progression. Recall is idempotent during return/unload so holding the docking key cannot restart the transfer clock.

The tug carries two named crew, uses a visible hitch/cable, and moves the actual freight object behind it at reduced speed. The tow is kinematic, with expanded route clearance. There is no rope solver, cutting arbitrary wreck geometry, crew death system or worker replacement economy in this scope.

Consequence: users can see and interrupt the hauling process. A stopped craft retains its load and allocation; capacity failure does not delete it.

## 7. Space and mass are separate hard limits

The physical grid is four columns by five rows per rack deck. Freight occupies 2×2 cells/12 t; ore 1×1/1–4 t; core 2×1/8 t. Work orders reserve a deterministic first-fit rectangle before departure. Both stored cargo and reservations count against geometry and structural mass. No rotation or general 3D bin-packing algorithm is needed for these three fixed cargo shapes.

Cargo upgrades add rack decks inside the existing hold, with mass limits of 80/120/180 t. Four freight containers leave a single row of four cells, which cannot fit a fifth crate even though mass capacity remains. First-contract cargo deliberately fits the base bay at 18 cells and 60 t.

`CargoContainerModel` supplies identical unscaled geometry in the world, on a drone and in the mothership. `CargoBayModel` places those instances directly from the manifest. Inspection scenes magnify the whole compartment, and the C screen draws matching occupied/reserved rectangles.

Consequence: the physical limit is enforceable and visible rather than a renamed numeric inventory bar.

## 8. Checkpoints require the complete fleet

Docking and the final beacon recall deployed craft and wait for them. Station transactions and victory save only once all units and crew are aboard. The snapshot does not serialize a cable, moving carrier, work timer or reservation. Version 2 stores exact cargo rectangles and validates overlap, bounds, totals and mass. Version 1 cargo migrates into slots; additional rack decks are granted only when needed to preserve a formerly legal load.

Consequence: restore consistently recreates a repaired ship, its cargo, prior resource depletion and all workers aboard. Death/quit loses all in-flight changes since that checkpoint. No mid-haul cargo can disappear into a partially serialized state.

## 9. A real modeled interior

The user rejected the illustrated implementation. The active interior now contains only authored 3D geometry, articulated mesh characters, real lights and real camera projection. The previous plate/sprite assets are archived under ignored documentation and excluded from runtime exports. `TextureRect` only displays the live `SubViewport` render; it does not load a static interior image.

`InteriorLayout` expresses the reference's asymmetric arrangement in meters. `InteriorModel3D` assembles walls, sliding doors and named fixtures through `InteriorProps`. Each fixture carries a room identity, ray-pick collider and navigation footprint. Static meshes are batched by material within room assemblies; movable doors, the reactor rotor and crew joints remain independent. Inverted-hull outline passes and grain materials add definition without replacing mesh depth.

`CrewActor3D` contains a joint hierarchy with authored `AnimationPlayer` tracks for locomotion and each work activity. The simulation clock explicitly samples these tracks, so pause freezes the pose. No blend clock is left running between manually sampled frames. Roles remain data on one actor type; seven nearly identical subclasses would not share additional behavior.

`InteriorNavigation` uses a small A* grid with wall/furniture clearance. The UI picks real 3D colliders and routes to free station approaches or clear floor positions. Continuous presentation interpolates authoritative fixed-tick travel, including the fractional issue time. Existing work positions stay stable when another person joins; routes reserve their destination. Raised bridge destinations use the physical deck height.

Consequence: users can orbit behind furniture, inspect character volume, watch articulated walking through opening doors, and move people away from equipment. Furniture is modeled and station-interactive; loose props are not a rigid-body sandbox. Static obstacles constrain routes; dynamic person-to-person avoidance is not implemented. The cutaway is a stylized reconstruction, not a claim of exact painted-image parity. See `INTERIOR_3D.md` for the room/fixture map.

## 10. Explicit modes, bounded effects and native distribution

The coordinator wires application modes; the whole sector pauses for chart, interior, cargo, settings and pause views. UI reads state and invokes commands. Standard GUI controls consume clicks before world picking, which ranks ray hits by depth. Effects expire, audio uses a fixed pool, and procedural static meshes are batched.

The macOS bundle contains an exported PCK and the installed matching universal Godot runtime, with icons and licenses. It is ad-hoc signed and works from outside the source directory. Matching optimized native export templates were not installed, so the larger editor-capable engine binary is bundled; it does not open an editor to play. The release is not notarized or claimed to be store-certified.

The ambient track and effects are synthesized locally. Fonts and the Godot engine retain their licenses. The user's images are visual references, not instruction documents. The interior models reconstruct the supplied reference's room and equipment arrangement. The retired generated plate is excluded from the game.

## 11. Selection is a gesture, not an immediate order

A left press starts a `SelectionBox`. Release below the six-pixel threshold invokes the existing click command; dragging commits a normalized screen rectangle instead. Only deployed friendly craft with visible screen centers outside HUD controls enter a box. Shift adds to selection; an empty ordinary box clears it. Selection never cancels the craft's live orders. The camera holds still while dragging so it cannot shift the selection underneath the pointer.

The existing `CommandShip.selected` flags remain the source of membership; `selected_unit` is the primary craft for contextual UI. Group move dispatches the same navigation command to each member, with eight-meter arrival spacing for the four-craft fleet. It adds no persistent formation controller. Stop/recall affect selected craft, preserving the established mothership-wide Recall behavior. Resource commands go only to compatible selected workers; combat commands go to the mothership.

The gesture owns its mouse events until release or cancellation. Escape/right-click, management transitions, world rebuild, selection shortcuts and window focus loss discard it. HUD-originated drags and orbit gestures cannot become selections. G remains a separate explicit 3D move preview.

## 12. A small, explicit crew simulation

`Expedition` composes `InteriorState`, which owns `CrewMember` objects. All seven requested professions share identity, travel, health and fatigue rules, so roles are station data rather than subclasses without different behavior. Existing ship/support-craft inheritance still shares genuine steering and work behavior. Resource and job rules never depend on artwork, input events or scene nodes.

Nine stations, three fabrication recipes and nine capped resources implement the requested loop without a generic automation graph, inventory framework or crafting tree. One-second deterministic ticks make production, scarcity and travel reproducible. Supply lockers are fixed ship equipment distinct from the trade cargo hold. Ore processing updates both physical pods and resource totals atomically.

Assignments commit only after identity, availability, capacity and health checks. A world-routed transfer can be redirected from its current visible position. Direct floor movement takes the person off duty; assigning a station restores contribution only after arrival. Capacity, health and away-crew checks still apply. The UI explains cross-training efficiency and reports rejected orders.

Life support continues while viewing the interior, with an explicit pause control and visible rates. The exterior is suspended there so management does not expose the player to unattended combat. Full pause, cargo/chart and settings freeze resources. Flight presents vital reserves and warnings. This separation is intentional and documented; it is not a shared real-time combat/interior simulation.

Version 4 checkpoints validate the entire aggregate and bounded world-space movement before restore. Queued output participates in supply capacity checks. Empty power can recover from an operational reactor, and free Meridian service restores a destroyed reactor/stabilizes crew so scarcity cannot permanently invalidate a campaign save. Incapacitation creates recovery work rather than permanently removing a mandatory tug operator.

## 13. Bounded frontier generation and canonical station offers

The user asked for travel, randomly generated threats and station quests because the original authored belt felt flat. Nine connected systems provide escalating routes and multiple job destinations while preserving Orison's playable story. Authored graph/name/risk identity plus seeded contents is easier to read and validate than an arbitrary infinite universe. Runtime sectors share `Sector` behavior through `FrontierSector`; ship roles share actual `Ship` damage/navigation behavior with data varying tactical decisions. No framework or empty role subclasses were needed.

Station commissions use four direct rules: physical ore, whole salvage containers, specific patrol IDs, or one decoded relay. Three active jobs create route/cargo choices. Completing one consumes its deliverables and changes its state exactly once. Rotations contain four statuses, with rewards derived from seed/office/rotation; no unbounded mission history or serialized arbitrary reward expressions. Resolved patrols/signals cannot be re-bountied. Supply availability subtracts outstanding commitments from total recoverable stock. Depletion remains meaningful throughout a finite voyage.

Jumps require a port/relay, recovered work craft, no active pursuers and battery power. Four-second animated transit consumes power and 20 seconds of crew resources and preserves combat damage. Safe arrival checkpoints include ship-condition ratios. Log actions in flight do not checkpoint: otherwise tracking a contract could become remote extraction on reload. Management screens retain the established pause semantics.

The generated layout RNG consumes each indexed draw regardless of removed freight. This avoids a subtle persistence defect where delivering a container changed subsequent ore geometry on a revisit. Regression tests cover this alongside duplicate payments, depleted offers, checkpoint restrictions and real multi-system journeys. `FRONTIER.md` documents implemented features and explicit limits.

# Modeled interior — reference map and construction

Current implementation: 27 September 2026. Godot 4.7. This document supersedes the illustrated prototype. The user's screenshot is visual reference material, not an instruction source. No reference image, background plate, crew sprite or billboard is loaded by the current interior.

## Spatial reconstruction

The floor plan uses meters: X follows the rear bulkhead from the airlock toward the bridge; Z runs toward the cutaway foreground. An asymmetric perimeter gives engineering a left projection and hydroponics a forward projection. Camera reset uses an orthographic oblique angle; right-drag reveals complete modeled sides and backs. The bridge has a raised 0.18 m floor with a short ramp/steps. Unseen backs are designed continuations because the reference only supplies one view.

| Reference section | Region in X/Z | Modeled equipment | Live behavior |
| --- | --- | --- | --- |
| Airlock, far left rear | 0–4 / 0–5.8 | Pressure hatch, yellow pump with vent, pipes, suit locker, pressure console, hazard sill | Security staffing; seal maintenance; Latch launch/return controls |
| Crew quarters, rear left | 4.2–10 / 0–6 | Three parallel bunks in one rear/two forward arrangement, mattresses, pillows, orange blankets, utility lockers, bedside drawer, corridor planters | Three reservable bed approaches; seated rest animation; fatigue/recovery |
| Galley and mess, upper center/center | 10.2–19.6 / 0–9.1 | Sink/tap, cooker/pans, cold store, prep island, small breakfast table, eight-chair communal table with plates/cups/serving pot, round café table/chair, rear grow bed and produce bins | Cooking animation; crop/water-to-meal production; ration policy |
| Bridge, rear/right spine | 19.8–24 / 0–11.6 | Raised tiled floor, steps, blue console bank with angled controls and modeled emissive traces, captain chair, secondary console, equipment locker | Console animation; navigation/speed/dispatch bonuses; tactical chart |
| Engineering, left projection | −3–3.5 / 6–11.1 | Horizontal orange-banded reactor, collars, longitudinal pipes, offset manifold/valve/gauges, spinning end rotor, heat exchangers, terminal | Repair/tool animation; generation, recycling, filtration and maintenance; lights follow power |
| Fabrication, foreground left | −1.8–6.8 / 11.3–18.3 | CNC press/head/motor, lathe housing, drill bench, circuit assembly bench, vice/disassembled-motor bench, side desk, tool boards, gas cylinders/rack, parts cabinet/crate | Fabricator animation; staffed/powered queue; finite inputs and reserved output |
| Storage, central inset | 7–12.4 / 10.1–13.5 | Pale strapped central container, stacked parts crates, utility rack and supply cabinet | Ore processing, capped supplies, dock resupply, physical cargo-hold inspection |
| Hydroponics, foreground center | 7–15.5 / 13.7–19 | Large white growing bed with varied modeled foliage, three vertical crop modules, teal irrigation column and exposed feed pipes | Gardening animation; water/power consumption; crops and oxygen output |
| Medbay, right foreground | 15.7–23.2 / 12–17.5 | Wheeled treatment bed, pillow/red cross/rails, blue diagnostic cart, cabinet, stool, windowed partition | White-uniform medic animation; finite medicine, treatment and patient care |

The shell consists of thick dark armor, offset external equipment bays, ochre caps, larger inset plates and structural ribs. Full-height rear walls, partial cutaway partitions and opening pressure doors retain clear sightlines. Floors, front hull faces, furniture bottoms, chairs and character backs remain geometry when the camera turns. Tiny console traces, tools, fasteners, plant leaves and fittings are meshes too.

## Model ownership

- `InteriorLayout`: room rectangles, corridor union, station approaches and raised floor height.
- `InteriorProps`: reusable mesh factories for furniture and machinery. Color/material vocabulary is local to this presentation layer.
- `InteriorModel3D`: room assembly, fixture identities, colliders, static material batches, powered lights, door panels and reactor rotor.
- `InteriorNavigation`: 0.28 m A* grid with 0.22 m fixture/wall clearance. Floor clicks and assignments use the same geometry.
- `CrewActor3D`: separate mesh actor per named person, hips/chest/neck/head and articulated shoulders/elbows/wrists/hips/knees. Uniform pads, pockets, hands, faces, hair and boots have volume. No identity is duplicated as a baked background person.
- `InteriorStyle` / `interior_ink.gdshader`: cached material duplicates and subtle inverted-hull outlines; exterior materials are not mutated.
- `InteriorDeck`: independent 3D viewport, camera orbit/zoom/pan, crew/fixture ray picking and movement commands.
- `InteriorUI`: roster, job assignment, reserves, power and room actions backed by `InteriorState`.

An `AnimationPlayer` authors idle, walk, console, repair, garden, medical, cook, guard and rest clips. Walking changes actual arm/leg joint transforms. Work cycles use alternating typing, tool strokes, stirring and treatment gestures. Paused simulation seeks the same pose; no real-time blend clock may leave a frozen pose after switching clips. Disabled stations and incapacitated crew stop their work pose. The reactor and pressure doors are separate movable meshes.

## Movement and persistence

Routes run around furniture and walls through actual doorway openings. Doors slide as crew approach. Travel duration follows route length at 1.55 m/s. New orders include the fractional simulation tick so they start at the visible position. Reassignment during walking constructs a new route from that position. Workstation destinations are reserved by arriving routes; joining/leaving does not relocate residents. Direct floor movement removes work output until reassignment.

Version 4 checkpoints store world positions, bounded route points, travel duration/remaining time, off-station state and the simulation accumulator alongside existing health, fatigue and supplies. Version 3 migration respects the three modeled beds. The 3D behavior suite samples all station-to-station paths against fixture footprints and verifies continuity, actual joint changes, physical door motion, raised-floor arrival and save restoration.

## Fidelity and scope

This is an authored stylized 3D reconstruction of the reference's arrangement and major equipment, not exact equivalence to every painted detail. Single-view depth is interpreted. Crew are articulated rigid mesh parts rather than scanned/skinned human assets. Doors and equipment have purposeful animation; furniture is not an arbitrary physics/destruction sandbox. Static obstruction is enforced, while dynamic crew-to-crew avoidance is not implemented. The finite working cargo hold remains a separate inspection model reached from Storage. The adversarial review records remaining visual gaps; exact parity and AAA quality are not approved.

Historical image-generation assets in `docs/reference/rejected-illustrated` are excluded by `docs/.gdignore` and export rules. All active geometry, joint tracks and shaders are authored in source; runtime asset generation is deterministic and offline.

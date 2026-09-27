extends SceneTree
## Geometry, navigation, animation, independent camera and persistent direct crew orders.
var passed := 0
var failures: Array[String] = []
var game: Node


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
	else:
		failures.append(title)
		push_error(title)


func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.capture_mode = "3d-test"
	game.save_path = "user://interior-3d-test.json"
	game.set_mode("interior")
	await process_frame
	await physics_frame
	await process_frame
	var deck: InteriorDeck = game.ui.interior_panel.deck
	game.interior_paused = true
	var state: InteriorState = game.expedition.interior_state
	var nav: InteriorNavigation = deck.model.navigation
	check(
		deck.viewport.own_world_3d and deck.camera.projection == Camera3D.PROJECTION_ORTHOGONAL,
		"Deck renders in a real independently lit 3D world"
	)
	check(
		deck.model.fixture_count >= 65 and deck.actors.size() == 7,
		"Nine rooms contain modeled fixtures and seven separate 3D crew actors"
	)
	for station in InteriorLayout.ROOMS:
		var destination := InteriorLayout.station_point(station)
		check(
			nav.walkable(Vector2(destination.x, destination.z)),
			station + " has a clear equipment approach"
		)
		var reachable := true
		var no_clipping := true
		for origin in InteriorLayout.ROOMS:
			var route := nav.route(InteriorLayout.station_point(origin), destination)
			reachable = reachable and route.size() >= 2
			var distance := InteriorNavigation.length(route)
			for step in maxi(2, ceili(distance / 0.10)):
				var point := InteriorNavigation.sample(
					route, float(step) / maxi(1, ceili(distance / 0.10) - 1)
				)
				if not nav.walkable(Vector2(point.x, point.z)):
					no_clipping = false
		check(reachable, "Every duty can reach " + station + " through connected doorways")
		check(no_clipping, "Routes to " + station + " avoid wall and furniture footprints")
	check(
		not nav.walkable(Vector2(16.4, 7.0)) and not nav.walkable(Vector2(0, 8.15)),
		"Dining table and reactor block crew navigation"
	)
	var actor: CrewActor3D = deck.actors.ivo
	var start := actor.position
	var target := Vector3(6.1, 0, 8.4)
	var route := nav.route(start, target)
	check(
		state.move_crew("ivo", route) and state.working("engineering") == 0,
		"Direct movement immediately takes the engineer off duty"
	)
	var duration := state.member("ivo").travel_duration
	state.advance(duration * 0.45)
	deck._process(0.2)
	check(
		(
			actor.position.distance_to(start) > 1
			and actor.position.distance_to(target) > 0.2
			and actor.active_clip == "walk"
		),
		"Crew physically traverses the route while articulated walking plays"
	)
	var halfway: Dictionary = game.expedition.snapshot()
	var restored := Expedition.from_snapshot(halfway)
	check(
		(
			restored != null
			and (
				restored.interior_state.member("ivo").transfer_path
				== state.member("ivo").transfer_path
			)
		),
		"Save restores exact world-space route and crew travel"
	)
	state.advance(duration)
	deck._process(0.2)
	check(
		(
			actor.position.distance_to(target) < 0.05
			and state.member("ivo").status() == "AWAITING ORDERS"
			and state.working("engineering") == 0
		),
		"Manual destination retains position and cannot silently staff a remote machine"
	)
	check(
		deck.assign_selected("ivo", "engineering"),
		"Assigning original station returns a manually moved worker to duty"
	)
	state.advance(state.member("ivo").travel_duration + 1)
	deck._process(0.2)
	check(
		state.working("engineering") > 0 and actor.active_clip == "repair",
		"Engineer resumes output and equipment animation only after returning"
	)
	actor.play_pose("walk", 0.12)
	var first: Vector3 = actor.joints.HipL.rotation
	actor.play_pose("walk", 0.52)
	var second: Vector3 = actor.joints.HipL.rotation
	check(
		first.distance_to(second) > 0.2,
		"Walking animates actual leg-joint transforms rather than translating a frozen mesh"
	)
	check(
		(
			actor.animation.has_animation("cook")
			and actor.animation.has_animation("medical")
			and actor.animation.has_animation("garden")
			and actor.animation.has_animation("rest")
		),
		"Crew has work and rest animation clips in addition to locomotion"
	)
	var before_screen := deck.crew_screen_position("ivo")
	var before_position := actor.position
	deck.azimuth += PI
	deck.update_camera()
	check(
		(
			deck.crew_screen_position("ivo").distance_to(before_screen) > 30
			and actor.position == before_position
		),
		"Orbit reveals model backs without changing crew world positions"
	)
	deck.reset_view()
	var door: Dictionary = deck.model.doors[0]
	var saved_position := actor.position
	actor.position = door.root.position
	deck.model.sync(state, deck.actors, 1)
	check(
		door.open > 0.9 and door.left.position.x < -.9,
		"Crew proximity physically slides pressure-door panels open"
	)
	actor.position = saved_position
	var bad: Dictionary = halfway.duplicate(true)
	bad.interior.crew[1].route = [[999, 0, 999], [0, 0, 0]]
	check(Expedition.from_snapshot(bad) == null, "Corrupt out-of-deck crew route is rejected")
	var original_position: Vector3 = state.member("ivo").deck_position
	check(
		(
			not state.move_crew("ivo", PackedVector3Array([Vector3.ZERO, Vector3(NAN, 0, 0)]))
			and state.member("ivo").deck_position == original_position
		),
		"Invalid manual movement cannot mutate a crew position"
	)
	# Orders at a fractional tick must start exactly where the player sees the actor.
	state.accumulator = 0.9
	var order_origin := actor.position
	check(
		state.move_crew("ivo", nav.route(order_origin, target)), "Fractional-tick movement accepted"
	)
	deck._process(0.1)
	check(
		actor.position.distance_to(order_origin) < 0.001,
		"Paused new order cannot jump ahead by the existing tick fraction"
	)
	var fractional_save := Expedition.from_snapshot(game.expedition.snapshot())
	check(
		(
			fractional_save != null
			and is_equal_approx(
				fractional_save.interior_state.member("ivo").travel_remaining,
				state.member("ivo").travel_remaining
			)
		),
		"A just-issued fractional-tick order survives checkpoint validation"
	)
	state.advance(0.2)
	deck._process(0.1)
	check(
		(
			actor.position.distance_to(order_origin) > 0.1
			and actor.position.distance_to(order_origin) < 0.4
		),
		"Crossing the fixed tick advances only actual time since the order"
	)
	var retarget_origin := actor.position
	check(deck.assign_selected("ivo", "engineering"), "Moving crew accepts a new station route")
	deck._process(0.1)
	check(
		actor.position.distance_to(retarget_origin) < 0.001,
		"Mid-route reassignment starts at the visible position without teleportation"
	)
	state.advance(30)
	deck._process(0.1)
	var resident: CrewActor3D = deck.actors.nia
	var resident_position := resident.position
	check(
		deck.assign_selected("mara", "hydroponics"), "A second specialist can join an occupied room"
	)
	deck._process(0.1)
	check(
		resident.position == resident_position,
		"Joining a station leaves its resident at her existing workstation"
	)
	state.advance(60)
	deck._process(0.1)
	check(
		resident.position.distance_to(deck.actors.mara.position) > 0.6,
		"Station arrivals use distinct reserved work positions"
	)
	state.set_tug_away(true)
	deck._process(.1)
	state.set_tug_away(false)
	deck._process(.1)
	state.advance(60)
	deck._process(.1)
	check(
		(
			resident.position == resident_position
			and resident.position.distance_to(deck.actors.mara.position) > .6
		),
		"Returning tug crew reserves a free workstation instead of overlapping its resident"
	)
	check(deck.assign_selected("mara", "bridge"), "Visitor can leave the shared workstation")
	deck._process(0.1)
	check(
		resident.position == resident_position,
		"Departing colleague cannot relocate the remaining operator"
	)
	state.advance(1)
	deck._process(.1)
	state.set_tug_away(true)
	deck._process(.1)
	state.set_tug_away(false)
	deck._process(.1)
	var returning: CrewMember = state.member("mara")
	check(
		(
			returning.transfer_path.size() > 1
			and returning.transfer_path[0].distance_to(InteriorLayout.station_point("airlock")) < .1
		),
		"Launching during a transfer cannot reuse that stale route after tug recall"
	)
	state.advance(60)
	deck._process(0.1)
	deck.selected_crew = "ivo"
	var bridge_target := Vector3(21.3, 0, 4.6)
	deck.move_selected(deck.camera.unproject_position(bridge_target))
	state.advance(60)
	deck._process(0.1)
	check(
		actor.position.distance_to(bridge_target + Vector3.UP * 0.18) < 0.05,
		"Right-click arrival stands on the raised bridge deck"
	)
	for slot in 3:
		var berth := InteriorLayout.station_point("quarters", slot)
		check(
			(
				nav.walkable(Vector2(berth.x, berth.z))
				and nav.route(actor.position, berth).size() >= 2
			),
			"Bed berth %d has a reachable physical approach" % slot
		)
	var legacy: Dictionary = game.expedition.snapshot()
	legacy.version = 3
	for person in legacy.interior.crew:
		person.station = "quarters"
		person.previous_station = "quarters"
		person.travel_remaining = 0
		person.erase("deck_position")
		person.erase("route")
		person.erase("off_station")
	var legacy_restored := Expedition.from_snapshot(legacy)
	var sleepers := 0
	if legacy_restored != null:
		for person in legacy_restored.interior_state.crew:
			if person.station == "quarters":
				sleepers += 1
	check(
		legacy_restored != null and sleepers == 3,
		"Legacy seven-sleeper saves migrate to the three modeled beds without losing crew"
	)
	actor.person.health = 10
	actor.person.off_station = false
	deck._process(0.1)
	check(actor.active_clip == "idle", "Incapacitated crew does not visibly operate machinery")
	game.audio.shutdown()
	await create_timer(.25).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	DirAccess.remove_absolute("user://interior-3d-test.json")
	print("INTERIOR 3D TESTS: %d passed, %d failed" % [passed, failures.size()])
	for failure in failures:
		print("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)

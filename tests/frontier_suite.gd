extends SceneTree
## Domain boundaries and real scene transitions, isolated from player saves.
var passed := 0
var failures: Array[String] = []
var game: Node
const SAVE := "user://frontier-suite.json"


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failures.append(label)
		push_error("FAIL: " + label)


func test_domain() -> void:
	var model := Expedition.new()
	var net := model.network
	for to in StarNetwork.COUNT:
		var path := net.route(0, to)
		check(to == 0 or not path.is_empty(), "System %d reachable from home" % to)
		var prev := 0
		for next in path:
			check(
				net.neighbors(prev).has(next) and net.neighbors(next).has(prev),
				"Every route segment is bidirectional"
			)
			prev = next
		check(net.layout(to) == net.layout(to), "System %d layout is seed stable" % to)
		check(net.encounter(to) == net.encounter(to), "System %d patrol is seed stable" % to)
	var original := net.layout(1)
	net.world_seed += 13
	check(net.layout(1) != original, "A new seed generates different terrain")
	net.world_seed = 457
	check(not net.arrive(8) and net.current == 0, "Cannot skip disconnected lanes")
	check(
		net.arrive(1) and net.visited[1] and net.jumps == 1, "Connected transit records exploration"
	)
	check(net.arrive(0), "All frontier systems have a route home")
	var jobs := model.contracts.office_jobs(net, 0)
	check(model.contracts.accept(jobs[0].id, model), "Station accepts mining commission")
	check(model.contracts.accept(jobs[1].id, model), "Station accepts salvage commission")
	check(model.contracts.accept(jobs[2].id, model), "Station accepts patrol commission")
	check(not model.contracts.accept(jobs[3].id, model), "Three active commissions is a hard limit")
	check(not model.contracts.rotate(0), "Cannot reroll active office contracts")
	var credits := model.credits
	check(
		not model.contracts.claim(jobs[0].id, model) and model.credits == credits,
		"Incomplete cargo cannot be claimed"
	)
	model.add_ore(jobs[0].amount + 4)
	model.network.current = 1
	check(
		not model.contracts.claim(jobs[0].id, model),
		"Cargo can only be delivered at its issuing station"
	)
	model.network.current = 0
	check(model.contracts.claim(jobs[0].id, model), "Qualifying physical ore delivers")
	check(
		model.ore == 4 and model.bay.mass() == 4 and model.credits == credits + int(jobs[0].reward),
		"Delivery removes real pods and pays the displayed reward"
	)
	check(not model.contracts.claim(jobs[0].id, model), "Closed commission cannot pay twice")
	for i in int(jobs[1].amount) / 12:
		model.add_salvage("contract_crate_%d" % i)
	check(
		model.contracts.claim(jobs[1].id, model) and model.scrap == 0 and model.bay.mass() == 4,
		"Salvage turn-in clears whole 2x2 containers only"
	)
	for spec in net.encounter(jobs[2].target):
		model.record_kill(spec.id)
	check(model.choir_kills() == 0, "Frontier kills cannot resolve the authored Choir story")
	check(model.contracts.claim(jobs[2].id, model), "Squadron bounty uses exact target IDs")
	check(model.contracts.accept(jobs[3].id, model), "Completing contracts frees active slots")
	check(
		not model.contracts.ready(model.contracts.find_job(net, jobs[3].id), model),
		"Unsurveyed relay has no progress"
	)
	net.visited[jobs[3].target] = true
	net.surveyed[jobs[3].target] = true
	check(model.contracts.claim(jobs[3].id, model), "Decoded survey can be delivered")
	check(model.contracts.completed == 4, "Reputation only counts successful deliveries")
	check(model.contracts.rotate(0), "Resolved office offers can rotate")
	var repeated := model.contracts.office_jobs(net, 0)
	for job in repeated:
		if job.kind == "bounty":
			for spec in net.encounter(job.target):
				model.record_kill(spec.id)
			check(
				not model.contracts.accept(job.id, model),
				"Already dead patrol cannot farm a fresh bounty"
			)
		elif job.kind == "survey":
			net.visited[job.target] = true
			net.surveyed[job.target] = true
			check(
				not model.contracts.accept(job.id, model),
				"Already decoded relay cannot farm a fresh survey"
			)
	check(model.contracts.accept(repeated[0].id, model), "Rotated supply commission is actionable")
	model.add_ore(repeated[0].amount)
	model.sell_cargo()
	check(
		not model.contracts.ready(model.contracts.find_job(net, repeated[0].id), model),
		"Selling cargo removes procurement progress"
	)
	check(model.contracts.abandon(repeated[0].id, model), "Abandon frees a contract slot")
	check(not model.contracts.accept(repeated[0].id, model), "Abandoned offers cannot reactivate")
	var exhausted := Expedition.new()
	for system in StarNetwork.COUNT:
		for i in 7 if system == 0 else 8:
			exhausted.consumed[("ore_%d" % i) if system == 0 else ("%d/ore/%d" % [system, i])] = true
		for i in 5:
			exhausted.consumed[("freight_%d" % i) if system == 0 else ("%d/freight/%d" % [system, i])] = true
	var empty_jobs := exhausted.contracts.office_jobs(exhausted.network, 0)
	check(
		(
			not exhausted.contracts.can_accept(empty_jobs[0], exhausted)
			and not exhausted.contracts.can_accept(empty_jobs[1], exhausted)
		),
		"Exhausted world cannot offer impossible supply commissions"
	)
	var copy := Expedition.from_snapshot(JSON.parse_string(JSON.stringify(model.snapshot())))
	check(
		copy != null and copy.snapshot() == model.snapshot(),
		"Network, office rotations, cargo and kills round-trip JSON"
	)
	var legacy := model.snapshot()
	legacy.version = 4
	legacy.erase("network")
	legacy.erase("contracts")
	legacy.erase("ship_condition")
	var migrated := Expedition.from_snapshot(legacy)
	check(
		migrated != null and migrated.network.current == 0 and migrated.credits == model.credits,
		"Version 4 save migrates without losing the existing expedition"
	)
	for field in ["network", "contracts", "ship_condition"]:
		var bad := model.snapshot()
		bad[field] = []
		check(Expedition.from_snapshot(bad) == null, "Reject malformed " + field)
	for field in ["seed", "current", "jumps"]:
		var bad := model.snapshot()
		bad.network[field] = -1
		check(Expedition.from_snapshot(bad) == null, "Reject invalid network " + field)
	var bad := model.snapshot()
	bad.network.visited[0] = 1
	check(Expedition.from_snapshot(bad) == null, "Reject non-boolean explored flags")
	bad = model.snapshot()
	bad.contracts.boards[0].states = [1, 1, 1, 1]
	check(Expedition.from_snapshot(bad) == null, "Reject over-limit active contracts in save")
	bad = model.snapshot()
	bad.contracts.tracked = "not:a:job"
	check(Expedition.from_snapshot(bad) == null, "Reject invalid tracked IDs in save")
	bad = model.snapshot()
	bad.ship_condition.hull = 0
	check(Expedition.from_snapshot(bad) == null, "Reject destroyed-ship checkpoints")
	bad = model.snapshot()
	bad.contracts.boards[0].states = [9, 0, 0, 0]
	check(Expedition.from_snapshot(bad) == null, "Reject invalid contract state")


func test_runtime() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.capture_mode = "test"
	game.save_path = SAVE
	game.build_world(Expedition.new())
	game.set_mode("flight")
	game.player.selected = true
	game.dock()
	game.voyage.open_jobs()
	var job: Dictionary = game.expedition.contracts.definition(game.expedition.network, 0, 2)
	check(game.voyage.accept_job(job.id), "Dock board command accepts and checkpoints a bounty")
	game.voyage.close()
	game.undock()
	game.player.take_damage(80)
	game.player.position = Vector3(0, 0, -50)
	game.voyage.open_jobs()
	var saved_before := FileAccess.get_file_as_string(SAVE)
	game.voyage.track_job(job.id)
	check(
		FileAccess.get_file_as_string(SAVE) == saved_before,
		"Flight tracking cannot create remote extraction checkpoints"
	)
	game.voyage.close()
	game.voyage.open_chart()
	game.voyage.selected_system = 1
	check(not game.voyage.begin_jump(), "Cannot jump from open space")
	game.voyage.close()
	game.player.position = game.sector.port_position + Vector3(0, 0, 24)
	game.fleet.craft[0].selected = true
	game.fleet.craft[0].launch()
	game.voyage.open_chart()
	game.voyage.selected_system = 1
	check(not game.voyage.begin_jump(), "Deployed drone blocks jump")
	game.voyage.close()
	# Domain boundary fixture: restore the berth after independently testing the blocker.
	game.fleet.craft[0].phase = SupportCraft.Phase.DOCKED
	game.fleet.craft[0].visible = false
	game.expedition.interior_state.resources.power = 0
	game.voyage.open_chart()
	game.voyage.selected_system = 1
	check(not game.voyage.begin_jump(), "Empty battery blocks transit")
	game.expedition.interior_state.resources.power = 100
	var hull: float = game.player.hull
	var expected := Expedition.from_snapshot(game.expedition.snapshot())
	expected.interior_state.resources.power -= expected.network.jump_cost(1)
	expected.interior_state.advance(20)
	check(
		game.voyage.begin_jump() and game.mode == "jump",
		"Safe, powered fleet starts a timed transition"
	)
	game.voyage.advance(4.1)
	check(
		(
			game.mode == "flight"
			and game.expedition.network.current == 1
			and game.sector is FrontierSector
		),
		"Jump builds the destination sector and resumes flight"
	)
	check(game.player.hull == hull, "Jump preserves combat damage")
	check(
		is_equal_approx(
			game.expedition.interior_state.resources.power, expected.interior_state.resources.power
		),
		"Transit charges battery and advances the crew resource simulation"
	)
	check(
		game.sector.pirates.size() == 2 and game.sector.storms.size() == 1,
		"Low-risk sector spawns its generated threats"
	)
	check(
		game.fleet.all_aboard() and game.expedition.changed.get_connections().size() == 1,
		"World replacement retains one signal connection and the fleet"
	)
	var saved := SaveStore.load_game(SAVE)
	check(
		saved != null and saved.network.current == 1 and saved.ship_condition.hull < 1,
		"Arrival saves current system and damaged hull"
	)
	game.continue_game()
	check(
		game.player.hull == hull and game.sector.station.display_name == StarNetwork.PORTS[1],
		"Continue restores damaged ship in the saved destination"
	)
	var enemy: PirateShip = game.sector.pirates[0]
	enemy.activated = true
	game.voyage.open_chart()
	game.voyage.selected_system = 0
	check(not game.voyage.begin_jump(), "Active hostile tracking prevents jumping")
	game.voyage.close()
	var storm: IonStorm = game.sector.storms[0]
	game.player.position = storm.position
	game.player.shield = 65
	storm.phase = 7
	storm.advance(0.2, [game.player])
	check(game.player.shield == 65, "Ion storm telegraph deals no premature damage")
	storm.phase = 10
	storm.advance(0.5, [game.player])
	check(game.player.shield < 65, "Ion discharge damages ships inside the 3D volume")
	game.player.position.y = storm.position.y + 15
	var shield: float = game.player.shield
	storm.advance(0.5, [game.player])
	check(game.player.shield == shield, "Changing altitude escapes the hazard volume")
	game.set_mode("dock")
	var killed_id := enemy.entity_id
	enemy.take_damage(1000)
	var rock: OreAsteroid = game.sector.obstacles[0]
	rock.extract(8, game.expedition)
	var rock_id := rock.entity_id
	var geometry: Array = []
	for asteroid in game.sector.obstacles:
		geometry.append(
			[asteroid.entity_id, asteroid.rock_seed, asteroid.radius, asteroid.position]
		)
	game.expedition.consumed["1/freight/0"] = true
	game.build_world(game.expedition)
	check(
		not game.sector.pirates.any(func(p): return p.entity_id == killed_id),
		"Re-entering a system never resurrects a cleared hostile"
	)
	var restored_geometry: Array = []
	for asteroid in game.sector.obstacles:
		restored_geometry.append(
			[asteroid.entity_id, asteroid.rock_seed, asteroid.radius, asteroid.position]
		)
	check(
		geometry == restored_geometry,
		"Salvaging a container cannot change seeded asteroid geometry on revisit"
	)
	check(
		game.sector.obstacles.filter(func(r): return r.entity_id == rock_id)[0].remaining == 32,
		"Re-entering a system preserves partially mined asteroids"
	)
	for system in [2, 3, 4, 5, 6, 7, 8]:
		var model := Expedition.new()
		model.network.current = system
		model.network.visited[system] = true
		game.build_world(model)
		game.set_mode("flight")
		game.player.position = game.sector.port_position + Vector3(0, 0, 24)
		check(
			game.sector.pirates.size() == model.network.risk(system) + 1,
			"Risk scales patrol population in system %d" % system
		)
		check(
			game.sector.storms.size() == model.network.risk(system),
			"Risk scales hazard population in system %d" % system
		)
		check(
			game.sector.pirates.all(
				func(p): return p.position.distance_to(game.player.position) > 100
			),
			"System %d arrival is outside hostile activation" % system
		)
		game.voyage.open_chart()
		await process_frame
		game.voyage.close()
		game.dock()
		game.voyage.open_jobs()
		await process_frame
		check(game.ui.buttons.size() >= 7, "System %d renders a usable station board" % system)
		game.voyage.close()
	game.audio.shutdown()
	await create_timer(0.25).timeout
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE)


func run() -> void:
	test_domain()
	await test_runtime()
	print("FRONTIER TESTS: %d passed, %d failed" % [passed, failures.size()])
	for failure in failures:
		print("  FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

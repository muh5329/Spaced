extends "res://tests/playthrough.gd"
## Flight-order pilot: mine for an upgrade, jump, fight, survey, return and deliver.
## No teleportation, resource grants, direct kills, or forced objective completion.
const FRONTIER_SAVE := "user://frontier-playthrough.json"


func berth() -> bool:
	if not await fly_to(game.sector.port_position + Vector3(-12, 0, 16)):
		return false
	return await interact_until(func(): return game.mode == "dock")


func travel(to: int) -> bool:
	while game.expedition.network.current != to:
		if game.mode == "flight" and not await berth():
			return false
		game.voyage.open_chart()
		var route: Array[int] = game.expedition.network.route(game.expedition.network.current, to)
		game.voyage.select_system(route[0])
		if not game.voyage.begin_jump():
			failures.append("Transit rejected: " + game.voyage.jump_blocker(route[0]))
			return false
		while game.mode == "jump":
			await step()
		game.select_fleet_unit(0)
		print("FRONTIER PILOT arrived: ", StarNetwork.NAMES[game.expedition.network.current])
	return true


func clear_patrol() -> bool:
	var deadline := simulation_seconds + 110
	while game.mode == "flight" and simulation_seconds < deadline:
		var enemy: PirateShip
		var distance := INF
		for candidate in game.sector.pirates:
			if candidate.dead:
				continue
			var separation: float = candidate.position.distance_to(game.player.position)
			if separation < distance:
				enemy = candidate
				distance = separation
		if enemy == null:
			return true
		if game.player.attack_target != enemy:
			game.player.command_attack(enemy)
		await step()
	failures.append("Patrol combat failed: mode=" + game.mode)
	return false


func finish_run() -> void:
	print(
		"FRONTIER PILOT RESULT: completed=",
		game.expedition.contracts.completed,
		" jumps=",
		game.expedition.network.jumps,
		" seconds=",
		int(simulation_seconds),
		" failures=",
		failures
	)
	release_controls()
	Engine.time_scale = 1
	game.audio.shutdown()
	await create_timer(0.25).timeout
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(FRONTIER_SAVE)
	quit(0 if failures.is_empty() else 1)


func run() -> void:
	Engine.time_scale = 4
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.capture_mode = "pilot"
	game.save_path = FRONTIER_SAVE
	game.build_world(Expedition.new())
	game.set_mode("flight")
	game.select_fleet_unit(0)
	if not await berth():
		await finish_run()
		return
	game.voyage.open_jobs()
	var supply: Dictionary = game.expedition.contracts.definition(game.expedition.network, 0, 0)
	if not game.voyage.accept_job(supply.id):
		failures.append("Supply offer rejected")
	game.voyage.close()
	game.undock()
	var deposit: OreAsteroid = game.sector.obstacles[0]
	if not await fly_to(deposit.position + Vector3(0, 6, 17)):
		await finish_run()
		return
	if not await work_until(deposit, func(): return game.expedition.ore >= int(supply.amount)):
		await finish_run()
		return
	if not await berth():
		await finish_run()
		return
	game.voyage.open_jobs()
	if not game.voyage.claim_job(supply.id):
		failures.append("Physical ore delivery failed")
	game.voyage.close()
	game.buy_upgrade("weapon")
	game.buy_upgrade("shield")
	print(
		"FRONTIER PILOT procurement delivered: ",
		supply.amount,
		" t; upgrades=",
		game.expedition.upgrades
	)
	game.voyage.open_jobs()
	var bounty: Dictionary = game.expedition.contracts.definition(game.expedition.network, 0, 2)
	var survey: Dictionary = game.expedition.contracts.definition(game.expedition.network, 0, 3)
	if not game.voyage.accept_job(bounty.id) or not game.voyage.accept_job(survey.id):
		failures.append("Frontier offers rejected")
	game.voyage.close()
	if not await travel(bounty.target):
		await finish_run()
		return
	if not await fly_to(game.sector.raider_position + Vector3(0, 26, 38)):
		await finish_run()
		return
	if not await clear_patrol():
		await finish_run()
		return
	print("FRONTIER PILOT patrol cleared; hull=", game.player.hull)
	if game.expedition.network.current != int(survey.target):
		if not await travel(survey.target):
			await finish_run()
			return
	var beacon: SurveyBeacon = game.sector.survey
	if not await fly_to(beacon.position + Vector3(0, 10, 9)):
		await finish_run()
		return
	if game.sector.threat_level() > 0:
		if not await clear_patrol():
			await finish_run()
			return
		if not await fly_to(beacon.position + Vector3(0, 10, 9)):
			await finish_run()
			return
	game.interaction_focus = beacon
	if not await interact_until(func(): return game.expedition.network.surveyed[survey.target]):
		await finish_run()
		return
	print("FRONTIER PILOT relay decoded in ", StarNetwork.NAMES[survey.target])
	if not await travel(0):
		await finish_run()
		return
	if not await berth():
		await finish_run()
		return
	game.voyage.open_jobs()
	if not game.voyage.claim_job(bounty.id):
		failures.append("Bounty delivery failed at issuer")
	if not game.voyage.claim_job(survey.id):
		failures.append("Survey delivery failed at issuer")
	var restored := SaveStore.load_game(FRONTIER_SAVE)
	if restored == null or restored.contracts.completed != 3 or restored.network.current != 0:
		failures.append("Final station checkpoint omitted voyage or commission progress")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(
			"res://docs/screenshots/frontier-playthrough-complete.png"
		)
	await finish_run()

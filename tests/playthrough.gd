extends SceneTree
## A bounded pilot issues the same move/attack orders as world clicks.
## Does not teleport, grant cargo/credits, kill actors directly, or bypass act gates.
var game: Node
var failures: Array[String] = []
var simulation_seconds: float = 0.0
const SAVE := "user://wayfarer-pilot-test.json"

func _initialize() -> void:
	call_deferred("run")

func step() -> void:
	await physics_frame
	simulation_seconds += 1.0 / 60.0 * Engine.time_scale

func release_controls() -> void:
	for action in ["boost", "interact"]:
		Input.action_release(action)

func fly_to(destination: Vector3) -> bool:
	if not game.player.command_move(destination):
		failures.append("Course rejected: " + str(destination))
		return false
	var deadline := simulation_seconds + 45
	Input.action_press("boost")
	while game.player.navigator.active() and simulation_seconds < deadline:
		if game.mode == "lost":
			failures.append("Pilot destroyed while navigating")
			return false
		await step()
	release_controls()
	for i in 7: await step()
	if simulation_seconds >= deadline:
		failures.append("Navigation timed out at " + str(destination))
		return false
	return true

func interact_until(predicate: Callable, timeout: float = 12) -> bool:
	var deadline := simulation_seconds + timeout
	Input.action_press("interact")
	while not predicate.call() and simulation_seconds < deadline and game.mode == "flight":
		await step()
	Input.action_release("interact")
	if not predicate.call():
		failures.append("Interaction timed out: " + str(game.interaction_target))
		return false
	return true

func work_until(target: Harvestable, predicate: Callable, timeout: float = 150) -> bool:
	if not game.fleet.request_job(target):
		failures.append("Work order rejected for " + target.display_name)
		return false
	var deadline := simulation_seconds + timeout
	while not predicate.call() and simulation_seconds < deadline:
		await step()
	game.fleet.recall_all()
	while not game.fleet.all_aboard() and simulation_seconds < deadline + 40:
		await step()
	if not predicate.call() or not game.fleet.all_aboard():
		failures.append("Work craft failed to deliver/return: " + target.display_name)
		return false
	return true

func run() -> void:
	Engine.time_scale = 4
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.capture_mode = "pilot"
	game.save_path = SAVE
	game.new_game()
	game.close_manual()
	game.update_camera(1, true)
	game.command_at(game.camera.unproject_position(game.player.position))
	if not game.player.selected: failures.append("Ship click did not select the Wayfarer")
	# Exercise real climbs and dives before the original expedition objectives.
	await fly_to(Vector3(-12, 24, 8))
	await fly_to(Vector3(-20, -16, -8))
	print("PILOT spatial transit: altitude=", snappedf(game.player.position.y, 0.1))
	var freight: Array = []
	for contact in game.sector.contacts:
		if contact is SalvageCache and not contact.is_relic:
			freight.append(contact)
	for i in 3:
		if not await fly_to(freight[i].position + Vector3(0, 5, 17)): break
		if not await work_until(freight[i], func(): return game.expedition.salvaged > i): break
	print("PILOT freight: ", game.expedition.salvaged)
	var deposit: OreAsteroid
	for contact in game.sector.contacts:
		if contact is OreAsteroid:
			deposit = contact
			break
	if await fly_to(deposit.position + Vector3(0, 6, 17)):
		await work_until(deposit, func(): return game.expedition.mined >= 24)
	print("PILOT ferrite: ", game.expedition.mined)
	if await fly_to(Sector.PORT + Vector3(-12, 0, 13)):
		await interact_until(func(): return game.mode == "dock")
	if game.mode == "dock":
		game.sell_cargo()
		game.complete_contract()
		game.buy_upgrade("weapon")
		game.buy_upgrade("shield")
		game.assign_crew("Gunnery")
		game.undock()
	print("PILOT act: ", game.expedition.act)
	if game.expedition.act == 1:
		await fly_to(Sector.RAIDERS + Vector3(0, 22, 36))
		var deadline := simulation_seconds + 100
		while game.expedition.kills < 3 and game.mode == "flight" and simulation_seconds < deadline:
			var enemy: PirateShip = null
			var nearest := INF
			for candidate in game.sector.pirates:
				if not candidate.dead:
					var distance: float = candidate.position.distance_to(game.player.position)
					if distance < nearest:
						nearest = distance
						enemy = candidate
			if enemy and game.player.attack_target != enemy:
				game.player.command_attack(enemy)
			await step()
		release_controls()
		if game.expedition.kills < 3: failures.append("Combat pilot could not clear three raiders")
	print("PILOT combat: kills=", game.expedition.kills, " hull=", game.player.hull)
	if game.mode == "flight" and await fly_to(Sector.PORT + Vector3(-12, 0, 13)):
		await interact_until(func(): return game.mode == "dock")
	if game.mode == "dock":
		game.complete_contract()
		game.undock()
	if game.expedition.act == 2:
		if await fly_to(Sector.RELIC + Vector3(0, 6, 17)):
			await work_until(game.sector.contacts.filter(func(c): return c is SalvageCache and c.is_relic)[0], func(): return game.expedition.relic)
		if await fly_to(Sector.GATE + Vector3(0, 0, 9)):
			await interact_until(func(): return game.mode == "won")
	if game.mode != "won": failures.append("Pilot did not reach victory")
	print("PILOT RESULT: mode=", game.mode, " simulated_seconds=", int(simulation_seconds), " failures=", failures)
	release_controls()
	Engine.time_scale = 1
	if DisplayServer.get_name() != "headless" and game.mode == "won":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/screenshots/won.png")
	game.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	DirAccess.remove_absolute(SAVE)
	quit(0 if failures.is_empty() else 1)

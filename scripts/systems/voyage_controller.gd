class_name VoyageController
extends RefCounted
## Application commands for travel and station commissions. The domain owns rewards.
var game: Node
var return_mode: String = "flight"
var selected_system: int = 0
var show_active: bool = false
var jump_target: int = -1
var jump_elapsed: float = 0.0
var jump_origin := Vector3.ZERO
var arrival_time: float = 0.0
const JUMP_SECONDS := 4.0


func _init(owner: Node) -> void:
	game = owner


func open_chart() -> void:
	if game.mode == "galaxy":
		close()
		return
	if game.mode not in ["flight", "dock", "jobs"]:
		return
	return_mode = (
		"dock"
		if game.mode == "dock" or (game.mode == "jobs" and return_mode == "dock")
		else "flight"
	)
	selected_system = game.expedition.network.current
	var job: Dictionary = game.expedition.contracts.tracked_job(game.expedition.network)
	if not job.is_empty():
		selected_system = destination(job)
	game.set_mode("galaxy")


func open_jobs() -> void:
	if game.mode == "jobs":
		close()
		return
	if game.mode not in ["flight", "dock"]:
		return
	return_mode = game.mode
	show_active = return_mode != "dock"
	game.set_mode("jobs")


func close() -> void:
	if game.mode not in ["galaxy", "jobs"]:
		return
	game.set_mode(return_mode)


func select_system(index: int) -> void:
	selected_system = index
	game.ui.rebuild()


func jump_blocker(to: int) -> String:
	if not game.expedition.network.neighbors(game.expedition.network.current).has(to):
		return "Select a connected system for the next jump."
	if not game.fleet.all_aboard():
		return "Recall all drones and the tug with R before jumping."
	if game.sector.threat_level() > 0:
		return "Break hostile tracking before opening a transit corridor."
	if (
		return_mode != "dock"
		and game.sector.gate.distance_to(game.player.position) > 16
		and game.sector.station.distance_to(game.player.position) > 14
	):
		return "Approach the transit relay or dock at a station."
	if game.expedition.interior_state.resources.power < game.expedition.network.jump_cost(to):
		return "Insufficient battery power. Staff engineering to recharge."
	return ""


func begin_jump() -> bool:
	if game.mode != "galaxy":
		return false
	var reason := jump_blocker(selected_system)
	if not reason.is_empty():
		game.notify(reason)
		return false
	jump_target = selected_system
	jump_elapsed = 0
	jump_origin = game.player.position
	game.player.stop()
	game.player.velocity = Vector3.ZERO
	game.set_mode("jump")
	game.audio.play("scan")
	return true


func advance(delta: float) -> void:
	arrival_time = maxf(0, arrival_time - delta)
	if game.mode != "jump":
		return
	jump_elapsed += delta
	game.player.model.throttle = 2.5
	game.player.position = jump_origin + Vector3(0, 12, -30) * smoothstep(0, 2, jump_elapsed)
	game.player.model.rotation.x = 0.15 * sin(jump_elapsed * 0.7)
	if jump_elapsed >= 1.2:
		for child in game.sector.get_children():
			if child is Node3D and child != game.player:
				child.visible = false
	if jump_elapsed >= JUMP_SECONDS:
		finish_jump()


func finish_jump() -> void:
	if game.mode != "jump" or jump_target < 0:
		return
	var model: Expedition = game.expedition
	var hull: float = game.player.hull
	var shield: float = game.player.shield
	var boost: float = game.player.energy
	var cost := model.network.jump_cost(jump_target)
	if not model.network.arrive(jump_target):
		game.set_mode(return_mode)
		jump_target = -1
		return
	model.interior_state.resources.power -= cost
	model.interior_state.advance(20)
	game.build_world(model)
	game.player.position = game.sector.port_position + Vector3(-8, 0, 25)
	game.player.hull = hull
	game.player.shield = shield
	game.player.energy = boost
	game.set_mode("flight")
	game.select_fleet_unit(0)
	game.checkpoint()
	arrival_time = 8
	jump_target = -1
	game.audio.play("dock")
	game.notify(
		(
			"Arrived at %s. Approach %s and hold E for contracts and repairs."
			% [StarNetwork.NAMES[model.network.current], StarNetwork.PORTS[model.network.current]]
		),
		8
	)


func approach_relay() -> void:
	close()
	if game.mode == "dock":
		game.undock()
	game.select_fleet_unit(0)
	game.approach_contact(game.sector.gate)
	game.notify("Course set to the transit relay. Press J on arrival.")


func toggle_job_list() -> void:
	show_active = not show_active
	game.ui.rebuild()


func accept_job(id: String) -> bool:
	if game.mode != "jobs" or return_mode != "dock":
		return false
	if not game.expedition.contracts.accept(id, game.expedition):
		return false
	game.checkpoint()
	game.ui.rebuild()
	game.notify("Commission accepted. L opens your log; J plots the route.")
	return true


func claim_job(id: String) -> bool:
	if game.mode != "jobs" or return_mode != "dock":
		return false
	var job: Dictionary = game.expedition.contracts.find_job(game.expedition.network, id)
	if not game.expedition.contracts.claim(id, game.expedition):
		return false
	game.checkpoint()
	game.ui.rebuild()
	game.audio.play("collect")
	game.notify("Commission fulfilled. +%d CR. Payment recorded." % job.reward)
	return true


func track_job(id: String) -> void:
	var job: Dictionary = game.expedition.contracts.find_job(game.expedition.network, id)
	if job.is_empty() or job.status != StationContracts.ACTIVE:
		return
	game.expedition.contracts.tracked = id
	if return_mode == "dock":
		game.checkpoint()
	game.ui.rebuild()


func abandon_job(id: String) -> void:
	if game.expedition.contracts.abandon(id, game.expedition):
		if return_mode == "dock":
			game.checkpoint()
		game.ui.rebuild()
		game.notify("Commission released. No credits or cargo deducted.")


func refresh_board() -> void:
	if game.mode != "jobs" or return_mode != "dock":
		return
	if game.expedition.contracts.rotate(game.expedition.network.current):
		game.checkpoint()
		game.ui.rebuild()


func destination(job: Dictionary) -> int:
	if game.expedition.contracts.ready(job, game.expedition):
		return job.office
	return job.target


func objective_lines() -> Array[String]:
	var model: Expedition = game.expedition
	var job := model.contracts.tracked_job(model.network)
	if job.is_empty():
		if model.network.current == 0:
			return model.objective_lines()
		return [
			"Dock for station commissions",
			"J opens the star network",
			"L opens your active contracts"
		]
	var target := destination(job)
	var route := model.network.route(model.network.current, target)
	var location: String = StarNetwork.NAMES[target]
	return [
		model.contracts.summary(job, model),
		(
			("Deliver at " + StarNetwork.PORTS[job.office])
			if model.contracts.ready(job, model)
			else ("Destination: " + location)
		),
		(
			"%d jump%s away / J plots route" % [route.size(), "" if route.size() == 1 else "s"]
			if not route.is_empty()
			else "In this system / M opens local chart"
		)
	]


func navigation_points() -> Array:
	var model: Expedition = game.expedition
	var job := model.contracts.tracked_job(model.network)
	if job.is_empty():
		return []
	var target := destination(job)
	if target != model.network.current:
		return [
			["TRANSIT RELAY / J", game.sector.gate_position, Color("b2a2f2")],
			[game.sector.station.display_name.to_upper(), game.sector.port_position, MeshKit.CYAN]
		]
	if model.contracts.ready(job, model):
		return [
			[
				"DELIVER / " + StarNetwork.PORTS[job.office].to_upper(),
				game.sector.port_position,
				MeshKit.CYAN
			]
		]
	var point: Vector3 = game.sector.mine_position
	if job.kind == "salvage":
		point = game.sector.wreck_position
	elif job.kind == "bounty":
		point = game.sector.raider_position
	elif job.kind == "survey" and game.sector is FrontierSector:
		point = game.sector.survey.position
	return [
		[job.title.to_upper(), point, MeshKit.GOLD],
		[game.sector.station.display_name.to_upper(), game.sector.port_position, MeshKit.CYAN]
	]

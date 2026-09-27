extends Node3D
## Application coordinator. Owns screen transitions and connects domain, world and UI.
var voyage: VoyageController
var expedition: Expedition
var sector: Sector
var player: PlayerShip
var camera: Camera3D
var ui: GameUI
var audio: AudioDirector
var mode: String = "menu"
var settings_return: String = "menu"
var manual_return: String = "menu"
var pause_return: String = "flight"
var crew_role: String = "Engineering"
var interior_paused: bool = false
var interior_return: String = "flight"
var cargo_return: String = "flight"
var map_return: String = "flight"
var interaction_target: SpaceEntity
var interaction_focus: SpaceEntity
var interaction_progress: float = 0.0
var scan_timer: float = 0.0
var scan_cooldown: float = 0.0
var scan_ring: MeshInstance3D
var fleet: FleetOperations
var selected_unit: CommandShip
var cargo_view: CargoBayModel
var world_environment: Environment
var camera_focus := Vector3.ZERO
var camera_zoom: float = 63.0
var tactical_camera := TacticalCamera.new()
var move_preview := MoveOrderPreview.new()
var selection_box := SelectionBox.new()
var height_modifier_latched: bool = false
var shake: float = 0.0
var shake_enabled: bool = true
var save_ok: bool = true
var elapsed: float = 0.0
var last_toast: String = ""
var toast_cooldown: float = 0.0
var screenshot_path: String = ""
var capture_mode: String = ""
var capture_time: float = 0.0
var save_path: String = SaveStore.PATH


func _ready() -> void:
	get_tree().auto_accept_quit = false
	DisplayServer.window_set_title("Wayfarer")
	Controls.install()
	voyage = VoyageController.new(self)
	setup_environment()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_zoom
	camera.far = 2400
	camera.current = true
	add_child(camera)
	audio = AudioDirector.new()
	add_child(audio)
	load_settings()
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = GameUI.new()
	ui.game = self
	layer.add_child(ui)
	cargo_view = CargoBayModel.new()
	cargo_view.position = Vector3(1060, 0, 0)
	cargo_view.scale = Vector3.ONE * 6
	add_child(cargo_view)
	cargo_view.visible = false
	build_world(Expedition.new())
	set_mode("menu")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_mode = argument.trim_prefix("--capture=")
		if argument.begins_with("--screenshot="):
			screenshot_path = argument.trim_prefix("--screenshot=")
	if not capture_mode.is_empty():
		save_path = "user://capture-checkpoint.json"
		call_deferred("configure_capture")


func setup_environment() -> void:
	var environment := Environment.new()
	world_environment = environment
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://shaders/deep_space.gdshader")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9cb9d3")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.65
	environment.glow_bloom = 0.12
	environment.ssao_enabled = true
	environment.ssao_radius = 1.3
	environment.ssao_intensity = 1.6
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_color = Color("ffdbb0")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-28, 135, 0)
	rim.light_color = Color("70bbdc")
	rim.light_energy = 0.4
	add_child(rim)


func build_world(model: Expedition) -> void:
	move_preview.cancel()
	selection_box.cancel()
	interior_paused = false
	interior_return = "flight"
	cargo_return = "flight"
	map_return = "flight"
	pause_return = "flight"
	tactical_camera = TacticalCamera.new()
	interaction_focus = null
	interaction_target = null
	interaction_progress = 0
	if is_instance_valid(sector):
		remove_child(sector)
		sector.free()
	expedition = model
	crew_role = model.crew_role
	sector = Sector.new() if model.network.current == 0 else FrontierSector.new()
	add_child(sector)
	sector.build(expedition)
	world_environment.sky.sky_material.set_shader_parameter(
		"nebula_tint",
		(
			Color(0.035, 0.10, 0.15)
			if model.network.current == 0
			else StarNetwork.COLORS[model.network.current].darkened(0.75)
		)
	)
	player = PlayerShip.new()
	player.position = Vector3(0, 0, 5)
	player.navigator.obstacles = sector.obstacles
	player.sector = sector
	sector.add_child(player)
	sector.player = player
	selected_unit = player
	fleet = FleetOperations.new()
	fleet.setup(sector, expedition)
	fleet.message.connect(notify)
	fleet.cargo_changed.connect(
		func():
			refresh_cargo()
			audio.play("collect", 0.6)
	)
	if not expedition.changed.is_connected(refresh_cargo):
		expedition.changed.connect(refresh_cargo)
	if not expedition.interior_state.notice.is_connected(notify):
		expedition.interior_state.notice.connect(notify)
	player.fired.connect(spawn_projectile)
	player.destroyed.connect(player_destroyed)
	player.damaged.connect(
		func(amount):
			expedition.interior_state.apply_impact(amount)
			shake = 0.36
			ui.damage_flash = 0.8
			audio.play("impact", 0.7)
	)
	apply_upgrades()
	player.restore()
	if expedition.act >= 1 or expedition.network.current > 0:
		activate_raiders()
	camera_focus = player.position
	refresh_cargo()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.98
	torus.outer_radius = 1.0
	torus.rings = 64
	torus.ring_segments = 6
	scan_ring = MeshKit.part(sector, torus, Vector3.ZERO, MeshKit.CYAN, 1.6)
	scan_ring.visible = false


func set_mode(next: String) -> void:
	move_preview.cancel()
	selection_box.cancel()
	tactical_camera.end_drag()
	mode = next
	world_environment.background_mode = (
		Environment.BG_COLOR if mode in ["interior", "cargo"] else Environment.BG_SKY
	)
	world_environment.background_color = Color("070d16")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.enabled = mode == "flight"
	fleet.set_enabled(mode == "flight")
	player.boost_permitted = true
	player.model.scale = Vector3.ONE * (1.3 if mode == "menu" else 1.0)
	for pirate in sector.pirates:
		if is_instance_valid(pirate):
			pirate.enabled = mode == "flight"
	sector.process_mode = (
		Node.PROCESS_MODE_INHERIT if mode in ["flight", "menu"] else Node.PROCESS_MODE_DISABLED
	)
	sector.visible = mode not in ["interior", "cargo"]
	cargo_view.visible = mode == "cargo"
	interaction_progress = 0
	ui.rebuild()
	update_camera(1.0, true)


func _process(delta: float) -> void:
	elapsed += delta
	voyage.advance(delta)
	toast_cooldown = maxf(0, toast_cooldown - delta)
	shake = maxf(0, shake - delta * 0.9)
	if mode in ["flight", "interior"]:
		expedition.interior_state.set_tug_away(fleet.crew_away() > 0)
		if mode == "flight" or not interior_paused:
			expedition.interior_state.advance(delta)
		update_crew_effects()
	if mode == "flight":
		player.model.hatch_open = not fleet.all_aboard()
		expedition.play_seconds += delta
		scan_timer = maxf(0, scan_timer - delta)
		scan_cooldown = maxf(0, scan_cooldown - delta)
		update_interaction(delta)
		sector.gate_field.set_shader_parameter(
			"charge",
			(
				1.0
				if expedition.act == 3
				else maxf(
					0.08,
					(
						interaction_progress
						if (
							is_instance_valid(interaction_target)
							and interaction_target.category == "gate"
						)
						else 0.0
					)
				)
			)
		)
		if scan_timer > 0:
			scan_ring.visible = true
			scan_ring.scale = Vector3.ONE * (6 + (3 - scan_timer) * 30)
		else:
			scan_ring.visible = false
		if player.damage_delay <= 0:
			player.shield = minf(
				player.max_shield,
				player.shield + delta * 4 * expedition.interior_state.working("engineering")
			)
	elif mode == "menu":
		player.rotation.y = -0.45 + sin(elapsed * 0.1) * 0.16
	update_camera(delta)
	if not Input.is_action_pressed("boost"):
		height_modifier_latched = false
	player.boost_permitted = (
		player.selected
		and not move_preview.active
		and not selection_box.active
		and not height_modifier_latched
	)
	if not screenshot_path.is_empty():
		capture_time += delta
		var capture_ready := capture_time > 3.0
		if capture_mode == "mining_operations":
			capture_ready = (
				capture_time > 4
				and fleet.craft.any(func(unit): return unit.phase == SupportCraft.Phase.WORKING)
			)
		if capture_mode == "tow_operations":
			capture_ready = (
				capture_time > 10
				and fleet.craft[2].payload_amount > 0
				and fleet.craft[2].phase == SupportCraft.Phase.RETURNING
			)
		if capture_ready or capture_time > 25:
			var path := screenshot_path
			screenshot_path = ""
			await RenderingServer.frame_post_draw
			var result := get_viewport().get_texture().get_image().save_png(path)
			print("CAPTURE: ", path, " result=", result)
			print(
				"RENDER: fps=",
				Engine.get_frames_per_second(),
				" draw_calls=",
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				" primitives=",
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			)
			quit_game()


func _physics_process(_delta: float) -> void:
	if mode == "flight":
		sector.resolve_collision(player)
		sector.advance_hazards(_delta)
		for pirate in sector.pirates:
			if is_instance_valid(pirate) and not pirate.dead:
				sector.resolve_collision(pirate)


func _input(event: InputEvent) -> void:
	if mode == "flight" and selection_box.active:
		if event is InputEventMouseMotion:
			selection_box.update(event.position)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				selection_box.update(event.position)
				var dragged := selection_box.dragging
				var bounds := selection_box.rectangle()
				var additive := selection_box.additive
				selection_box.cancel()
				if dragged:
					select_rectangle(bounds, additive)
				else:
					command_at(event.position, additive)
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				selection_box.cancel()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("pause_game"):
			selection_box.cancel()
			get_viewport().set_input_as_handled()
			return
	if mode == "flight" and tactical_camera.drag_button != MOUSE_BUTTON_NONE:
		if event is InputEventMouseMotion:
			tactical_camera.drag(event.position)
			get_viewport().set_input_as_handled()
			return
		if (
			event is InputEventMouseButton
			and not event.pressed
			and event.button_index == tactical_camera.drag_button
		):
			var was_dragging := tactical_camera.end_drag()
			if not was_dragging and event.button_index == MOUSE_BUTTON_RIGHT:
				if move_preview.active:
					move_preview.cancel()
				else:
					command_at(event.position)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton:
			# Orbit owns mouse buttons until its initiating button is released.
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause_game"):
		if mode == "flight" and move_preview.active:
			move_preview.cancel()
			tactical_camera.end_drag()
			get_viewport().set_input_as_handled()
			return
		match mode:
			"flight":
				pause_return = "flight"
				set_mode("pause")
			"pause":
				set_mode(pause_return)
			"settings":
				close_settings()
			"manual":
				close_manual()
			"interior":
				toggle_interior()
			"cargo":
				toggle_cargo()
			"map":
				set_mode(map_return)
			"galaxy", "jobs":
				voyage.close()
			"dock":
				undock()
			"confirm_new":
				set_mode("menu")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("starchart") and mode in ["flight", "dock", "galaxy", "jobs"]:
		voyage.open_chart()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("journal") and mode in ["flight", "dock", "jobs"]:
		voyage.open_jobs()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interior") and mode in ["flight", "interior", "dock"]:
		toggle_interior()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("map") and mode in ["flight", "map"]:
		toggle_map()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("cargo_view") and mode in ["flight", "interior", "cargo"]:
		toggle_cargo()
		get_viewport().set_input_as_handled()
		return
	if (
		mode == "map"
		and map_return == "flight"
		and event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		var goal = ui.chart_goal_at(event.position)
		if goal != null:
			set_mode("flight")
			select_fleet_unit(0)
			var contact: SpaceEntity
			for candidate in sector.contacts:
				if candidate.available and candidate.position.is_equal_approx(goal):
					contact = candidate
					break
			if contact != null:
				approach_contact(contact)
			else:
				player.command_move(goal)
			get_viewport().set_input_as_handled()
			return
	if mode != "flight":
		return
	for index in 4:
		if event.is_action_pressed("unit_%d" % index):
			select_fleet_unit(index)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("recall"):
		move_preview.cancel()
		selection_box.cancel()
		tactical_camera.end_drag()
		if player.selected:
			player.stop()
			fleet.recall_all()
		else:
			for unit in selected_units():
				if unit is SupportCraft:
					unit.recall()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and interaction_target is Harvestable:
		fleet.request_job(interaction_target)
		get_viewport().set_input_as_handled()
		return
	if move_preview.active:
		if event is InputEventMouseMotion and not ui.blocks_world_input(event.position):
			move_preview.update(camera, event.position, event.shift_pressed)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("boost") or event.is_action_released("boost"):
			height_modifier_latched = event.is_pressed()
			move_preview.update(camera, get_viewport().get_mouse_position(), event.is_pressed())
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("plot_move"):
		selection_box.cancel()
		if selected_unit.selected:
			move_preview.begin(selection_center())
			height_modifier_latched = Input.is_action_pressed("boost")
			player.boost_permitted = false
			move_preview.update(camera, get_viewport().get_mouse_position(), false)
		else:
			notify("Select a craft before plotting a 3D course.")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("focus_ship"):
		tactical_camera.reset()
		camera_zoom = 63
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("stop"):
		move_preview.cancel()
		selection_box.cancel()
		tactical_camera.end_drag()
		for unit in selected_units():
			unit.stop()
		interaction_focus = null
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("scan"):
		get_viewport().set_input_as_handled()
		if scan_cooldown <= 0:
			scan_timer = 3
			scan_cooldown = 7
			scan_ring.position = player.position + Vector3.UP * 0.3
			audio.play("scan")
			notify("Survey complete. Nearby resources marked on telemetry.")
	if event is InputEventMouseButton and event.pressed:
		if (
			event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
			and not ui.blocks_world_input(event.position)
		):
			var step := 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			if move_preview.active:
				move_preview.adjust_height(step * 3)
			else:
				camera_zoom = clampf(camera_zoom - step * 4, 35, 110)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if (
		mode != "flight"
		or not event is InputEventMouseButton
		or not event.pressed
		or ui.blocks_world_input(event.position)
	):
		return
	if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		tactical_camera.begin_drag(event.position, event.button_index)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if move_preview.active:
			interaction_focus = null
			move_selected(move_preview.destination())
			move_preview.cancel()
			audio.play("ui", 0.5)
			get_viewport().set_input_as_handled()
		else:
			selection_box.begin(event.position, event.shift_pressed)
			player.boost_permitted = false
			if event.shift_pressed:
				height_modifier_latched = true
			get_viewport().set_input_as_handled()


func command_at(screen: Vector2, additive: bool = false) -> void:
	if mode != "flight" or ui.blocks_world_input(screen):
		return
	get_viewport().set_input_as_handled()
	var closest := WorldPicker.hit_distance(camera, screen, player)
	var picked: SpaceEntity = player if closest < INF else null
	for contact in sector.contacts:
		if not contact.available or not contact.visible or (contact is Ship and contact.dead):
			continue
		var distance := WorldPicker.hit_distance(camera, screen, contact)
		if distance < closest:
			picked = contact
			closest = distance
	if picked == player or picked is SupportCraft:
		select_unit(picked, additive)
		return
	if not selected_unit.selected:
		notify("Click or drag a box around your craft to select them first.")
		return
	interaction_focus = null
	if picked is Harvestable:
		var compatible := false
		for unit in selected_units():
			if unit is SupportCraft and unit.accepts(picked):
				compatible = true
				unit.command_work(picked)
		if not compatible:
			if player.selected:
				approach_contact(picked)
			else:
				notify("Mining drones cut ore; Latch's crew handles salvage. R recalls your craft.")
	elif picked is Ship and player.selected:
		player.command_attack(picked)
	elif picked != null:
		approach_contact(picked)
	else:
		var goal = ui.navigation_goal_at(screen)
		if goal != null:
			if goal == sector.port_position:
				approach_contact(sector.station)
			else:
				move_selected(goal)
		else:
			var point = Plane(Vector3.UP, selection_center().y).intersects_ray(
				camera.project_ray_origin(screen), camera.project_ray_normal(screen)
			)
			if point != null:
				move_selected(point)
	audio.play("ui", 0.5)


func approach_contact(contact: SpaceEntity) -> void:
	var outward := (selection_center() - contact.position).normalized()
	if outward.length() < 0.01:
		outward = Vector3.BACK
	if move_selected(
		contact.position + outward * (contact.radius + 5.5),
		"APPROACHING " + contact.display_name.to_upper()
	):
		interaction_focus = contact


func update_camera(delta: float, immediate: bool = false) -> void:
	if mode == "flight" and selection_box.active:
		return
	var focus := selection_center() if mode == "flight" else player.position
	tactical_camera.update(delta, immediate)
	var offset := tactical_camera.offset(camera_zoom)
	var zoom := camera_zoom
	match mode:
		"menu", "confirm_new":
			offset = Vector3(23, 30, 34)
			focus = player.position - Vector3(offset.z, 0, -offset.x).normalized() * 8.0
			zoom = 29
		"dock":
			focus = sector.port_position + Vector3(12, 0, 1)
			offset = Vector3(0, 48, 31)
			zoom = 57
		"jump":
			focus = player.position
			offset = Vector3(12, 8, 21)
			zoom = 30 - voyage.jump_elapsed * 2
		"interior":
			focus = player.position
			offset = Vector3(24, 36, 29)
			zoom = 49
		"cargo":
			focus = cargo_view.position + Vector3(4.5, 4, 0)
			offset = Vector3(15, 25, 23)
			zoom = 27
		"pause", "settings", "manual", "map", "galaxy", "jobs", "lost", "won":
			return
	var blend := 1.0 if immediate else 1.0 - exp(-delta * 4.5)
	camera.projection = (
		Camera3D.PROJECTION_PERSPECTIVE if mode == "flight" else Camera3D.PROJECTION_ORTHOGONAL
	)
	camera.fov = TacticalCamera.FIELD_OF_VIEW
	camera_focus = camera_focus.lerp(focus, blend)
	camera.size = lerpf(camera.size, zoom, blend)
	var jitter := Vector3.ZERO
	if shake_enabled and shake > 0 and mode == "flight":
		jitter = Vector3(sin(elapsed * 73), 0, cos(elapsed * 61)) * shake
	camera.position = camera_focus + offset + jitter
	camera.look_at(camera_focus + jitter, Vector3.UP)


func update_interaction(delta: float) -> void:
	var reach := 12.0 + 5.0 * expedition.interior_state.working("bridge")
	var target := sector.nearest_interactable(player.position, reach)
	if (
		is_instance_valid(interaction_focus)
		and interaction_focus.available
		and interaction_focus.distance_to(player.position) <= reach
	):
		target = interaction_focus
	if target != interaction_target:
		interaction_progress = 0
		interaction_target = target
	if not is_instance_valid(target):
		return
	if target is Harvestable:
		# Work orders launch independent craft; proximity never teleports cargo aboard.
		interaction_progress = 0
		return
	if not Input.is_action_pressed("interact"):
		interaction_progress = 0
		return
	if target.category == "station":
		if sector.threat_level() > 0:
			notify("Docking denied while hostiles are tracking you. Break contact first.")
			return
		interaction_progress += delta / 1.1
		if interaction_progress >= 1:
			dock()
	elif target.category == "survey":
		if sector.threat_level() > 0:
			notify("Hostile interference. Break contact before decoding the relay.")
			return
		interaction_progress += delta / 4.0
		if interaction_progress >= 1:
			expedition.network.surveyed[expedition.network.current] = true
			target.available = false
			target.display_name = "Relay decoded"
			expedition.changed.emit()
			audio.play("scan")
			notify(
				"Signal decoded. Survey data stored; return to the issuing station to claim your commission.",
				6
			)
	elif target.category == "gate":
		if expedition.network.current > 0:
			voyage.open_chart()
		elif expedition.act == 3:
			notify("The corridor is open. Home is waiting.")
		elif expedition.act != 2 or not expedition.relic:
			notify("J opens inter-system transit. The story corridor requires the Asterion core.")
		else:
			if not fleet.all_aboard():
				fleet.recall_all()
				notify("Recall in progress. Recover work craft before opening the corridor.")
				return
			interaction_progress += delta / 3.5
			if interaction_progress >= 1 and expedition.finish():
				checkpoint()
				audio.play("dock")
				set_mode("won")


func notify(message: String, seconds: float = 4) -> void:
	if message == last_toast and toast_cooldown > 0:
		return
	last_toast = message
	toast_cooldown = 2.5
	ui.toast(message, seconds)


func spawn_projectile(origin: Vector3, direction: Vector3, power: float, faction: String) -> void:
	if mode != "flight":
		return
	var projectile := Projectile.new()
	projectile.position = origin
	projectile.velocity = direction * (74 if faction == "player" else 38)
	projectile.power = power
	projectile.faction = faction
	projectile.collision_query = sector.segment_hit
	projectile.impact = burst
	sector.add_child(projectile)
	audio.play("rail" if faction == "player" else "hostile", 0.44 if faction == "player" else 0.7)


func burst(point: Vector3, color: Color, large: bool) -> void:
	var effect := Burst.new()
	effect.position = point
	effect.color = color
	effect.large = large
	sector.add_child(effect)
	if large:
		audio.play("explosion")
		shake = 0.7


func activate_raiders() -> void:
	for pirate in sector.spawn_raiders():
		pirate.fired.connect(spawn_projectile)
		pirate.destroyed.connect(pirate_destroyed)
		pirate.enabled = mode == "flight"


func pirate_destroyed(ship: Ship) -> void:
	expedition.record_kill(ship.entity_id)
	burst(ship.position, MeshKit.GOLD, true)
	ship.visible = false
	ship.available = false
	notify("%s neutralized. +90 CR bounty. L shows commission progress." % ship.display_name)


func player_destroyed(_ship: Ship) -> void:
	interaction_focus = null
	player.stop()
	burst(player.position, MeshKit.GOLD, true)
	player.visible = false
	set_mode("lost")


func request_new_game() -> void:
	if SaveStore.load_game() != null:
		set_mode("confirm_new")
	else:
		new_game()


func new_game() -> void:
	crew_role = "Engineering"
	var model := Expedition.new()
	model.network.world_seed = randi_range(1, 2147483646)
	build_world(model)
	checkpoint()
	set_mode("flight")
	manual_return = "flight"
	set_mode("manual")


func continue_game() -> void:
	var saved := SaveStore.load_game(save_path)
	if saved == null:
		notify("Checkpoint could not be read. Begin a new expedition.")
		return
	build_world(saved)
	player.hull = player.max_hull * saved.ship_condition.hull
	player.shield = player.max_shield * saved.ship_condition.shield
	player.energy = saved.ship_condition.boost
	player.position = sector.port_position + Vector3(-8, 0, 18)
	set_mode("flight")
	notify("Checkpoint restored. Welcome back, Captain.")


func checkpoint() -> void:
	if not fleet.all_aboard():
		return
	expedition.ship_condition = {
		"hull": player.hull / player.max_hull,
		"shield": player.shield / player.max_shield,
		"boost": player.energy
	}
	save_ok = SaveStore.save_game(expedition, save_path) == OK
	if not save_ok:
		notify("Save failed. Your current expedition is still running.")


func dock() -> void:
	if not fleet.all_aboard():
		player.stop()
		fleet.recall_all()
		notify("Recovering work craft. Hold position until the crew and cargo are aboard.")
		return
	interaction_focus = null
	player.stop()
	player.restore()
	player.energy = 100
	player.velocity = Vector3.ZERO
	player.position = sector.port_position + Vector3(0, 1.2, 1)
	player.rotation.y = 0
	player.model.rotation = Vector3.ZERO
	expedition.interior_state.dock_service()
	checkpoint()
	audio.play("dock")
	set_mode("dock")


func undock() -> void:
	interaction_focus = null
	player.stop()
	player.velocity = Vector3.ZERO
	player.position = sector.port_position + Vector3(-5, 0, 24)
	player.rotation.y = -0.5
	interaction_target = null
	set_mode("flight")
	notify("Moorings released. Safe travels, Wayfarer.")


func sell_cargo() -> void:
	var revenue := expedition.sell_cargo()
	checkpoint()
	ui.rebuild()
	notify("Freight sold. +%d CR transferred to your account." % revenue)
	audio.play("collect")


func complete_contract() -> void:
	if expedition.network.current != 0:
		return
	if expedition.turn_in():
		if expedition.act == 1:
			activate_raiders()
		checkpoint()
		ui.rebuild()
		notify("Contract complete. New coordinates added to your chart.", 6)
		audio.play("dock")


func buy_upgrade(kind: String) -> void:
	if expedition.purchase(kind):
		apply_upgrades()
		player.restore()
		checkpoint()
		ui.rebuild()
		notify(Expedition.UPGRADE_NAMES[kind] + " installed. Ship systems updated.")
		audio.play("collect")


func apply_upgrades() -> void:
	player.apply_upgrades(expedition)
	update_crew_effects()
	refresh_cargo()


func update_crew_effects() -> void:
	player.weapon_power = (
		24 + expedition.upgrades.weapon * 9 + 5 * expedition.interior_state.working("airlock")
	)
	player.crew_navigation_bonus = 2 * expedition.interior_state.working("bridge")


func resupply_interior() -> void:
	if mode != "dock":
		notify("Life-support resupply is available at Meridian.")
		return
	var price := expedition.interior_state.supply_cost()
	if expedition.credits < price:
		notify("Resupply costs %d CR. Sell cargo to cover the order." % price)
		return
	expedition.credits -= price
	expedition.interior_state.resupply()
	checkpoint()
	ui.rebuild()
	notify("Food, water, oxygen, medicine and spare parts replenished.")


func select_fleet_unit(index: int) -> void:
	select_unit(player if index == 0 else fleet.craft[index - 1])


func select_unit(unit: CommandShip, additive: bool = false) -> void:
	var members: Array[CommandShip] = []
	if additive:
		members = selected_units()
	if not members.has(unit):
		members.append(unit)
	set_selection(members)
	if mode == "flight" and unit is SupportCraft:
		unit.launch()


func set_selection(members: Array[CommandShip]) -> void:
	if mode != "flight":
		return
	move_preview.cancel()
	selection_box.cancel()
	tactical_camera.end_drag()
	player.selected = members.has(player)
	for craft in fleet.craft:
		craft.selected = members.has(craft)
	selected_unit = members[0] if not members.is_empty() else player
	audio.play("ui", 0.5)
	if members.size() > 1:
		notify(
			"%d craft selected. Click to command the group; G plots a 3D course." % members.size()
		)
	elif members.size() == 1:
		notify(
			(
				selected_unit.display_name
				+ " selected. Click a contact to work; G plots a course. R recalls."
			)
		)


func selected_units() -> Array[CommandShip]:
	var members: Array[CommandShip] = []
	if player.selected and not player.dead:
		members.append(player)
	for unit in fleet.craft:
		if unit.selected and not unit.dead:
			members.append(unit)
	return members


func selection_center() -> Vector3:
	var center := Vector3.ZERO
	var count := 0
	for unit in selected_units():
		if not unit.visible:
			continue
		center += unit.position
		count += 1
	return center / count if count > 0 else player.position


func select_rectangle(bounds: Rect2, additive: bool = false) -> void:
	var members: Array[CommandShip] = []
	if additive:
		members = selected_units()
	var candidates: Array[CommandShip] = [player]
	candidates.append_array(fleet.craft)
	bounds = bounds.intersection(get_viewport().get_visible_rect())
	for unit in candidates:
		if not unit.visible or unit.dead or camera.is_position_behind(unit.global_position):
			continue
		var point := camera.unproject_position(unit.global_position)
		if bounds.has_point(point) and not ui.blocks_world_input(point) and not members.has(unit):
			members.append(unit)
	set_selection(members)


func move_selected(destination: Vector3, label: String = "FOLLOWING COURSE") -> bool:
	var members := selected_units()
	var accepted := false
	var center := destination
	if members.size() > 1 and destination.is_finite():
		center = FlightNavigator.constrain(destination)
		var horizontal := Vector2(center.x, center.z).limit_length(FlightNavigator.BELT_RADIUS - 8)
		center.x = horizontal.x
		center.z = horizontal.y
	# Separate arrival berths for this four-craft fleet; no formation controller needed.
	for i in members.size():
		var offset := Vector3.ZERO
		if members.size() > 1:
			offset = Vector3(
				(i % 2 - 0.5) * 8, 0, (floori(i / 2.0) - (ceilf(members.size() / 2.0) - 1) / 2) * 8
			)
		if members[i].command_move(center + offset, label):
			accepted = true
	return accepted


func refresh_cargo() -> void:
	if not is_instance_valid(player):
		return
	if is_instance_valid(player.model.cargo_hold):
		player.model.cargo_hold.refresh(expedition.bay)
	if is_instance_valid(cargo_view):
		cargo_view.refresh(expedition.bay)


func toggle_cargo() -> void:
	if mode == "cargo":
		set_mode(cargo_return)
	else:
		cargo_return = mode if mode in ["interior", "dock"] else "flight"
		set_mode("cargo")


func assign_crew(role: String) -> void:
	crew_role = role
	expedition.crew_role = role
	apply_upgrades()
	ui.rebuild()
	notify(role + " watch assigned.")


func toggle_interior() -> void:
	if mode in ["flight", "dock"]:
		interior_return = mode
		set_mode("interior")
	elif mode == "interior":
		if interior_return == "dock":
			checkpoint()
		set_mode(interior_return)


func toggle_map() -> void:
	if mode == "map":
		set_mode(map_return)
	else:
		map_return = mode if mode in ["interior", "dock"] else "flight"
		set_mode("map")


func resume() -> void:
	set_mode(pause_return if mode == "pause" else "flight")


func retry() -> void:
	continue_game()


func return_to_title() -> void:
	build_world(Expedition.new())
	manual_return = "menu"
	ui.toast_time = 0
	set_mode("menu")


func open_settings(from: String) -> void:
	settings_return = from
	set_mode("settings")


func close_settings() -> void:
	save_settings()
	set_mode(settings_return)


func close_manual() -> void:
	set_mode(manual_return)


func open_manual(from: String) -> void:
	manual_return = from
	set_mode("manual")


func adjust_audio(channel: String, amount: float) -> void:
	if channel == "music":
		audio.music_volume = clampf(audio.music_volume + amount, 0, 1)
	else:
		audio.effects_volume = clampf(audio.effects_volume + amount, 0, 1)
	audio.apply_volume()
	save_settings()


func toggle_shake() -> void:
	shake_enabled = not shake_enabled
	save_settings()


func toggle_fullscreen() -> void:
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	save_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", audio.music_volume)
	config.set_value("audio", "effects", audio.effects_volume)
	config.set_value("video", "shake", shake_enabled)
	config.set_value(
		"video",
		"fullscreen",
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	config.save("user://settings.cfg")


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		audio.music_volume = clampf(float(config.get_value("audio", "music", 0.65)), 0, 1)
		audio.effects_volume = clampf(float(config.get_value("audio", "effects", 0.8)), 0, 1)
		shake_enabled = config.get_value("video", "shake", true)
		if config.get_value("video", "fullscreen", false):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		audio.apply_volume()


func quit_game() -> void:
	save_settings()
	audio.shutdown()
	await get_tree().create_timer(0.18).timeout
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		selection_box.cancel()
		tactical_camera.end_drag()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
	elif (
		what == NOTIFICATION_APPLICATION_FOCUS_OUT
		and mode in ["flight", "interior"]
		and capture_mode.is_empty()
		and is_instance_valid(ui)
	):
		pause_return = mode
		set_mode("pause")


func navigation_hint() -> String:
	if (
		expedition.network.current > 0
		or not expedition.contracts.active_jobs(expedition.network).is_empty()
	):
		return "J  STAR NETWORK   /   L  CONTRACT LOG   /   M  LOCAL CHART"
	match expedition.act:
		0:
			return "Find the wreck and ferrite field  /  M to open chart"
		1:
			return (
				"Head north to Choir territory  /  M to open chart"
				if expedition.choir_kills() < 3
				else "Corridor clear. Return to Port Meridian."
			)
		2:
			return (
				"Recover the Asterion core in the northeast"
				if not expedition.relic
				else "The Janus beacon is waiting in the east"
			)
	return "The belt is yours to explore."


func navigation_points() -> Array:
	var mission_points := voyage.navigation_points()
	if not mission_points.is_empty():
		return mission_points
	if expedition.network.current > 0:
		return sector.chart_points().filter(func(p): return not p[0].begins_with("ION"))
	var points: Array = []
	match expedition.act:
		0:
			if expedition.salvaged < 3:
				points.append(["FREIGHT WRECK", Sector.WRECK, MeshKit.GOLD])
			if expedition.mined < 24:
				points.append(["FERRITE FIELD", Sector.MINE, MeshKit.CYAN])
			points.append(["MERIDIAN", Sector.PORT, MeshKit.CYAN])
		1:
			points.append(
				(
					["CHOIR TERRITORY", Sector.RAIDERS, MeshKit.RED]
					if expedition.choir_kills() < 3
					else ["MERIDIAN", Sector.PORT, MeshKit.CYAN]
				)
			)
		2:
			points.append(
				(
					["ASTERION RELIC", Sector.RELIC, Color("b2a2f2")]
					if not expedition.relic
					else ["JANUS BEACON", Sector.GATE, Color("b2a2f2")]
				)
			)
		3:
			points.append(["MERIDIAN", Sector.PORT, MeshKit.CYAN])
	return points


func configure_capture() -> void:
	match capture_mode:
		"flight":
			set_mode("flight")
		"navigation":
			set_mode("flight")
			player.selected = true
			player.command_move(Sector.WRECK)
		"spatial":
			set_mode("flight")
			player.selected = true
			tactical_camera.target_azimuth = -0.52
			tactical_camera.target_elevation = 0.64
			update_camera(1, true)
			move_preview.begin(player.position)
			move_preview.base = player.position + Vector3(18, 0, 8)
			move_preview.altitude = 20
		"climb":
			set_mode("flight")
			player.selected = true
			tactical_camera.target_azimuth = -0.5
			tactical_camera.target_elevation = 0.5
			update_camera(1, true)
			player.command_move(Vector3(25, 25, -30))
		"salvage":
			player.position = Sector.WRECK + Vector3(8, 0, 13)
			set_mode("flight")
		"dock":
			dock()
		"interior":
			set_mode("interior")
		"cargo":
			expedition.add_salvage("capture_crate_1")
			expedition.add_salvage("capture_crate_2")
			expedition.add_ore(20)
			set_mode("cargo")
		"ship_detail":
			set_mode("flight")
			player.selected = true
			camera_zoom = 32
			tactical_camera.target_azimuth = -0.9
			tactical_camera.target_elevation = 0.56
			update_camera(1, true)
		"mining_operations":
			player.position = Sector.MINE + Vector3(-12, 6, 22)
			set_mode("flight")
			player.selected = true
			fleet.request_job(sector.obstacles[0])
			fleet.request_job(sector.obstacles[1])
			camera_zoom = 48
			update_camera(1, true)
		"tow_operations":
			player.position = Sector.WRECK + Vector3(16, 0, 20)
			set_mode("flight")
			player.selected = true
			for contact in sector.contacts:
				if contact is SalvageCache and not contact.is_relic:
					fleet.request_job(contact)
					break
			camera_zoom = 54
			update_camera(1, true)
		"map":
			set_mode("map")
		"combat":
			expedition.act = 1
			activate_raiders()
			player.position = Sector.RAIDERS + Vector3(0, 0, 23)
			set_mode("flight")
		"won":
			expedition.act = 3
			set_mode("won")
		"manual":
			set_mode("manual")

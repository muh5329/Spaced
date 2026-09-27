class_name InteriorDeck
extends Control
## Native 3D viewport: orbitable modeled deck, animated actors and ray-cast picking.
signal crew_picked(id: String)
signal station_picked(id: String)
signal movement_ordered(message: String)
var state: InteriorState
var selected_crew: String = "mara"
var selected_station: String = "bridge"
var hovered_crew: String = ""
var hovered_station: String = ""
var zoom: float = 1.0
var pan := Vector2.ZERO
var azimuth: float = -0.56
var elevation: float = 0.76
var orbiting: bool = false
var panning: bool = false
var right_distance: float = 0
var viewport: SubViewport
var display: TextureRect
var world: Node3D
var model: InteriorModel3D
var camera: Camera3D
var actors: Dictionary = {}
var bound_state: InteriorState
var font: Font = preload("res://assets/fonts/Barlow-SemiBold.ttf")


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.name = "InteriorWorld"
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.handle_input_locally = false
	add_child(viewport)
	display = TextureRect.new()
	display.texture = viewport.get_texture()
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(display)
	world = Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0a111e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b4c0d4")
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 1.8
	env.ssao_intensity = 2.0
	env.glow_enabled = true
	env.glow_intensity = 0.28
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-56, -24, 0)
	sun.light_color = Color("e3d8c7")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 145, 0)
	fill.light_color = Color("8ca6c4")
	fill.light_energy = 0.12
	world.add_child(fill)
	model = InteriorModel3D.new()
	world.add_child(model)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.1
	camera.far = 150
	world.add_child(camera)
	camera.current = true
	resized.connect(resize_view)
	mouse_exited.connect(
		func():
			hovered_crew = ""
			hovered_station = ""
			orbiting = false
			panning = false
	)
	resize_view()


func resize_view() -> void:
	if not is_instance_valid(viewport):
		return
	viewport.size = Vector2i(maxi(16, int(size.x)), maxi(16, int(size.y)))
	update_camera()


func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	azimuth = -0.56
	elevation = 0.76
	update_camera()


func update_camera() -> void:
	if not is_instance_valid(camera):
		return
	var center := Vector3(10.1, 0, 9.5) + Vector3(pan.x, 0, pan.y)
	camera.size = 26.0 / zoom
	camera.position = (
		center
		+ Vector3(sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation)) * 46
	)
	camera.look_at(center, Vector3.UP)


func bind_people() -> void:
	if state == null or bound_state == state:
		return
	for actor in actors.values():
		actor.queue_free()
	actors.clear()
	bound_state = state
	var slots: Dictionary = {}
	for i in state.crew.size():
		var actor := CrewActor3D.new()
		world.add_child(actor)
		var station: String = state.crew[i].station
		if not state.crew[i].has_deck_position:
			var point := model.navigation.work_position(state, station, state.crew[i].id)
			if point.is_finite():
				state.crew[i].deck_position = point
				state.crew[i].has_deck_position = true
		actor.setup(state.crew[i], i, slots.get(station, 0))
		slots[station] = slots.get(station, 0) + 1
		actors[state.crew[i].id] = actor


func pick(point: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 150, 6)
	var result := world.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {}
	var collider: Node = result.collider
	return {
		"crew": collider.get_meta("crew", ""),
		"station": collider.get_meta("station", ""),
		"point": result.position
	}


func crew_screen_position(id: String) -> Vector2:
	return camera.unproject_position(actors[id].position + Vector3(0, 0.9, 0))


func station_screen_position(id: String) -> Vector2:
	return camera.unproject_position(InteriorLayout.ROOMS[id].label)


func assignment_path(id: String, station: String) -> PackedVector3Array:
	if not actors.has(id):
		return PackedVector3Array()
	var destination := model.navigation.work_position(state, station, id)
	if not destination.is_finite():
		return PackedVector3Array()
	return model.navigation.route(actors[id].position, destination)


func assign_selected(id: String, station: String) -> bool:
	var person := state.member(id)
	if person.station == station and not person.off_station:
		return true
	var route := assignment_path(id, station)
	if route.size() < 2:
		return state.fail("No walkable route to that station.")
	var duration := maxf(1, InteriorNavigation.length(route) / 1.55)
	if not state.assign(id, station, duration):
		return false
	person.begin_route(route, duration, state.accumulator)
	return true


func move_selected(screen: Vector2) -> void:
	var point = Plane(Vector3.UP, 0).intersects_ray(
		camera.project_ray_origin(screen), camera.project_ray_normal(screen)
	)
	if point == null or not model.navigation.walkable(Vector2(point.x, point.z)):
		movement_ordered.emit(
			"Choose clear deck space; crew cannot walk through furniture or walls."
		)
		return
	point.y = InteriorLayout.floor_height(point)
	var path := model.navigation.route(actors[selected_crew].position, point)
	if state.move_crew(selected_crew, path):
		movement_ordered.emit(
			state.member(selected_crew).display_name + " moving. Reassign a station to resume duty."
		)
	else:
		movement_ordered.emit(state.last_error)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if orbiting:
			right_distance += event.relative.length()
			azimuth -= event.relative.x * 0.008
			elevation = clampf(elevation + event.relative.y * 0.006, 0.25, 1.35)
			update_camera()
		elif panning:
			pan += Vector2(-event.relative.x, event.relative.y) * 0.03 / zoom
			update_camera()
		else:
			var result := pick(event.position)
			hovered_crew = result.get("crew", "")
			hovered_station = result.get("station", "")
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			orbiting = event.pressed
			if event.pressed:
				right_distance = 0
			elif right_distance < 6:
				move_selected(event.position)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = event.pressed
		elif (
			event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
		):
			zoom = clampf(
				zoom * (1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12),
				0.70,
				3.5
			)
			update_camera()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var result := pick(event.position)
			if result.get("crew", "") != "":
				crew_picked.emit(result.crew)
			elif result.get("station", "") != "":
				station_picked.emit(result.station)
	accept_event()
	queue_redraw()


func _process(delta: float) -> void:
	if not is_instance_valid(viewport):
		return
	viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	)
	if not is_visible_in_tree() or state == null:
		return
	bind_people()
	for id in actors:
		actors[id].sync(state, model.navigation, id == selected_crew, id == hovered_crew, delta)
	model.sync(state, actors, delta)
	model.highlight(selected_station)
	update_camera()
	queue_redraw()


func _draw() -> void:
	# UI labels are separate from the modeled world, never used as room/crew artwork.
	if hovered_crew != "" and state != null:
		var person := state.member(hovered_crew)
		if person != null:
			draw_string(
				font,
				Vector2(16, size.y - 18),
				person.display_name + " / " + person.profession,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				16,
				Color("deedf0")
			)

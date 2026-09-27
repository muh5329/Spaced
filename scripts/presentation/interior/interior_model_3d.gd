class_name InteriorModel3D
extends Node3D
## Authored deck assembly. Fixture identities remain separate from rendered batches.
var blockers: Array[Rect2] = []
var fixtures: Array[Node3D] = []
var doors: Array[Dictionary] = []
var room_lights: Dictionary = {}
var room_nodes: Dictionary = {}
var navigation := InteriorNavigation.new()
var selection: MeshInstance3D
var selected_room: String = ""
var reactor_rotor: Node3D
var assembly: Node3D
var fixture_count: int = 0


func _ready() -> void:
	name = "ModeledDeck"
	assembly = Node3D.new()
	assembly.name = "Architecture"
	add_child(assembly)
	for key in InteriorLayout.ROOMS:
		var room := Node3D.new()
		room.name = key.to_pascal_case()
		add_child(room)
		room_nodes[key] = room
	build_floor()
	build_shell()
	build_partitions()
	furnish_airlock()
	furnish_quarters()
	furnish_mess()
	furnish_bridge()
	furnish_engineering()
	furnish_fabrication()
	furnish_storage()
	furnish_hydroponics()
	furnish_medbay()
	navigation.build(blockers)
	batch_static(assembly)
	for room in room_nodes.values():
		batch_static(room)
	InteriorStyle.apply(self)


func body(parent: Node3D, center: Vector3, size_value: Vector3, station: String) -> void:
	var collider := StaticBody3D.new()
	collider.set_meta("station", station)
	collider.collision_layer = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size_value
	shape.shape = box
	shape.position = center
	collider.add_child(shape)
	parent.add_child(collider)


func build_floor() -> void:
	# Floors are fully modeled including an exposed structural layer beneath the deck.
	for rect in InteriorLayout.floor_rects():
		InteriorProps.box(
			assembly,
			Vector3(rect.get_center().x, -0.34, rect.get_center().y),
			Vector3(rect.size.x, 0.6, rect.size.y),
			InteriorProps.FRAME
		)
	for key in InteriorLayout.ROOMS:
		var rect: Rect2 = InteriorLayout.ROOMS[key].rect
		body(
			room_nodes[key],
			Vector3(rect.get_center().x, -0.10, rect.get_center().y),
			Vector3(rect.size.x, 0.18, rect.size.y),
			key
		)
	for x in range(-5, 35):
		for z in range(0, 28):
			var point := Vector2(x * 0.7 + 0.35, z * 0.7 + 0.35)
			if not InteriorLayout.contains_floor(point):
				continue
			var room := InteriorLayout.room_at(Vector3(point.x, 0, point.y))
			var deck_height := InteriorLayout.floor_height(Vector3(point.x, 0, point.y))
			var tint := Color("5d616b") if room != "medbay" else Color("8fa9b1")
			if room == "bridge":
				tint = Color("676f7f")
			tint = tint.darkened(0.02 * posmod(x * 17 + z * 31, 6))
			InteriorProps.box(
				assembly,
				Vector3(point.x, deck_height - 0.025, point.y),
				Vector3(0.675, 0.08, 0.675),
				tint
			)
			if posmod(x * 11 + z * 3, 9) == 0:
				InteriorProps.box(
					assembly,
					Vector3(point.x - 0.24, deck_height + 0.019, point.y + 0.26),
					Vector3(0.05, 0.005, 0.035),
					InteriorProps.FRAME
				)


func hull_run(a: Vector2, b: Vector2) -> void:
	var length := a.distance_to(b)
	var center := (a + b) / 2
	var along_x := absf(a.x - b.x) > 0.1
	var thickness := 0.58
	var segments := maxi(1, ceili(length / 2.65))
	for i in segments:
		var t := (float(i) + 0.5) / segments
		var at := a.lerp(b, t)
		var size_value := (
			Vector3(length / segments - 0.03, 2.9, thickness)
			if along_x
			else Vector3(thickness, 2.9, length / segments - 0.03)
		)
		InteriorProps.box(assembly, Vector3(at.x, -0.62, at.y), size_value, Color("171e2b"))
		var cap := size_value
		cap.y = 0.16
		cap.x += 0.10
		cap.z += 0.10
		InteriorProps.box(assembly, Vector3(at.x, 0.88, at.y), cap, Color("414752"))
		if i % 3 == 1:
			cap.x *= 0.65
			cap.z *= 0.65
			cap.y = 0.026
			InteriorProps.box(assembly, Vector3(at.x, 0.98, at.y), cap, InteriorProps.GOLD)
		# Deep hull ribs and visible vent seams, present from the reverse view too.
		var rib := (
			Vector3(0.19, 3.12, thickness + 0.25)
			if along_x
			else Vector3(thickness + 0.25, 3.12, 0.19)
		)
		InteriorProps.box(assembly, Vector3(at.x, -0.66, at.y), rib, InteriorProps.FRAME)
		var outward := Vector2((b - a).normalized().y, -(b - a).normalized().x)
		var face := at + outward * 0.36
		var armor := (
			Vector3(length / segments * 0.85, 1.42 + 0.22 * (i % 2), 0.15)
			if along_x
			else Vector3(0.15, 1.42 + 0.22 * (i % 2), length / segments * 0.85)
		)
		InteriorProps.box(assembly, Vector3(face.x, -0.65, face.y), armor, Color("303747"))
		var strip := armor
		strip.y = 0.10
		strip.x += 0.025
		strip.z += 0.025
		for y in [-1.26, -0.03]:
			InteriorProps.box(assembly, Vector3(face.x, y, face.y), strip, InteriorProps.FRAME)
		var inset := armor
		inset.y = 0.48
		inset.x *= 0.78
		inset.z *= 0.78
		InteriorProps.box(
			assembly,
			Vector3(face.x + outward.x * 0.09, -0.54, face.y + outward.y * 0.09),
			inset,
			Color("202735")
		)
	blockers.append(
		Rect2(
			Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * thickness / 2,
			Vector2(absf(a.x - b.x), absf(a.y - b.y)) + Vector2.ONE * thickness
		)
	)


func build_shell() -> void:
	# Stepped outer silhouette: engine room projects left; greenhouse projects forward.
	var perimeter := [
		Vector2(0, 0),
		Vector2(24, 0),
		Vector2(24, 12),
		Vector2(23.2, 12),
		Vector2(23.2, 17.5),
		Vector2(15.5, 17.5),
		Vector2(15.5, 19),
		Vector2(7, 19),
		Vector2(7, 18.3),
		Vector2(-1.8, 18.3),
		Vector2(-1.8, 11.1),
		Vector2(-3, 11.1),
		Vector2(-3, 6),
		Vector2(0, 6),
		Vector2(0, 0)
	]
	for i in range(1, perimeter.size()):
		hull_run(perimeter[i - 1], perimeter[i])
	wall(Vector2(0, 0), Vector2(24, 0), 2.7)
	wall(Vector2(24, 0), Vector2(24, 11.7), 2.45)
	wall(Vector2(0, 0), Vector2(0, 5.8), 2.3)
	for x in [1.7, 6.0, 10.9, 15.0, 19.1, 22.6]:
		wall_module(Vector3(x, 1.45, 0.24), 1.65, x > 19)
	for z in [2.5, 6.5, 9.7]:
		var mount := Node3D.new()
		assembly.add_child(mount)
		mount.position = Vector3(23.7, 0, z)
		mount.rotation_degrees.y = -90
		wall_module(Vector3.ZERO, 1.45, true, mount)
	# Exterior equipment bays and yellow hull collars.
	for z in [7.1, 9.1, 13.0, 16.2]:
		var x := -3.48 if z < 11 else -2.23
		InteriorProps.box(
			assembly, Vector3(x, -0.12, z), Vector3(0.42, 1.25, 1.52), InteriorProps.FRAME
		)
		IndustrialDetail.vent(assembly, Vector3(x, 0.55, z), 0.50, 1.27, 9)
	for x in [0.0, 3.4, 9.3, 13.1]:
		var z := 18.63 if x < 7 else 19.30
		InteriorProps.box(
			assembly, Vector3(x, -0.18, z), Vector3(2.4, 1.2, 0.22), InteriorProps.FRAME
		)
		InteriorProps.box(
			assembly,
			Vector3(x, 0.12, z + 0.13),
			Vector3(1.25, 0.30, 0.035),
			InteriorProps.GOLD,
			0.15
		)


func wall(a: Vector2, b: Vector2, height: float = 2.05, station: String = "") -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var mid := (a + b) / 2
	var horizontal := absf(b.x - a.x) > absf(b.y - a.y)
	var size_value := Vector3(length, height, 0.34) if horizontal else Vector3(0.34, height, length)
	InteriorProps.box(assembly, Vector3(mid.x, height / 2, mid.y), size_value, InteriorProps.FRAME)
	var size_panel := size_value
	size_panel.y *= 0.78
	size_panel.x += 0.025
	size_panel.z += 0.025
	InteriorProps.box(
		assembly, Vector3(mid.x, height * 0.54, mid.y), size_panel, InteriorProps.PANEL
	)
	var trim := size_value
	trim.y = 0.13
	trim.x += 0.10
	trim.z += 0.10
	InteriorProps.box(assembly, Vector3(mid.x, height, mid.y), trim, InteriorProps.FRAME)
	var skirt := size_value
	skirt.y = 0.27
	skirt.x += 0.13
	skirt.z += 0.13
	InteriorProps.box(assembly, Vector3(mid.x, 0.18, mid.y), skirt, Color("333b47"))
	var rail := size_value
	rail.y = 0.045
	rail.x += 0.08
	rail.z += 0.08
	InteriorProps.box(
		assembly, Vector3(mid.x, height - 0.20, mid.y), rail, InteriorProps.EDGE.darkened(0.35)
	)
	blockers.append(
		Rect2(
			Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * 0.12,
			Vector2(absf(a.x - b.x), absf(a.y - b.y)) + Vector2.ONE * 0.24
		)
	)
	body(assembly, Vector3(mid.x, height / 2, mid.y), size_value, station)
	var count := int(length / (1.8 if station in ["engineering", "fabrication"] else 2.1))
	for i in count:
		var at := a.lerp(b, (i + 0.5) / count)
		var rib := Vector3(0.075, height, 0.30) if horizontal else Vector3(0.30, height, 0.075)
		InteriorProps.box(
			assembly, Vector3(at.x, height / 2, at.y), rib, InteriorProps.EDGE.darkened(0.22)
		)
		var service := Node3D.new()
		assembly.add_child(service)
		service.position = Vector3(at.x, height * 0.52, at.y)
		service.rotation.y = 0 if horizontal else PI / 2
		var face_height := minf(1.0, height * 0.58)
		var panel_width := 1.24 if i % 2 == 0 else 0.95
		for sign_value in [-1, 1]:
			InteriorProps.box(
				service,
				Vector3(0, 0, sign_value * 0.205),
				Vector3(panel_width, face_height, 0.045),
				Color("363d49")
			)
			InteriorProps.box(
				service,
				Vector3(0, -0.015, sign_value * 0.235),
				Vector3(panel_width * 0.82, face_height * 0.78, 0.025),
				Color("62636a") if i % 3 == 0 else Color("4b505c")
			)
			for corner in [-1, 1]:
				MeshKit.sphere(
					service,
					Vector3(corner * 0.37, face_height * 0.30, sign_value * 0.26),
					0.025,
					InteriorProps.EDGE
				)
				MeshKit.sphere(
					service,
					Vector3(corner * 0.37, -face_height * 0.30, sign_value * 0.26),
					0.025,
					InteriorProps.EDGE
				)
			InteriorProps.box(
				service,
				Vector3(0.23, 0.07, sign_value * 0.27),
				Vector3(0.10, 0.13, 0.015),
				InteriorProps.GOLD
			)
			for line in 3:
				InteriorProps.box(
					service,
					Vector3(-0.19, -face_height * 0.18 + line * 0.07, sign_value * 0.26),
					Vector3(0.25, 0.015, 0.012),
					InteriorProps.FRAME
				)
		if height > 1.8:
			InteriorProps.pipe(
				service,
				Vector3(-0.55, -height * 0.43, 0.21),
				Vector3(-0.55, height * 0.38, 0.21),
				0.035,
				InteriorProps.EDGE
			)
			InteriorProps.box(
				service,
				Vector3(0, height * 0.32, 0.26),
				Vector3(0.68, 0.045, 0.065),
				InteriorProps.WARM,
				1.2
			)


func partition(
	a: Vector2, b: Vector2, door_at: float, station: String, height: float = 2.0
) -> void:
	var direction := (b - a).normalized()
	var midpoint := a + direction * door_at
	var half := 0.69
	wall(a, midpoint - direction * half, height, station)
	wall(midpoint + direction * half, b, height, station)
	doorway(Vector3(midpoint.x, 0, midpoint.y), 0 if absf(direction.x) > 0.5 else PI / 2, station)


func doorway(point: Vector3, yaw: float, station: String) -> void:
	var root := Node3D.new()
	root.name = station + "PressureDoor"
	add_child(root)
	root.position = point
	root.rotation.y = yaw
	for x in [-0.74, 0.74]:
		InteriorProps.box(root, Vector3(x, 1.07, 0), Vector3(0.16, 2.14, 0.40), InteriorProps.FRAME)
	InteriorProps.box(root, Vector3(0, 2.16, 0), Vector3(1.62, 0.25, 0.43), InteriorProps.FRAME)
	InteriorProps.box(
		root, Vector3(0, 2.20, 0.23), Vector3(1.0, 0.045, 0.025), InteriorProps.WARM, 1.7
	)
	InteriorProps.box(root, Vector3(0, 0.035, 0), Vector3(1.44, 0.05, 0.54), InteriorProps.EDGE)
	for i in 10:
		var stripe := InteriorProps.box(
			root,
			Vector3(-0.59 + i * 0.13, 0.069, 0),
			Vector3(0.065, 0.012, 0.43),
			InteriorProps.GOLD if i % 2 == 0 else InteriorProps.FRAME
		)
		stripe.rotation.y = -0.36
	var left := InteriorProps.box(
		root, Vector3(-0.35, 0.92, 0), Vector3(0.67, 1.82, 0.13), InteriorProps.PANEL
	)
	var right := InteriorProps.box(
		root, Vector3(0.35, 0.92, 0), Vector3(0.67, 1.82, 0.13), InteriorProps.PANEL
	)
	for panel in [left, right]:
		InteriorProps.box(
			panel, Vector3(0, 0.08, 0.085), Vector3(0.06, 0.62, 0.04), InteriorProps.GOLD
		)
	doors.append({"root": root, "left": left, "right": right, "open": 0.0})


func wall_module(point: Vector3, width: float, cool: bool = false, parent: Node3D = null) -> void:
	var root := Node3D.new()
	(assembly if parent == null else parent).add_child(root)
	root.position = point
	InteriorProps.frame(root, Vector3.ZERO, Vector3(width, 1.9, 0.18))
	InteriorProps.box(
		root,
		Vector3(0, 0.72, 0.16),
		Vector3(width * 0.82, 0.075, 0.08),
		InteriorProps.CYAN if cool else InteriorProps.WARM,
		1.8
	)
	InteriorProps.screen(root, Vector3(0, 0.12, 0.17), Vector2(width * 0.64, 0.65), 2)
	for x in [-0.42, 0.42]:
		InteriorProps.pipe(
			root,
			Vector3(x * width, -0.75, 0.17),
			Vector3(x * width, 0.59, 0.17),
			0.033,
			InteriorProps.EDGE
		)


func build_partitions() -> void:
	partition(Vector2(4.1, 0.2), Vector2(4.1, 6), 4.55, "quarters", 1.8)
	partition(Vector2(10.1, 0.2), Vector2(10.1, 6), 4.45, "mess", 1.9)
	partition(Vector2(4.2, 6.1), Vector2(10, 6.1), 1.55, "quarters", 0.95)
	partition(Vector2(10.3, 5.0), Vector2(15.2, 5.0), 2.9, "mess", 1.2)
	partition(Vector2(19.65, 0.3), Vector2(19.65, 9.0), 6.3, "bridge", 1.12)
	partition(Vector2(-3, 6), Vector2(3.5, 6), 5.5, "engineering", 2.25)
	partition(Vector2(3.5, 6.1), Vector2(3.5, 11.1), 3.3, "engineering", 1.08)
	partition(Vector2(-1.8, 11.25), Vector2(6.8, 11.25), 6.7, "fabrication", 2.25)
	partition(Vector2(6.85, 11.4), Vector2(6.85, 18.3), 1.15, "fabrication", 1.35)
	partition(Vector2(7.0, 10.05), Vector2(12.4, 10.05), 1.2, "storage", 0.90)
	partition(Vector2(7.0, 13.6), Vector2(15.5, 13.6), 1.3, "hydroponics", 2.3)
	partition(Vector2(15.6, 12.0), Vector2(23.2, 12.0), 2.15, "medbay", 2.1)
	wall(Vector2(15.6, 13.8), Vector2(15.6, 17.5), 1.0, "medbay")
	# Windowed partition in front of the medbay, with modeled mullions.
	for x in [19.8, 21.0, 22.2]:
		InteriorProps.box(
			assembly, Vector3(x, 1.35, 11.86), Vector3(0.92, 0.65, 0.05), Color("264b58"), 0.22
		)


func fixture(
	station: String,
	title: String,
	point: Vector3,
	size_value: Vector3,
	builder: Callable,
	yaw: float = 0
) -> Node3D:
	var root := Node3D.new()
	root.name = title
	root.position = point
	root.rotation.y = yaw
	room_nodes[station].add_child(root)
	builder.call(root)
	root.set_meta("fixture", title)
	root.set_meta("station", station)
	fixtures.append(root)
	fixture_count += 1
	var extents := Vector2(
		absf(cos(yaw)) * size_value.x + absf(sin(yaw)) * size_value.z,
		absf(sin(yaw)) * size_value.x + absf(cos(yaw)) * size_value.z
	)
	if extents.x > 0 and extents.y > 0:
		blockers.append(Rect2(Vector2(point.x, point.z) - extents / 2, extents))
		body(root, Vector3(0, size_value.y / 2, 0), size_value, station)
	return root


func light(
	station: String, point: Vector3, color: Color, energy: float = 1.0, radius: float = 5.0
) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = point
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = radius
	lamp.omni_attenuation = 1.05
	lamp.shadow_enabled = station in ["engineering", "fabrication", "hydroponics"]
	room_nodes[station].add_child(lamp)
	if not room_lights.has(station):
		room_lights[station] = []
	room_lights[station].append({"node": lamp, "energy": energy})


func furnish_airlock() -> void:
	fixture(
		"airlock",
		"YellowPressurePump",
		Vector3(1.3, 0, 1.7),
		Vector3(1.5, 1.1, 1.4),
		func(p):
			InteriorProps.crate(p, Vector3(1.5, 1.0, 1.2), InteriorProps.GOLD)
			IndustrialDetail.vent(p, Vector3(0, 1.05, 0), 0.95, 0.75, 8)
	)
	fixture(
		"airlock",
		"SuitLocker",
		Vector3(0.65, 0, 4.7),
		Vector3(0.75, 2.1, 0.75),
		func(p): InteriorProps.locker(p, false, 2.1)
	)
	for z in [1.1, 2.0, 3.0]:
		InteriorProps.pipe(
			room_nodes.airlock,
			Vector3(0.4, 0.25, z),
			Vector3(0.4, 1.85, z),
			0.12,
			InteriorProps.PANEL
		)
	doorway(Vector3(1.95, 0, 0.43), 0, "airlock")
	fixture(
		"airlock",
		"PressureConsole",
		Vector3(3.4, 0, 1.0),
		Vector3(0.70, 1.0, 0.65),
		func(p): InteriorProps.console(p, 0.7)
	)
	light("airlock", Vector3(1.8, 2.3, 2.0), Color("ffc077"), 1.1, 4)


func furnish_quarters() -> void:
	for i in 3:
		fixture(
			"quarters",
			"Bunk%02d" % i,
			Vector3(7.6, 0, [1.2, 3.1, 4.5][i]),
			Vector3(1.3, 1, 2.3),
			func(p): InteriorProps.bed(p, i != 1),
			PI / 2
		)
	for i in 3:
		fixture(
			"quarters",
			"WhiteUtilityLocker%02d" % i,
			[Vector3(4.9, 0, 1.1), Vector3(4.9, 0, 2.4), Vector3(4.6, 0, 7.7)][i],
			Vector3(0.72, 0.98, 0.68),
			func(p): InteriorProps.locker(p, true, 0.96),
			PI
		)
	fixture(
		"quarters",
		"BedsideDrawer",
		Vector3(5.8, 0, 0.85),
		Vector3(0.72, 0.86, 0.68),
		func(p): InteriorProps.locker(p, true, 0.86)
	)
	light("quarters", Vector3(6.8, 2.6, 1.3), InteriorProps.WARM, 1.0, 5)
	for x in [4.8, 7.6, 9.0]:
		fixture(
			"quarters",
			"CorridorPlanter",
			Vector3(x, 0, 6.60),
			Vector3(0.62, 0.55, 0.60),
			func(p): InteriorProps.grow_bed(p, Vector2(0.65, 0.60), int(x * 13), 0.36)
		)


func furnish_mess() -> void:
	fixture(
		"mess",
		"GalleyCounter",
		Vector3(12.3, 0, 0.9),
		Vector3(3.7, 1.3, 0.96),
		InteriorProps.galley
	)
	fixture(
		"mess",
		"ColdStore",
		Vector3(10.8, 0, 2.5),
		Vector3(0.75, 2.0, 0.70),
		func(p): InteriorProps.locker(p, true, 2.0)
	)
	fixture(
		"mess",
		"GalleyIsland",
		Vector3(13.4, 0, 4.0),
		Vector3(2.0, 1.1, 0.85),
		func(p): InteriorProps.workbench(p, 2.0)
	)
	fixture(
		"mess",
		"BreakfastTable",
		Vector3(11.9, 0, 3.45),
		Vector3(0.85, 1.1, 0.85),
		func(p): InteriorProps.table(p, Vector2(0.85, 0.85))
	)
	fixture(
		"mess",
		"CommunalDiningTable",
		Vector3(16.4, 0, 7.0),
		Vector3(3.6, 1.1, 2.2),
		func(p): InteriorProps.table(p, Vector2(3.6, 2.2))
	)
	for x in [15.25, 16.40, 17.55]:
		for z in [5.35, 8.65]:
			fixture(
				"mess",
				"DiningChair",
				Vector3(x, 0, z),
				Vector3(0.62, 1.4, 0.62),
				InteriorProps.chair,
				0 if z < 7 else PI
			)
	for x in [14.05, 18.75]:
		fixture(
			"mess",
			"TableEndChair",
			Vector3(x, 0, 7),
			Vector3(0.62, 1.4, 0.62),
			InteriorProps.chair,
			-PI / 2 if x < 16 else PI / 2
		)
	fixture(
		"mess",
		"RoundCafeTable",
		Vector3(11.9, 0, 7.8),
		Vector3(1.1, 1.0, 1.1),
		func(p):
			MeshKit.cylinder(p, Vector3(0, 0.47, 0), 0.15, 0.92, InteriorProps.FRAME)
			MeshKit.cylinder(p, Vector3(0, 0.98, 0), 0.61, 0.12, InteriorProps.WOOD)
			MeshKit.cylinder(p, Vector3(0.1, 1.08, 0), 0.15, 0.04, InteriorProps.WHITE)
	)
	fixture(
		"mess",
		"CafeChair",
		Vector3(11.1, 0, 7.5),
		Vector3(0.6, 1.4, 0.6),
		InteriorProps.chair,
		-PI / 2
	)
	fixture(
		"mess",
		"RearKitchenGrowBed",
		Vector3(17.1, 0, 2.7),
		Vector3(3.0, 1.0, 1.7),
		func(p): InteriorProps.grow_bed(p, Vector2(3.0, 1.7), 811)
	)
	fixture(
		"mess",
		"ProduceBins",
		Vector3(17.1, 0, 0.70),
		Vector3(3.0, 0.8, 0.65),
		func(p): InteriorProps.grow_bed(p, Vector2(3.0, 0.65), 23, 0.6)
	)
	light("mess", Vector3(16.3, 3.4, 7.0), InteriorProps.WARM, 1.45, 6)
	light("mess", Vector3(12.2, 2.4, 1.5), InteriorProps.WARM, 1, 4)


func furnish_bridge() -> void:
	room_nodes.bridge.position.y = 0.18
	InteriorProps.box(
		assembly, Vector3(21.9, 0.045, 3.15), Vector3(4.0, 0.23, 5.95), Color("5d6672")
	)
	for z in [6.20, 6.36]:
		InteriorProps.box(
			assembly,
			Vector3(21.7, 0.04 if z > 6.3 else 0.10, z),
			Vector3(3.5, 0.08, 0.18),
			InteriorProps.EDGE
		)
	for z in [1.75, 3.55, 5.35]:
		fixture(
			"bridge",
			"MainCommandConsole",
			Vector3(23.10, 0, z),
			Vector3(1.65, 2.4, 0.75),
			func(p): InteriorProps.console(p, 1.7, true),
			-PI / 2
		)
	fixture(
		"bridge",
		"CommandChair",
		Vector3(21.75, 0, 3.6),
		Vector3(0.65, 1.4, 0.65),
		func(p): InteriorProps.chair(p, InteriorProps.PANEL),
		PI / 2
	)
	fixture(
		"bridge",
		"RearEquipmentRack",
		Vector3(21.8, 0, 0.67),
		Vector3(0.86, 2.3, 0.72),
		func(p): InteriorProps.locker(p, false, 2.3)
	)
	fixture(
		"bridge",
		"AstrogationConsole",
		Vector3(21.55, 0, 9.85),
		Vector3(2.5, 1.4, 0.85),
		func(p): InteriorProps.console(p, 2.5, true),
		PI
	)
	fixture(
		"bridge",
		"BridgeProduceCabinet",
		Vector3(20.7, 0, 7.65),
		Vector3(1.5, 0.9, 0.74),
		func(p): InteriorProps.grow_bed(p, Vector2(1.5, 0.75), 90, 0.75)
	)
	light("bridge", Vector3(22.5, 2.6, 3.0), Color("87c5ff"), 1.4, 5)
	light("bridge", Vector3(22, 2.6, 9.5), Color("65c4ed"), 0.7, 4)


func furnish_engineering() -> void:
	var reactor := fixture(
		"engineering",
		"MainHorizontalReactor",
		Vector3(0, 0, 8.15),
		Vector3(5.2, 2.1, 2.05),
		InteriorProps.reactor
	)
	reactor_rotor = reactor.get_node("Rotor")
	for x in [-2.0, -0.55, 1.0]:
		fixture(
			"engineering",
			"HeatExchanger",
			Vector3(x, 0, 6.45),
			Vector3(0.7, 2.2, 0.65),
			func(p):
				InteriorProps.frame(p, Vector3(0, 1.1, 0), Vector3(0.73, 2.1, 0.38))
				InteriorProps.box(
					p, Vector3(0, 1.35, 0.23), Vector3(0.3, 0.63, 0.05), Color("ef702b"), 1.6
				)
				InteriorProps.valve(p, Vector3(0, 0.70, 0.38))
		)
		InteriorProps.pipe(
			room_nodes.engineering,
			Vector3(x, 1.8, 6.8),
			Vector3(x, 1.8, 7.5),
			0.09,
			InteriorProps.GOLD
		)
		InteriorProps.pipe(
			room_nodes.engineering,
			Vector3(x, 1.8, 7.5),
			Vector3(x, 1.1, 7.5),
			0.09,
			InteriorProps.GOLD
		)
	fixture(
		"engineering",
		"ReactorServiceTerminal",
		Vector3(-2.2, 0, 10.2),
		Vector3(0.9, 1.2, 0.7),
		func(p): InteriorProps.console(p, 0.9)
	)
	light("engineering", Vector3(0, 2.6, 7.0), Color("ff9c46"), 3.2, 5)
	light("engineering", Vector3(-0.7, 1.1, 9.35), Color("ff741e"), 0.75, 3)


func furnish_fabrication() -> void:
	fixture(
		"fabrication",
		"YellowCNCPress",
		Vector3(3.0, 0, 15.1),
		Vector3(1.3, 2.0, 1.4),
		InteriorProps.fabricator
	)
	for x in [-0.45, 1.55]:
		fixture(
			"fabrication",
			"WallWorkbench",
			Vector3(x, 0, 12.0),
			Vector3(1.65, 1.3, 0.9),
			func(p): InteriorProps.workbench(p, 1.7, 1 if x < 0 else 2)
		)
		fixture(
			"fabrication",
			"ToolBoard",
			Vector3(x, 0, 11.65),
			Vector3(0, 0, 0),
			func(p):
				InteriorProps.frame(p, Vector3(0, 1.8, 0), Vector3(1.4, 0.72, 0.12))
				for i in 6:
					InteriorProps.pipe(
						p,
						Vector3(-0.48 + i * 0.19, 1.56, 0.12),
						Vector3(-0.48 + i * 0.19, 1.95, 0.12),
						0.025,
						InteriorProps.EDGE
					)
		)
	fixture(
		"fabrication",
		"StandingLathe",
		Vector3(5.8, 0, 14.0),
		Vector3(1.0, 2.1, 1.9),
		func(p):
			InteriorProps.crate(p, Vector3(0.9, 1.1, 1.8), InteriorProps.PANEL)
			InteriorProps.frame(p, Vector3(0, 1.55, 0), Vector3(0.82, 0.95, 1.3))
			InteriorProps.screen(p, Vector3(0, 1.65, 0.70), Vector2(0.50, 0.37))
	)
	fixture(
		"fabrication",
		"ForegroundAssemblyBench",
		Vector3(0.3, 0, 16.9),
		Vector3(2.1, 1.3, 1.0),
		func(p): InteriorProps.workbench(p, 2.1, 3)
	)
	fixture(
		"fabrication",
		"TallFabricationLocker",
		Vector3(5.9, 0, 16.7),
		Vector3(0.75, 2.0, 0.7),
		func(p): InteriorProps.locker(p, false, 2.0),
		-PI / 2
	)
	fixture(
		"fabrication",
		"SparePartCrate",
		Vector3(1.95, 0, 17.1),
		Vector3(0.70, 0.65, 0.70),
		func(p): InteriorProps.crate(p, Vector3(0.70, 0.65, 0.70), InteriorProps.GOLD)
	)
	fixture(
		"fabrication",
		"WeldingGasRack",
		Vector3(0.8, 0, 14.1),
		Vector3(1.0, 1.9, 0.65),
		func(p):
			InteriorProps.box(
				p, Vector3(0, 0.11, 0), Vector3(1.08, 0.22, 0.70), InteriorProps.FRAME
			)
			for x in [-0.32, 0.0, 0.32]:
				MeshKit.cylinder(p, Vector3(x, 0.95, 0), 0.13, 1.62, Color("343c46"))
				MeshKit.sphere(p, Vector3(x, 1.78, 0), 0.13, InteriorProps.WHITE)
				InteriorProps.pipe(
					p, Vector3(x, 1.84, 0), Vector3(x, 1.97, 0), 0.034, InteriorProps.GOLD
				)
	)
	fixture(
		"fabrication",
		"MachinePartsCabinet",
		Vector3(2.6, 0, 12.7),
		Vector3(0.8, 1.3, 0.75),
		func(p): InteriorProps.crate(p, Vector3(0.80, 1.3, 0.75), InteriorProps.PANEL)
	)
	fixture(
		"fabrication",
		"SideRepairDesk",
		Vector3(-1.03, 0, 14.7),
		Vector3(1.5, 1.2, 0.85),
		func(p): InteriorProps.workbench(p, 1.5),
		PI / 2
	)
	light("fabrication", Vector3(1.5, 3.0, 13.3), InteriorProps.WARM, 2.0, 6)


func furnish_storage() -> void:
	fixture(
		"storage",
		"PaleCentralContainer",
		Vector3(10.2, 0, 11.7),
		Vector3(1.4, 1.2, 1.3),
		func(p): InteriorProps.crate(p, Vector3(1.4, 1.2, 1.3), InteriorProps.WHITE)
	)
	fixture(
		"storage",
		"CargoUtilityRack",
		Vector3(11.8, 0, 12.6),
		Vector3(0.72, 1.8, 0.7),
		func(p): InteriorProps.locker(p, false, 1.8)
	)
	fixture(
		"storage",
		"PartsCrate",
		Vector3(9.45, 0, 12.8),
		Vector3(0.74, 0.65, 0.60),
		func(p):
			InteriorProps.crate(p, Vector3(0.74, 0.65, 0.60), InteriorProps.GOLD)
			var upper := Node3D.new()
			p.add_child(upper)
			upper.position = Vector3(.03, .68, 0)
			upper.rotation.y = -.12
			InteriorProps.crate(upper, Vector3(.62, .44, .54), InteriorProps.PANEL)
	)
	fixture(
		"storage",
		"SupplyShelf",
		Vector3(11.8, 0, 10.6),
		Vector3(0.74, 1.4, 0.64),
		func(p): InteriorProps.locker(p, true, 1.4)
	)
	light("storage", Vector3(9.5, 2.6, 11.4), InteriorProps.WARM, 0.65, 3.5)


func furnish_hydroponics() -> void:
	fixture(
		"hydroponics",
		"MainHydroponicGrowingBed",
		Vector3(11.2, 0, 16.7),
		Vector3(5.2, 1.15, 2.45),
		func(p): InteriorProps.grow_bed(p, Vector2(5.2, 2.45), 53)
	)
	for x in [9.6, 11.55, 13.5]:
		fixture(
			"hydroponics",
			"WallCropModule",
			Vector3(x, 0, 14.0),
			Vector3(1.4, 2.35, 0.80),
			InteriorProps.wall_garden
		)
	fixture(
		"hydroponics",
		"TealIrrigationColumn",
		Vector3(14.8, 0, 14.9),
		Vector3(0.7, 2.4, 0.7),
		func(p):
			InteriorProps.crate(p, Vector3(0.65, 2.3, 0.65), Color("397677"))
			for x in [-0.17, 0.17]:
				InteriorProps.pipe(
					p, Vector3(x, 0.2, 0.4), Vector3(x, 2.1, 0.4), 0.055, InteriorProps.CYAN
				)
	)
	light("hydroponics", Vector3(11.2, 2.7, 16.4), Color("d8efb6"), 1.65, 5)
	light("hydroponics", Vector3(14.5, 2.1, 14.4), Color("68cfca"), 0.55, 3)


func furnish_medbay() -> void:
	fixture(
		"medbay",
		"RedCrossTreatmentBed",
		Vector3(19.2, 0, 15.1),
		Vector3(1.9, 1.2, 2.5),
		InteriorProps.med_table
	)
	fixture(
		"medbay",
		"DiagnosticsCart",
		Vector3(21.2, 0, 14.0),
		Vector3(0.75, 1.6, 0.75),
		func(p): InteriorProps.console(p, 0.75, true),
		PI / 2
	)
	fixture(
		"medbay",
		"MedicalSupplyCabinet",
		Vector3(22.5, 0, 16.1),
		Vector3(0.7, 1.1, 0.7),
		func(p): InteriorProps.locker(p, true, 1.1),
		-PI / 2
	)
	fixture(
		"medbay",
		"TreatmentStool",
		Vector3(17.7, 0, 16.4),
		Vector3(0.48, 0.7, 0.48),
		func(p):
			MeshKit.cylinder(p, Vector3(0, 0.30, 0), 0.055, 0.60, InteriorProps.EDGE)
			MeshKit.cylinder(p, Vector3(0, 0.66, 0), 0.25, 0.14, InteriorProps.WHITE)
	)
	for x in [19.7, 21.8]:
		InteriorProps.screen(room_nodes.medbay, Vector3(x, 1.60, 12.19), Vector2(1.35, 0.68))
	light("medbay", Vector3(19.2, 2.8, 14.8), Color("b4d8e5"), 1.45, 5)


func sync(state: InteriorState, people: Dictionary, delta: float) -> void:
	if is_instance_valid(reactor_rotor) and state.powered.engineering:
		reactor_rotor.rotation.x = state.sim_seconds * 1.7 + state.accumulator * 1.7
	for key in room_lights:
		for entry in room_lights[key]:
			entry.node.light_energy = entry.energy if state.powered[key] else entry.energy * 0.06
	for door in doors:
		var opening := false
		for actor in people.values():
			if actor.visible and actor.position.distance_to(door.root.position) < 1.85:
				opening = true
				break
		door.open = move_toward(door.open, 1.0 if opening else 0.0, delta * 3.0)
		door.left.position.x = -0.35 - door.open * 0.64
		door.right.position.x = 0.35 + door.open * 0.64


func highlight(key: String) -> void:
	if selected_room == key:
		return
	selected_room = key
	if is_instance_valid(selection):
		selection.queue_free()
	if not InteriorLayout.ROOMS.has(key):
		return
	var rect: Rect2 = InteriorLayout.ROOMS[key].rect
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	var corners := [
		Vector3(rect.position.x, 0.06, rect.position.y),
		Vector3(rect.end.x, 0.06, rect.position.y),
		Vector3(rect.end.x, 0.06, rect.end.y),
		Vector3(rect.position.x, 0.06, rect.end.y)
	]
	for i in 4:
		st.add_vertex(corners[i])
		st.add_vertex(corners[(i + 1) % 4])
	selection = MeshInstance3D.new()
	selection.mesh = st.commit()
	selection.material_override = MeshKit.material(Color("88d9dc"), 0.7)
	add_child(selection)


func batch_static(root: Node3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	collect_meshes(root, meshes)
	var groups: Dictionary = {}
	for part in meshes:
		if part.material_override == null:
			continue
		var id := part.material_override.get_instance_id()
		if not groups.has(id):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_material(part.material_override)
			groups[id] = st
		groups[id].append_from(
			part.mesh, 0, root.global_transform.affine_inverse() * part.global_transform
		)
	for id in groups:
		var mesh := MeshInstance3D.new()
		mesh.name = "BatchedSurface"
		mesh.mesh = groups[id].commit()
		root.add_child(mesh)
	for part in meshes:
		part.get_parent().remove_child(part)
		part.free()


func collect_meshes(root: Node, target: Array[MeshInstance3D]) -> void:
	for child in root.get_children():
		if child.has_meta("animated"):
			continue
		if child is MeshInstance3D:
			target.append(child)
		else:
			collect_meshes(child, target)

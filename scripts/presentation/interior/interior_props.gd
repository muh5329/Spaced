class_name InteriorProps
extends RefCounted
## Reusable, volumetric furniture and ship machinery. Every part is a real mesh.
const FRAME := Color("242c39")
const PANEL := Color("575d69")
const EDGE := Color("8b9097")
const WHITE := Color("cbd0c9")
const GOLD := Color("c58a37")
const WOOD := Color("af8b55")
const CYAN := Color("42b5de")
const WARM := Color("ffd699")
const DARK := Color("111a24")


static func box(p: Node3D, v: Vector3, s: Vector3, c: Color, glow: float = 0) -> MeshInstance3D:
	return MeshKit.box(p, v, s, c, glow)


static func pipe(
	p: Node3D, a: Vector3, b: Vector3, radius: float = 0.05, color: Color = EDGE
) -> void:
	IndustrialDetail.pipe(p, a, b, radius, color)


static func frame(p: Node3D, center: Vector3, size: Vector3) -> void:
	box(p, center, size, FRAME)
	box(
		p, center + Vector3(0, 0, size.z * 0.51), Vector3(size.x * 0.85, size.y * 0.83, 0.06), PANEL
	)
	for x in [-1, 1]:
		for y in [-1, 1]:
			MeshKit.sphere(
				p,
				center + Vector3(x * size.x * 0.43, y * size.y * 0.43, size.z * 0.53),
				0.026,
				EDGE
			)


static func screen(p: Node3D, point: Vector3, size: Vector2, variant: int = 0) -> void:
	box(p, point, Vector3(size.x + 0.13, size.y + 0.13, 0.12), FRAME)
	box(p, point + Vector3(0, 0, 0.067), Vector3(size.x, size.y, 0.026), Color("123e5b"), 0.6)
	# Physical illuminated traces: no image or billboard stands in for the console.
	for i in 7:
		var width := size.x * (0.22 + 0.11 * ((i + variant) % 5))
		box(
			p,
			point + Vector3(-size.x * 0.42 + width / 2, size.y * (0.39 - i * 0.115), 0.084),
			Vector3(width, 0.014, 0.007),
			CYAN if i % 3 != 0 else Color("9bd1df"),
			1.0
		)
	for i in 4:
		box(
			p,
			point + Vector3(size.x * 0.34, size.y * (0.28 - i * 0.18), 0.086),
			Vector3(size.x * 0.09, size.y * 0.055, 0.007),
			GOLD if i == 2 else CYAN,
			0.8
		)


static func console(p: Node3D, width: float = 1.7, wall: bool = false) -> void:
	box(p, Vector3(0, 0.49, 0), Vector3(width, 0.94, 0.64), FRAME)
	box(p, Vector3(0, 0.46, 0.34), Vector3(width * 0.9, 0.57, 0.07), PANEL)
	for x in [-0.36, 0.36]:
		IndustrialDetail.vent(p, Vector3(x * width, 0.94, 0.03), width * 0.24, 0.38, 6)
	var desk := Node3D.new()
	p.add_child(desk)
	desk.position = Vector3(0, 1.0, 0)
	desk.rotation_degrees.x = -58
	screen(desk, Vector3.ZERO, Vector2(width * 0.65, 0.47))
	for i in 9:
		box(
			desk,
			Vector3((i - 4) * width * 0.085, -0.30, 0.10),
			Vector3(0.07, 0.04, 0.025),
			GOLD if i % 3 == 0 else EDGE,
			0.25
		)
	if wall:
		screen(p, Vector3(0, 1.85, -0.24), Vector2(width * 0.86, 1.04), 2)


static func chair(p: Node3D, color: Color = GOLD) -> void:
	MeshKit.cylinder(p, Vector3(0, 0.08, 0), 0.34, 0.08, FRAME)
	pipe(p, Vector3(0, 0.12, 0), Vector3(0, 0.58, 0), 0.08, PANEL)
	box(p, Vector3(0, 0.59, 0), Vector3(0.57, 0.16, 0.57), FRAME)
	box(p, Vector3(0, 0.70, 0.03), Vector3(0.52, 0.12, 0.50), color)
	box(p, Vector3(0, 1.06, -0.27), Vector3(0.55, 0.72, 0.12), FRAME)
	box(p, Vector3(0, 1.09, -0.19), Vector3(0.44, 0.58, 0.08), color)
	for sign_value in [-1, 1]:
		pipe(
			p,
			Vector3(sign_value * 0.33, 0.63, -0.2),
			Vector3(sign_value * 0.33, 0.94, 0.05),
			0.032,
			EDGE
		)
		box(p, Vector3(sign_value * 0.33, 0.95, 0.07), Vector3(0.09, 0.06, 0.35), FRAME)


static func bed(p: Node3D, orange: bool = true) -> void:
	box(p, Vector3(0, 0.29, 0), Vector3(1.25, 0.44, 2.23), FRAME)
	for z in [-1.06, 1.06]:
		box(p, Vector3(0, 0.56, z), Vector3(1.33, 0.64, 0.10), PANEL)
	box(p, Vector3(0, 0.60, 0), Vector3(1.14, 0.27, 1.98), WHITE)
	box(p, Vector3(0, 0.77, -0.7), Vector3(0.88, 0.13, 0.38), Color("e4dfce"))
	box(p, Vector3(0, 0.76, 0.30), Vector3(1.15, 0.07, 0.88), GOLD if orange else PANEL)
	for x in [-0.58, 0.58]:
		box(p, Vector3(x, 0.20, 0), Vector3(0.08, 0.22, 1.84), EDGE)


static func locker(p: Node3D, white: bool = false, height: float = 1.2) -> void:
	box(p, Vector3(0, height / 2, 0), Vector3(0.72, height, 0.68), WHITE if white else PANEL)
	box(p, Vector3(0, height / 2, 0.35), Vector3(0.62, height * 0.83, 0.035), FRAME)
	for i in 3:
		box(
			p,
			Vector3(0, height * (0.23 + i * 0.25), 0.38),
			Vector3(0.54, height * 0.21, 0.032),
			WHITE if white else PANEL
		)
		box(p, Vector3(0, height * (0.25 + i * 0.25), 0.41), Vector3(0.18, 0.025, 0.02), DARK)
	IndustrialDetail.vent(p, Vector3(0, height + 0.02, 0), 0.38, 0.40, 5)


static func table(p: Node3D, size: Vector2, dining: bool = true) -> void:
	for x in [-1, 1]:
		for z in [-1, 1]:
			box(
				p,
				Vector3(x * size.x * 0.38, 0.45, z * size.y * 0.36),
				Vector3(0.13, 0.90, 0.13),
				FRAME
			)
	box(p, Vector3(0, 0.98, 0), Vector3(size.x, 0.17, size.y), WOOD if dining else EDGE)
	box(p, Vector3(0, 0.87, 0), Vector3(size.x * 0.96, 0.09, size.y * 0.92), FRAME)
	if dining:
		for x in [-0.32, 0.0, 0.32]:
			for z in [-0.34, 0.34]:
				MeshKit.cylinder(p, Vector3(x * size.x, 1.084, z * size.y), 0.13, 0.025, WHITE)
				MeshKit.cylinder(p, Vector3(x * size.x + 0.21, 1.13, z * size.y), 0.058, 0.14, EDGE)
		MeshKit.cylinder(p, Vector3(0, 1.19, 0), 0.25, 0.20, Color("713f2e"))
		MeshKit.sphere(p, Vector3(0, 1.36, 0), 0.15, GOLD)


static func crate(p: Node3D, size: Vector3, tint: Color = PANEL) -> void:
	box(p, Vector3(0, size.y / 2, 0), size, FRAME)
	box(
		p,
		Vector3(0, size.y / 2, size.z * 0.5 + 0.012),
		Vector3(size.x * 0.87, size.y * 0.82, 0.04),
		tint
	)
	box(p, Vector3(0, size.y + 0.02, 0), Vector3(size.x * 0.89, 0.07, size.z * 0.86), tint)
	for x in [-1, 1]:
		box(
			p,
			Vector3(x * size.x * 0.35, size.y * 0.5, size.z * 0.53),
			Vector3(0.06, size.y * 0.95, 0.07),
			EDGE
		)
	box(
		p,
		Vector3(size.x * 0.24, size.y * 0.60, size.z * 0.56),
		Vector3(size.x * 0.23, size.y * 0.16, 0.01),
		GOLD
	)


static func reactor(p: Node3D) -> void:
	# Cylinder axis is local X, matching the prominent diagonal in the reference.
	var core := Node3D.new()
	p.add_child(core)
	core.position.y = 1.1
	core.rotation_degrees.z = 90
	MeshKit.cylinder(core, Vector3.ZERO, 0.87, 4.8, FRAME)
	for y in [-2.22, -1.85, -1.24, -0.48, 0.42, 1.15, 1.86, 2.22]:
		MeshKit.cylinder(
			core,
			Vector3(0, y, 0),
			0.94 if absf(y) > 1.5 else 0.91,
			0.20 if absf(y) > 1.5 else 0.48,
			Color("c96c2d") if absf(y) < 0.6 else EDGE
		)
		MeshKit.cylinder(core, Vector3(0, y + 0.10, 0), 0.95, 0.075, DARK)
	for sign_value in [-1, 1]:
		MeshKit.cylinder(core, Vector3(0, sign_value * 2.48, 0), 0.56, 0.16, PANEL)
		MeshKit.cylinder(core, Vector3(0, sign_value * 2.59, 0), 0.40, 0.07, GOLD)
		MeshKit.cylinder(
			core, Vector3(0, sign_value * 2.65, 0), 0.24, 0.045, Color("ff8d3c"), -1, 1.8
		)
	for i in 10:
		var angle := i * TAU / 10
		pipe(
			core,
			Vector3(sin(angle) * 0.85, -2.1, cos(angle) * 0.85),
			Vector3(sin(angle) * 0.85, 2.1, cos(angle) * 0.85),
			0.055,
			PANEL
		)
	for x in [-1.65, 1.65]:
		box(p, Vector3(x, 0.25, 0), Vector3(0.62, 0.50, 1.65), FRAME)
	for x in [-2.1, -1.3, 0.8, 1.65]:
		box(p, Vector3(x, 1.82, 0.21), Vector3(0.38, 0.30, 0.64), PANEL)
		box(p, Vector3(x, 1.98, 0.21), Vector3(0.25, 0.06, 0.40), GOLD)
		for z in [-0.15, 0.50]:
			MeshKit.sphere(p, Vector3(x, 2.0, z), 0.039, EDGE)
	for z in [-0.50, 0.52]:
		pipe(p, Vector3(-2.25, 0.67, z), Vector3(2.2, 0.67, z), 0.085, PANEL)
		pipe(p, Vector3(2.2, 0.67, z), Vector3(2.2, 1.45, z), 0.085, GOLD)
	# Offset service manifold, insulated elbow and a mechanical gauge break the
	# clean cylinder silhouette while staying within the registered footprint.
	box(p, Vector3(1.54, 1.48, .70), Vector3(.86, .47, .48), FRAME)
	box(p, Vector3(1.54, 1.49, .97), Vector3(.70, .33, .055), Color("be742d"))
	for x in [1.28, 1.8]:
		pipe(p, Vector3(x, 1.29, .88), Vector3(x, .52, .88), .075, EDGE)
	valve(p, Vector3(1.55, 1.55, 1.02))
	for i in 3:
		var gauge := MeshKit.cylinder(p, Vector3(-1.16 + i * .32, 1.56, .84), .115, .08, EDGE)
		gauge.rotation.x = PI / 2
		box(p, Vector3(-1.16 + i * .32, 1.57, .89), Vector3(.014, .095, .015), DARK)
	pipe(p, Vector3(-.78, 1.31, .90), Vector3(-.78, .54, .90), .09, Color("784c2b"))
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.set_meta("animated", true)
	rotor.position = Vector3(-2.75, 1.1, 0)
	p.add_child(rotor)
	for i in 8:
		var angle := TAU * i / 8
		pipe(rotor, Vector3.ZERO, Vector3(0, cos(angle) * 0.44, sin(angle) * 0.44), 0.065, FRAME)
	for x in [-2.43, 2.43]:
		for i in 10:
			var angle := TAU * i / 10
			MeshKit.sphere(p, Vector3(x, 1.1 + cos(angle) * 0.61, sin(angle) * 0.61), 0.048, EDGE)


static func valve(p: Node3D, center: Vector3) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.25
	mesh.outer_radius = 0.30
	mesh.rings = 20
	mesh.ring_segments = 8
	var wheel := MeshKit.part(p, mesh, center, GOLD)
	wheel.rotation_degrees.x = 90
	for i in 4:
		var angle := TAU * i / 4
		pipe(p, center, center + Vector3(cos(angle) * 0.27, sin(angle) * 0.27, 0), 0.035, GOLD)


static func plant(p: Node3D, base: Vector3, seed_value: int, scale_value: float = 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	pipe(p, base, base + Vector3(0, 0.48 * scale_value, 0), 0.017 * scale_value, Color("527536"))
	for i in 7:
		var angle := i * 2.4 + rng.randf_range(-0.25, 0.25)
		var species := seed_value % 3
		var leaf := MeshKit.sphere(
			p,
			base + Vector3(cos(angle) * 0.18, 0.16 + i * 0.043, sin(angle) * 0.18) * scale_value,
			0.20 * scale_value,
			[Color("4b7835"), Color("7c9d3f"), Color("355b2f"), Color("95b755")][i % 4]
		)
		leaf.scale = Vector3(
			0.90 if species == 0 else 0.60,
			0.20 if species == 1 else 0.13,
			1.3 if species == 0 else 1.75
		)
		leaf.position.y += rng.randf_range(-0.04, 0.09)
		leaf.rotation = Vector3(0.28, -angle + PI / 2, rng.randf_range(-0.3, 0.3))


static func grow_bed(p: Node3D, size: Vector2, seed_value: int = 30, height: float = 0.55) -> void:
	box(p, Vector3(0, height / 2, 0), Vector3(size.x, height, size.y), WHITE)
	box(
		p,
		Vector3(0, height + 0.015, 0),
		Vector3(size.x - 0.16, 0.05, size.y - 0.16),
		Color("2a3023")
	)
	for z in [-1, 1]:
		box(
			p,
			Vector3(0, height + 0.10, z * size.y * 0.5),
			Vector3(size.x + 0.08, 0.18, 0.09),
			WHITE
		)
	for x in [-1, 1]:
		box(p, Vector3(x * size.x * 0.5, height + 0.10, 0), Vector3(0.09, 0.18, size.y), WHITE)
	var columns := maxi(1, int(size.x / 0.52))
	var rows := maxi(1, int(size.y / 0.52))
	for x in columns:
		for z in rows:
			var point := Vector3(
				(x + 0.5) * size.x / columns - size.x / 2,
				height + 0.05,
				(z + 0.5) * size.y / rows - size.y / 2
			)
			plant(p, point, seed_value + x * 91 + z, 0.80 + 0.2 * sin(x * 7 + z * 3))


static func wall_garden(p: Node3D) -> void:
	frame(p, Vector3(0, 1.22, 0), Vector3(1.4, 2.0, 0.3))
	box(p, Vector3(0, 1.25, 0.18), Vector3(1.16, 1.58, 0.08), Color("224d45"), 0.35)
	for y in [0.5, 1.1, 1.65]:
		box(p, Vector3(0, y, 0.35), Vector3(1.18, 0.15, 0.40), GOLD.darkened(0.2))
		for x in [-0.4, 0, 0.4]:
			plant(p, Vector3(x, y + 0.12, 0.40), int(y * 30 + x * 4 + 70), 0.62)
	box(p, Vector3(0, 2.25, 0.29), Vector3(1.35, 0.06, 0.10), Color("d4efb8"), 1.5)


static func med_table(p: Node3D) -> void:
	box(p, Vector3(0, 0.41, 0), Vector3(1.05, 0.7, 1.85), FRAME)
	box(p, Vector3(0, 0.87, 0), Vector3(1.55, 0.23, 2.42), WHITE)
	box(p, Vector3(0, 1.006, 0.12), Vector3(0.28, 0.018, 0.88), Color("bd493e"))
	box(p, Vector3(0, 1.016, 0.12), Vector3(0.86, 0.018, 0.28), Color("bd493e"))
	box(p, Vector3(0, 1.07, -0.86), Vector3(1.10, 0.20, 0.44), Color("e1e0d0"))
	for x in [-0.88, 0.88]:
		pipe(p, Vector3(x, 0.5, -0.8), Vector3(x, 1.08, -0.8), 0.04)
		pipe(p, Vector3(x, 1.08, -0.8), Vector3(x, 1.08, 0.65), 0.04)
	for z in [-0.92, 0.92]:
		for x in [-0.5, 0.5]:
			MeshKit.sphere(p, Vector3(x, 0.10, z), 0.10, DARK)


static func fabricator(p: Node3D) -> void:
	box(p, Vector3(0, 0.28, 0), Vector3(1.25, 0.55, 1.32), GOLD)
	box(p, Vector3(0, 0.68, 0.10), Vector3(1.08, 0.23, 1.08), FRAME)
	for x in [-0.49, 0.49]:
		box(p, Vector3(x, 1.18, -0.36), Vector3(0.18, 1.3, 0.27), GOLD)
	box(p, Vector3(0, 1.84, -0.36), Vector3(1.24, 0.23, 0.41), GOLD)
	pipe(p, Vector3(0, 1.8, -0.32), Vector3(0, 1.0, -0.32), 0.075, EDGE)
	box(p, Vector3(0, 0.85, 0.10), Vector3(0.48, 0.16, 0.45), PANEL)
	box(p, Vector3(-0.36, 0.35, 0.68), Vector3(0.30, 0.40, 0.05), PANEL)
	box(p, Vector3(0.39, 1.0, -0.2), Vector3(0.22, 0.50, 0.35), FRAME)
	for i in 4:
		box(p, Vector3(-0.30 + i * 0.2, 0.39, 0.72), Vector3(0.08, 0.025, 0.015), DARK)
	pipe(p, Vector3(-0.65, 0.5, -0.2), Vector3(-0.65, 1.6, -0.2), 0.055, EDGE)
	var motor := MeshKit.cylinder(p, Vector3(0, 1.96, -0.3), 0.24, 0.38, FRAME)
	motor.rotation_degrees.z = 90
	box(p, Vector3(0, 1.53, -0.45), Vector3(0.95, 0.60, 0.42), GOLD)
	box(p, Vector3(0, 1.08, -0.05), Vector3(0.32, 0.40, 0.35), PANEL)
	box(p, Vector3(0.72, 0.58, -0.32), Vector3(0.25, 0.76, 0.54), FRAME)
	box(p, Vector3(0.87, 0.62, -0.32), Vector3(0.035, 0.46, 0.30), GOLD)
	pipe(p, Vector3(-0.52, 0.70, -0.2), Vector3(-0.32, 1.44, -0.25), 0.07, EDGE)
	var controls := Node3D.new()
	p.add_child(controls)
	controls.position = Vector3(0, 0.70, 0.73)
	controls.rotation_degrees.x = -25
	screen(controls, Vector3.ZERO, Vector2(0.61, 0.25))


static func workbench(p: Node3D, width: float = 1.7, variant: int = 0) -> void:
	table(p, Vector2(width, 0.85), false)
	box(p, Vector3(-width * 0.23, 0.48, 0), Vector3(width * 0.4, 0.87, 0.70), GOLD)
	for i in 3:
		box(
			p,
			Vector3(-width * 0.23, 0.25 + i * 0.23, 0.37),
			Vector3(width * 0.32, 0.035, 0.02),
			DARK
		)
	box(p, Vector3(width * 0.17, 1.11, 0.04), Vector3(0.46, 0.16, 0.35), FRAME)
	pipe(
		p,
		Vector3(width * 0.17 - 0.2, 1.2, 0.04),
		Vector3(width * 0.17 + 0.2, 1.2, 0.04),
		0.028,
		EDGE
	)
	for i in 4:
		var tool_root := Node3D.new()
		p.add_child(tool_root)
		tool_root.position = Vector3(-width * 0.36 + i * 0.16, 1.09, -0.22)
		tool_root.rotation.y = .12 * (i + variant)
		box(tool_root, Vector3.ZERO, Vector3(0.035, 0.035, 0.23), EDGE)
		box(tool_root, Vector3(0, 0, .10), Vector3(.095, .05, .07), EDGE)
		box(tool_root, Vector3(0, .03, .13), Vector3(.038, .012, .06), DARK)
	if variant == 1:
		# Bench-mounted drill: spindle, drive housing, feed lever and clamped stock.
		box(p, Vector3(.42, 1.12, -.06), Vector3(.44, .13, .50), FRAME)
		pipe(p, Vector3(.42, 1.1, -.24), Vector3(.42, 1.95, -.24), .06)
		box(p, Vector3(.42, 1.89, -.06), Vector3(.34, .24, .54), GOLD)
		pipe(p, Vector3(.42, 1.78, .09), Vector3(.42, 1.39, .09), .028)
		pipe(p, Vector3(.58, 1.82, -.03), Vector3(.79, 1.64, .02), .024)
	elif variant == 2:
		# Open electronics housing, copper traces and separate component trays.
		box(p, Vector3(.30, 1.26, -.04), Vector3(.48, .24, .39), GOLD)
		box(p, Vector3(.30, 1.39, -.04), Vector3(.40, .025, .32), Color("265b49"))
		for i in 4:
			box(p, Vector3(.15 + .09 * i, 1.41, -.04), Vector3(.023, .016, .27), GOLD)
			box(p, Vector3(.15 + .09 * i, 1.44, .02), Vector3(.058, .04, .09), FRAME)
	elif variant == 3:
		# Vise and a disassembled motor on the front assembly table.
		box(p, Vector3(-.47, 1.18, .12), Vector3(.43, .18, .34), PANEL)
		for x in [-.64, -.32]:
			box(p, Vector3(x, 1.34, .12), Vector3(.08, .18, .34), EDGE)
		pipe(p, Vector3(-.47, 1.18, .22), Vector3(-.47, 1.18, .60), .034)
		var motor := MeshKit.cylinder(p, Vector3(.51, 1.29, -.06), .19, .43, PANEL)
		motor.rotation.z = PI / 2
		for x in [.36, .45, .54, .63]:
			var fin := MeshKit.cylinder(p, Vector3(x, 1.29, -.06), .22, .023, FRAME)
			fin.rotation.z = PI / 2


static func galley(p: Node3D) -> void:
	box(p, Vector3(0, 0.52, 0), Vector3(3.6, 1.04, 0.86), PANEL)
	box(p, Vector3(0, 1.09, 0), Vector3(3.74, 0.12, 0.96), EDGE)
	for x in [-1.2, 0.0, 1.2]:
		box(p, Vector3(x, 0.52, 0.46), Vector3(1.05, 0.76, 0.06), FRAME)
		box(p, Vector3(x, 0.75, 0.51), Vector3(0.25, 0.035, 0.025), EDGE)
	for x in [0.7, 1.2]:
		MeshKit.cylinder(p, Vector3(x, 1.18, 0), 0.19, 0.03, DARK)
		MeshKit.cylinder(p, Vector3(x, 1.29, 0), 0.15, 0.2, PANEL)
	box(p, Vector3(-1.1, 1.17, 0), Vector3(0.64, 0.06, 0.55), DARK)
	pipe(p, Vector3(-1.3, 1.16, -0.3), Vector3(-1.3, 1.52, -0.3), 0.03, EDGE)
	pipe(p, Vector3(-1.3, 1.52, -0.3), Vector3(-1.3, 1.52, 0), 0.03, EDGE)

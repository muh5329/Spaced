class_name IndustrialDetail
extends RefCounted
## Shared physical fittings: segmented armor, vents, pipes and inhabited workstations.

static func armor(parent: Node3D, center: Vector3, size: Vector3, tint: Color) -> void:
	MeshKit.box(parent, center, size, tint)
	var top := center.y + size.y * 0.5 + 0.012
	for x in [-1, 1]:
		for z in [-1, 1]:
			MeshKit.cylinder(parent, Vector3(center.x + x * (size.x * 0.5 - 0.09), top, center.z + z * (size.z * 0.5 - 0.09)), 0.035, 0.025, MeshKit.INK)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(int((center.x * 57 + center.z * 139) * 100)) + 901
	for i in 5:
		var chip := Vector3(center.x + rng.randf_range(-0.44, 0.44) * size.x, top, center.z + rng.randf_range(-0.46, 0.46) * size.z)
		MeshKit.box(parent, chip, Vector3(rng.randf_range(0.025, 0.10), 0.008, rng.randf_range(0.02, 0.12)), tint.darkened(0.55))

static func vent(parent: Node3D, center: Vector3, width: float, length: float, count: int = 8) -> void:
	MeshKit.box(parent, center, Vector3(width, 0.10, length), MeshKit.INK)
	for i in count:
		MeshKit.box(parent, center + Vector3(0, 0.065, (float(i) / count - 0.44) * length), Vector3(width * 0.87, 0.045, length / count * 0.35), MeshKit.STEEL)

static func pipe(parent: Node3D, start: Vector3, end: Vector3, radius: float, tint: Color) -> void:
	var part := MeshKit.cylinder(parent, (start + end) * 0.5, radius, start.distance_to(end), tint)
	var direction := (end - start).normalized()
	part.basis = Basis.looking_at(direction, Vector3.FORWARD if absf(direction.y) > 0.99 else Vector3.UP) * Basis(Vector3.RIGHT, PI / 2)

static func person(parent: Node3D, point: Vector3, uniform: Color = MeshKit.GOLD, seated: bool = false) -> Node3D:
	var actor := Node3D.new()
	parent.add_child(actor)
	actor.position = point
	MeshKit.box(actor, Vector3(0, 0.72, 0), Vector3(0.43, 0.63, 0.27), uniform)
	MeshKit.box(actor, Vector3(0, 0.85, -0.147), Vector3(0.15, 0.18, 0.04), MeshKit.INK)
	MeshKit.box(actor, Vector3(0, 0.52, -0.02), Vector3(0.44, 0.06, 0.29), MeshKit.INK)
	MeshKit.sphere(actor, Vector3(0, 1.2, 0), 0.20, Color("b88b65"))
	MeshKit.box(actor, Vector3(0, 1.32, 0.015), Vector3(0.36, 0.10, 0.32), MeshKit.INK)
	for side in [-1, 1]:
		pipe(actor, Vector3(side * 0.26, 0.94, 0), Vector3(side * 0.32, 0.50, -0.05 if not seated else -0.4), 0.085, uniform)
		MeshKit.box(actor, Vector3(side * 0.12, 0.26, -0.12 if seated else 0), Vector3(0.16, 0.50, 0.22), MeshKit.INK)
		MeshKit.box(actor, Vector3(side * 0.12, 0.07, -0.12), Vector3(0.19, 0.12, 0.32), Color("20242a"))
	MeshKit.bake(actor)
	return actor

static func screen(parent: Node3D, point: Vector3, size: Vector2, tint: Color = MeshKit.CYAN) -> void:
	MeshKit.box(parent, point, Vector3(size.x + 0.16, size.y + 0.14, 0.16), MeshKit.INK)
	MeshKit.box(parent, point + Vector3(0, 0, 0.10), Vector3(size.x, size.y, 0.025), tint.darkened(0.72), 0.8)
	for i in 5:
		MeshKit.box(parent, point + Vector3(-size.x * 0.20, size.y * (0.32 - i * 0.15), 0.12), Vector3(size.x * (0.49 + (i % 3) * 0.10), 0.025, 0.01), tint, 1.2)
	MeshKit.box(parent, point + Vector3(size.x * 0.33, 0, 0.12), Vector3(0.045, size.y * 0.65, 0.01), MeshKit.GOLD, 0.9)

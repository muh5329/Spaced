class_name ShipModel
extends Node3D
## Long axial hull, four drives, recessed machinery and a real midship hold.
var flames: Array[MeshInstance3D] = []
var flame_origins: Array[Vector3] = []
var throttle: float = 0.15
var clock: float = 0.0
var pirate: bool = false
var derelict: bool = false
var cargo_hold: CargoBayModel
var hatch_doors: Array[Node3D] = []
var hatch_open: bool = false
var hatch_amount: float = 0.0

func _init(is_pirate: bool = false, is_derelict: bool = false) -> void:
	pirate = is_pirate
	derelict = is_derelict

func _ready() -> void:
	var armor := Color("8b9295") if not pirate else Color("665d5a")
	var accent := Color("c38a32") if not pirate else MeshKit.RED.darkened(0.3)
	var glow := MeshKit.CYAN if not pirate else MeshKit.RED
	if derelict:
		armor = Color("5c6260")
		accent = Color("7c623a")
	profile([Vector3(-8.6, 0.47, 0.48), Vector3(-7.2, 0.98, 0.76), Vector3(-5.8, 1.48, 1.02), Vector3(-1.9, 1.60, 1.06)], armor)
	MeshKit.box(self, Vector3(0, -0.65, 1.0), Vector3(2.8, 0.50, 6.4), MeshKit.INK)
	MeshKit.box(self, Vector3(0, 0, 5.1), Vector3(3.4, 1.55, 3.3), MeshKit.INK)
	for z in [-5.35, -4.25, -3.15]:
		IndustrialDetail.armor(self, Vector3(0, 1.04, z), Vector3(2.72, 0.14, 0.96), armor)
	# Contrasting armored collars frame the body modules and show thickness at the edges.
	for z in [-5.92, -2.04, 3.70]:
		MeshKit.box(self, Vector3(0, 1.12, z), Vector3(3.25, 0.22, 0.24), MeshKit.PALE)
		MeshKit.box(self, Vector3(0, -0.93, z), Vector3(2.65, 0.16, 0.25), MeshKit.STEEL)
		for side in [-1, 1]:
			MeshKit.box(self, Vector3(side * 1.58, 0.02, z), Vector3(0.19, 1.94, 0.27), MeshKit.PALE)
			MeshKit.box(self, Vector3(side * 1.69, 0.30, z), Vector3(0.05, 0.24, 0.18), MeshKit.INK)
	for side in [-1, 1]:
		MeshKit.box(self, Vector3(side * 0.48, 0.69, -7.05), Vector3(0.63, 0.20, 0.43), MeshKit.INK)
		MeshKit.box(self, Vector3(side * 0.48, 0.80, -7.06), Vector3(0.49, 0.035, 0.32), Color("2e616b"), 0.45)
		MeshKit.box(self, Vector3(side * 0.83, 0.0, -6.9), Vector3(0.13, 0.55, 0.48), accent)
		for z in [-5.1, -3.9, -2.7]:
			IndustrialDetail.armor(self, Vector3(side * 1.47, 0.05, z), Vector3(0.18, 1.45, 1.04), armor)
			MeshKit.box(self, Vector3(side * 1.58, 0.18, z - 0.23), Vector3(0.035, 0.22, 0.19), MeshKit.INK)
			MeshKit.box(self, Vector3(side * 1.60, -0.32, z + 0.24), Vector3(0.04, 0.11, 0.28), accent, 0.15)
			for dz in [-0.49, 0.49]:
				MeshKit.box(self, Vector3(side * 1.577, 0.08, z + dz), Vector3(0.02, 1.12, 0.025), MeshKit.INK)
			for y in [-0.42, 0.49]:
				for dz in [-0.36, 0.36]:
					MeshKit.box(self, Vector3(side * 1.588, y, z + dz), Vector3(0.027, 0.045, 0.065), MeshKit.INK)
		for z in [-4.75, -3.55]:
			MeshKit.box(self, Vector3(side * 1.2, 1.13, z), Vector3(0.34, 0.055, 0.20), MeshKit.INK)
		for y in [-0.52, 0.23]:
			IndustrialDetail.pipe(self, Vector3(side * 1.30, y, -1.5), Vector3(side * 1.30, y, 5.5), 0.085, MeshKit.STEEL)
		for z in [-1.4, -0.7, 0, 0.7, 1.4, 2.1, 2.8, 3.5, 4.2]:
			MeshKit.box(self, Vector3(side * 1.62, -0.2, z), Vector3(0.24, 1.45, 0.16), MeshKit.STEEL)
			MeshKit.box(self, Vector3(side * 1.76, 0.12, z), Vector3(0.05, 0.26, 0.08), accent, 0.4)
		for z in [-0.8, 1.3, 3.4]:
			IndustrialDetail.armor(self, Vector3(side * 1.53, 0.65, z), Vector3(0.43, 0.29, 1.76), armor if z != 1.3 else accent)
		for z in [-0.5, 2.2, 4.0]:
			var tank := MeshKit.cylinder(self, Vector3(side * 1.70, -0.15, z), 0.23, 1.35, MeshKit.INK)
			tank.rotation.x = PI / 2
			for dz in [-0.42, 0.42]:
				var band := MeshKit.cylinder(self, Vector3(side * 1.70, -0.15, z + dz), 0.25, 0.09, accent)
				band.rotation.x = PI / 2
		IndustrialDetail.pipe(self, Vector3(side * 1.89, 0.28, -1.4), Vector3(side * 1.89, 0.28, 4.5), 0.045, armor)
		IndustrialDetail.armor(self, Vector3(side * 1.69, 0.32, 5.20), Vector3(0.46, 2.28, 1.64), accent)
		IndustrialDetail.vent(self, Vector3(side * 0.85, 0.95, 5.0), 0.85, 1.3, 10)
		for z in [4.65, 5.55]:
			MeshKit.box(self, Vector3(side * 1.94, 0.36, z), Vector3(0.06, 1.47, 0.15), MeshKit.INK)
		for y in [-0.35, 0.0, 0.35, 0.7]:
			MeshKit.box(self, Vector3(side * 1.94, y, 5.2), Vector3(0.045, 0.045, 0.69), MeshKit.STEEL)
	for z in [-1.66, 3.48]:
		MeshKit.box(self, Vector3(0, 0.16, z), Vector3(3.35, 2.18, 0.22), MeshKit.STEEL)
		IndustrialDetail.armor(self, Vector3(0, 1.28, z), Vector3(3.38, 0.14, 0.33), armor)
	for z in [-1.08, 3.04]:
		IndustrialDetail.vent(self, Vector3(0, 0.83, z), 2.30, 0.61, 7)
	MeshKit.cylinder(self, Vector3(0, 1.22, -2.7), 0.49, 0.23, MeshKit.STEEL)
	IndustrialDetail.armor(self, Vector3(0, 1.47, -2.9), Vector3(0.83, 0.34, 0.94), accent)
	for side in [-1, 1]:
		MeshKit.box(self, Vector3(side * 0.24, 1.47, -3.8), Vector3(0.12, 0.12, 1.15), MeshKit.INK)
	IndustrialDetail.pipe(self, Vector3(1.05, 1.0, 4.9), Vector3(1.05, 2.31, 4.9), 0.032, armor)
	MeshKit.box(self, Vector3(1.05, 2.30, 4.9), Vector3(0.42, 0.08, 0.16), MeshKit.INK)
	for x in [-0.86, 0.86]:
		for y in [-0.50, 0.63]:
			var c := Vector3(x, y, 6.5)
			for spec in [Vector3(0.63, 0.65, 0), Vector3(0.53, 0.30, 0.46), Vector3(0.43, 0.10, 0.67)]:
				var nozzle := MeshKit.cylinder(self, c + Vector3(0, 0, spec.z), spec.x, spec.y, MeshKit.STEEL if spec.z == 0 else MeshKit.INK)
				nozzle.rotation.x = PI / 2
			var inner := MeshKit.cylinder(self, c + Vector3(0, 0, 0.74), 0.32, 0.035, Color("bba77e") if derelict else glow, -1, 0 if derelict else 2.6)
			inner.rotation.x = PI / 2
			if not derelict: flame_origins.append(c + Vector3(0, 0, 0.8))
	if derelict:
		for i in 11:
			var scar := MeshKit.box(self, Vector3(-0.9 + i * 0.17, 1.12, -5.4 + i * 0.12), Vector3(0.095, 0.035, 1.45), MeshKit.INK)
			scar.rotation.y = -0.6
	if pirate:
		for side in [-1, 1]:
			var fin := MeshKit.box(self, Vector3(side * 2.2, -0.6, 3), Vector3(1.0, 0.18, 3.6), MeshKit.INK)
			fin.rotation.y = side * 0.25
	MeshKit.bake(self)
	MeshKit.label(self, "07" if not pirate else "X", Vector3(0, 1.135, -4.4), 63, MeshKit.INK)
	MeshKit.label(self, "WAYFARER" if not pirate else "CHOIR", Vector3(0, 1.13, -5.25), 14, MeshKit.INK)
	if not pirate and not derelict:
		cargo_hold = CargoBayModel.new()
		cargo_hold.position = Vector3(0, -0.62, 0.95)
		add_child(cargo_hold)
	for side in [-1, 1]:
		var hatch := Node3D.new()
		hatch.position = Vector3(side * 0.65, 1.05, 0.96)
		add_child(hatch)
		for z in [-1.05, 0, 1.05]:
			if derelict and z == 0: continue
			IndustrialDetail.armor(hatch, Vector3(0, 0, z), Vector3(1.25, 0.14, 1.0), armor)
			MeshKit.box(hatch, Vector3(side * 0.46, 0.077, z), Vector3(0.095, 0.025, 0.8), accent)
		MeshKit.bake(hatch)
		hatch_doors.append(hatch)
	for c in flame_origins:
		var flame := MeshKit.cylinder(self, c + Vector3(0, 0, 0.65), 0.01, 1.4, glow, 0.30, 2.8)
		flame.rotation.x = PI / 2
		flames.append(flame)
	if pirate: scale = Vector3.ONE * 0.60

func profile(rings: Array[Vector3], tint: Color) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_smooth_group(-1)
	var corners := [Vector2(-0.65,-1), Vector2(0.65,-1), Vector2(1,-0.55), Vector2(1,0.55), Vector2(0.65,1), Vector2(-0.65,1), Vector2(-1,0.55), Vector2(-1,-0.55)]
	for n in range(rings.size() - 1):
		for i in 8:
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 8]
			var r := rings[n]
			var s := rings[n + 1]
			MeshKit.quad(mesh, [Vector3(a.x*r.y,a.y*r.z,r.x), Vector3(b.x*r.y,b.y*r.z,r.x), Vector3(b.x*s.y,b.y*s.z,s.x), Vector3(a.x*s.y,a.y*s.z,s.x)])
	for r in [rings[0], rings[-1]]:
		for i in 8:
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 8]
			MeshKit.add_triangle(mesh, Vector3(0,0,r.x), Vector3(a.x*r.y,a.y*r.z,r.x), Vector3(b.x*r.y,b.y*r.z,r.x))
	mesh.generate_normals()
	mesh.index()
	MeshKit.part(self, mesh.commit(), Vector3.ZERO, tint)

func _process(delta: float) -> void:
	clock += delta
	hatch_amount = move_toward(hatch_amount, 1.0 if hatch_open else 0.0, delta * 0.7)
	for i in hatch_doors.size():
		hatch_doors[i].position.x = (-1 if i == 0 else 1) * (0.65 + hatch_amount * 1.25)
	for i in flames.size():
		flames[i].scale.y = 0.32 + throttle * 1.2 + sin(clock * 30 + i) * 0.05
		flames[i].position = flame_origins[i] + Vector3(0, 0, flames[i].scale.y * 0.70)

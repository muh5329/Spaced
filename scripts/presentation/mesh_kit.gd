class_name MeshKit
extends RefCounted
## A tiny procedural modelling vocabulary. Static geometry is batched by material.
static var materials: Dictionary = {}
static var bevel_meshes: Dictionary = {}
static var surface_grain: ImageTexture
const INK := Color("15202a")
const STEEL := Color("34434e")
const PALE := Color("97a4a5")
const GOLD := Color("d99936")
const CYAN := Color("65d9ec")
const RED := Color("ec654e")

static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key := str(color) + str(glow)
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.79
	mat.metallic = 0.35 if glow == 0 else 0.0
	if glow == 0:
		if surface_grain == null:
			var pixels := Image.create(128, 128, false, Image.FORMAT_RGB8)
			var rng := RandomNumberGenerator.new()
			rng.seed = 7007
			for y in 128:
				for x in 128:
					var shade := rng.randf_range(0.80, 1.0)
					if y % 37 == 0 and x % 13 < 5: shade = 0.61
					pixels.set_pixel(x, y, Color(shade, shade, shade))
			pixels.generate_mipmaps()
			surface_grain = ImageTexture.create_from_image(pixels)
		mat.albedo_texture = surface_grain
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * 1.8
	if glow > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	materials[key] = mat
	return mat

static func part(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color, glow)
	node.position = pos
	parent.add_child(node)
	return node

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	if size.x > 0.24 and size.y > 0.24 and size.z > 0.24 and glow == 0:
		return part(parent, beveled_box(size), pos, color)
	var mesh := BoxMesh.new()
	mesh.size = size
	return part(parent, mesh, pos, color, glow)

static func beveled_box(size: Vector3) -> ArrayMesh:
	var key := str(size)
	if bevel_meshes.has(key):
		return bevel_meshes[key]
	var h := size * 0.5
	var bevel := minf(0.15, minf(size.x, minf(size.y, size.z)) * 0.16)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for sign_value in [-1.0, 1.0]:
			var face: Array[Vector3] = []
			for corner in [Vector2(-1,-1), Vector2(-1,1), Vector2(1,1), Vector2(1,-1)]:
				var point := Vector3.ZERO
				point[axis] = h[axis] * sign_value
				point[u] = (h[u] - bevel) * corner.x
				point[v] = (h[v] - bevel) * corner.y
				face.append(point)
			quad(st, face)
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for su in [-1.0, 1.0]:
			for sv in [-1.0, 1.0]:
				var edge: Array[Vector3] = []
				for spec in [Vector2(-1,0), Vector2(1,0), Vector2(1,1), Vector2(-1,1)]:
					var point := Vector3.ZERO
					point[axis] = spec.x * (h[axis] - bevel)
					point[u] = su * (h[u] - (bevel if spec.y == 1 else 0.0))
					point[v] = sv * (h[v] - (bevel if spec.y == 0 else 0.0))
					edge.append(point)
				quad(st, edge)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var signs := Vector3(sx, sy, sz)
				var triangle: Array[Vector3] = []
				for axis in 3:
					var point := (h - Vector3.ONE * bevel) * signs
					point[axis] = h[axis] * signs[axis]
					triangle.append(point)
				add_triangle(st, triangle[0], triangle[1], triangle[2])
	st.generate_normals()
	st.index()
	var result := st.commit()
	bevel_meshes[key] = result
	return result

static func quad(st: SurfaceTool, points: Array[Vector3]) -> void:
	add_triangle(st, points[0], points[1], points[2])
	add_triangle(st, points[0], points[2], points[3])

static func add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var center := (a + b + c) / 3
	# Godot front faces are clockwise. Ensure all generated faces point outward.
	if (b - a).cross(c - a).dot(center) > 0:
		var swap := b
		b = c
		c = swap
	for point in [a, b, c]:
		st.set_uv(Vector2(point.x, point.z))
		st.add_vertex(point)

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top: float = -1.0, glow: float = 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return part(parent, mesh, pos, color, glow)

static func sphere(parent: Node3D, pos: Vector3, radius: float, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 16
	mesh.rings = 8
	return part(parent, mesh, pos, color, glow)

static func beam(parent: Node3D, start: Vector3, end: Vector3, width: float, color: Color) -> MeshInstance3D:
	var line := cylinder(parent, (start + end) * 0.5, width, start.distance_to(end), color, width, 2.0)
	var direction := (end - start).normalized()
	if absf(direction.dot(Vector3.UP)) < 0.99:
		line.basis = Basis.looking_at(direction, Vector3.UP) * Basis(Vector3.RIGHT, PI / 2)
	return line

static func label(parent: Node3D, text: String, pos: Vector3, size: int, color: Color) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.font = load("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
	node.font_size = size
	node.pixel_size = 0.015
	node.modulate = color
	node.outline_size = 0
	node.no_depth_test = false
	node.position = pos
	node.rotation_degrees.x = -90
	parent.add_child(node)
	return node

static func bake(root: Node3D) -> void:
	var groups: Dictionary = {}
	var old: Array[Node] = []
	for child in root.get_children():
		if not child is MeshInstance3D:
			continue
		var key: int = child.material_override.get_instance_id()
		if not groups.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_material(child.material_override)
			groups[key] = st
		groups[key].append_from(child.mesh, 0, child.transform)
		old.append(child)
	for key in groups:
		var combined := MeshInstance3D.new()
		combined.mesh = groups[key].commit()
		root.add_child(combined)
	for node in old:
		root.remove_child(node)
		node.free()

static func rock_mesh(seed_value: int, radius: float) -> ArrayMesh:
	var base := SphereMesh.new()
	base.radius = 1.0
	base.height = 2.0
	base.radial_segments = 9
	base.rings = 5
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for vertex in base.get_faces():
		var factor := 1.0 + noise.get_noise_3dv(vertex * 3.0) * 0.5
		st.set_color(Color.WHITE * (0.78 + factor * 0.2))
		st.add_vertex(vertex * radius * factor * Vector3(1.0, 0.78, 1.16))
	st.generate_normals()
	st.index()
	return st.commit()

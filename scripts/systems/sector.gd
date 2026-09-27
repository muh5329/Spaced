class_name Sector
extends Node3D
## Owns deterministic world population, contact lookup and spatial hit queries.
const PORT := Vector3(47, 0, 35)
const WRECK := Vector3(-35, 0, -30)
const MINE := Vector3(32, 0, -31)
const RAIDERS := Vector3(0, 0, -116)
const RELIC := Vector3(92, 0, -105)
const GATE := Vector3(116, 0, 38)
var contacts: Array[SpaceEntity] = []
var obstacles: Array[SpaceEntity] = []
var pirates: Array[PirateShip] = []
var player: PlayerShip
var expedition: Expedition
var station: SpaceEntity
var gate: SpaceEntity
var gate_field: ShaderMaterial
var port_position := PORT
var mine_position := MINE
var wreck_position := WRECK
var raider_position := RAIDERS
var gate_position := GATE


func build(model: Expedition) -> void:
	expedition = model
	backdrop()
	station = SpaceEntity.new()
	station.position = PORT
	station.radius = 17
	station.entity_id = "meridian"
	station.display_name = "Port Meridian"
	station.category = "station"
	station.contact_color = MeshKit.CYAN
	add_child(station)
	station.add_child(StationModel.new())
	contacts.append(station)
	var wreck := Node3D.new()
	wreck.position = WRECK + Vector3(-8, -2, -9)
	wreck.rotation_degrees = Vector3(8, -40, 16)
	wreck.scale = Vector3.ONE * 1.65
	add_child(wreck)
	var wreck_model := ShipModel.new(false, true)
	wreck.add_child(wreck_model)
	wreck_model.set_process(false)
	for flame in wreck_model.flames:
		flame.visible = false
	var freight_positions: Array[Vector3] = [
		Vector3(-5, 0, 2),
		Vector3(6, 0, -2),
		Vector3(14, 0, 5),
		Vector3(-2, 0, 14),
		Vector3(10, 0, 16)
	]
	for i in 5:
		var id := "freight_%d" % i
		if model.consumed.has(id):
			continue
		var cache := SalvageCache.new()
		cache.entity_id = id
		cache.position = WRECK + freight_positions[i]
		cache.rotation.y = i * 1.8
		add_child(cache)
		contacts.append(cache)
	for i in 7:
		var rock := OreAsteroid.new()
		rock.entity_id = "ore_%d" % i
		rock.rock_seed = 107 + i * 23
		rock.radius = 3.0 + (i % 3)
		rock.position = MINE + Vector3((i % 3) * 13 - 13, 0, (i / 3) * 13)
		add_child(rock)
		rock.remaining = int(model.ore_remaining.get(rock.entity_id, 40))
		if model.consumed.has(rock.entity_id):
			rock.available = false
			rock.remaining = 0
		contacts.append(rock)
		obstacles.append(rock)
	if not model.consumed.has("asterion"):
		var relic := SalvageCache.new()
		relic.entity_id = "asterion"
		relic.is_relic = true
		relic.position = RELIC
		add_child(relic)
		contacts.append(relic)
	build_gate()
	debris()


func spawn_raiders() -> Array[PirateShip]:
	var created: Array[PirateShip] = []
	for i in 3:
		var id := "raider_%d" % i
		if (
			expedition.consumed.has(id)
			or pirates.any(func(p): return is_instance_valid(p) and p.entity_id == id)
		):
			continue
		var pirate := PirateShip.new()
		pirate.entity_id = id
		pirate.position = RAIDERS + Vector3(-24 + i * 24, 0, (i % 2) * -15)
		pirate.target = player
		pirate.orbit_side = -1 if i % 2 else 1
		add_child(pirate)
		pirates.append(pirate)
		contacts.append(pirate)
		created.append(pirate)
	return created


func backdrop() -> void:
	var planet_sphere := SphereMesh.new()
	planet_sphere.radius = 140
	planet_sphere.height = 280
	planet_sphere.radial_segments = 128
	planet_sphere.rings = 64
	var planet := MeshKit.part(self, planet_sphere, Vector3(-210, -190, -330), Color.WHITE)
	planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var planet_mat := ShaderMaterial.new()
	planet_mat.shader = load("res://shaders/planet.gdshader")
	planet.material_override = planet_mat
	if expedition.network.current > 0:
		planet_mat.set_shader_parameter(
			"tint", StarNetwork.COLORS[expedition.network.current].darkened(0.52)
		)


func debris() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = expedition.network.world_seed + expedition.network.current * 139
	var meshes: Array[ArrayMesh] = []
	for i in 8:
		meshes.append(MeshKit.rock_mesh(i * 34, 1))
	for i in 170:
		# Decorative distant rubble stays below the flyable volume; ore rocks are physical.
		var point := Vector3(
			rng.randf_range(-220, 220), rng.randf_range(-95, -82), rng.randf_range(-210, 160)
		)
		var size := rng.randf_range(0.4, 3.5)
		var rock := MeshKit.part(
			self, meshes[i % 8], point, Color("35424c") if i % 2 else Color("4d5354")
		)
		rock.scale = Vector3.ONE * size
		rock.rotation = Vector3(rng.randf() * 3, rng.randf() * 6, rng.randf() * 2)
	for i in 24:
		var point := (
			wreck_position
			+ Vector3(rng.randf_range(-25, 20), rng.randf_range(-5, -1), rng.randf_range(-20, 20))
		)
		var panel := MeshKit.box(
			self,
			point,
			Vector3(rng.randf_range(0.3, 2), 0.2, rng.randf_range(0.6, 2.7)),
			MeshKit.STEEL if i % 3 else MeshKit.GOLD.darkened(0.4)
		)
		panel.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())


func build_gate() -> void:
	gate = SpaceEntity.new()
	gate.position = gate_position
	gate.entity_id = "gate"
	gate.category = "gate"
	gate.display_name = "The Janus beacon"
	gate.radius = 7
	gate.contact_color = Color("b2a2f2")
	add_child(gate)
	contacts.append(gate)
	for i in 12:
		var angle := i * TAU / 12
		var point := Vector3(cos(angle) * 10, 0, sin(angle) * 10)
		var piece := MeshKit.box(gate, point, Vector3(3.5, 2.2, 2.8), MeshKit.STEEL)
		piece.rotation.y = -angle
		var light := MeshKit.box(
			gate, point + Vector3.UP * 1.2, Vector3(2.1, 0.1, 0.24), gate.contact_color, 1.5
		)
		light.rotation.y = -angle
	for x in [-12, 12]:
		MeshKit.box(gate, Vector3(x, 3, 0), Vector3(2.4, 9, 3.2), MeshKit.INK)
		MeshKit.box(gate, Vector3(x, 7.6, 0), Vector3(2.5, 0.35, 3.3), MeshKit.GOLD)
		MeshKit.box(gate, Vector3(x, 5.2, 0), Vector3(2.6, 1, 0.3), gate.contact_color, 1.5)
	MeshKit.bake(gate)
	var portal := MeshInstance3D.new()
	var surface := PlaneMesh.new()
	surface.size = Vector2(19, 19)
	portal.mesh = surface
	portal.position.y = 0.35
	gate_field = ShaderMaterial.new()
	gate_field.shader = load("res://shaders/jump_field.gdshader")
	gate_field.set_shader_parameter("charge", 1.0 if expedition.act == 3 else 0.08)
	portal.material_override = gate_field
	gate.add_child(portal)


func nearest_interactable(point: Vector3, reach: float = 12.0) -> SpaceEntity:
	var result: SpaceEntity = null
	var best := reach
	for contact in contacts:
		if not is_instance_valid(contact) or not contact.available or contact is Ship:
			continue
		var distance := contact.distance_to(point)
		if distance < best:
			best = distance
			result = contact
	return result


func segment_hit(start: Vector3, end: Vector3, faction: String) -> SpaceEntity:
	var candidates: Array[SpaceEntity] = []
	if faction == "player":
		for pirate in pirates:
			if is_instance_valid(pirate) and not pirate.dead:
				candidates.append(pirate)
	elif is_instance_valid(player) and not player.dead:
		candidates.append(player)
	candidates.append_array(obstacles)
	var hit: SpaceEntity = null
	var first := INF
	var segment := end - start
	for entity in candidates:
		var center := entity.global_position + Vector3.UP * 0.4
		var t := clampf((center - start).dot(segment) / maxf(segment.length_squared(), 0.001), 0, 1)
		if (
			(start + segment * t).distance_squared_to(center) < pow(entity.radius + 0.3, 2)
			and t < first
		):
			hit = entity
			first = t
	return hit


func resolve_collision(ship: Ship) -> void:
	for rock in obstacles:
		var offset := ship.position - rock.position
		var limit := ship.radius + rock.radius * 0.8
		if offset.length() < limit:
			var normal := offset.normalized() if offset.length() > 0.01 else Vector3.RIGHT
			ship.position = rock.position + normal * limit
			var closing := ship.velocity.dot(-normal)
			if closing > 5:
				ship.take_damage(closing * 0.4)
			ship.velocity += normal * maxf(closing, 0)


func threat_level() -> int:
	var result := 0
	for pirate in pirates:
		if is_instance_valid(pirate) and not pirate.dead and pirate.activated:
			result += 1
	return result


func advance_hazards(_delta: float) -> void:
	pass


func hazard_warning() -> String:
	return ""


func chart_points() -> Array:
	return [
		["PORT MERIDIAN", PORT, MeshKit.CYAN],
		["FREIGHT WRECK", WRECK, MeshKit.GOLD],
		["FERRITE FIELD", MINE, MeshKit.CYAN],
		["CHOIR TERRITORY", RAIDERS, MeshKit.RED],
		["ASTERION RELIC", RELIC, Color("b2a2f2")],
		["JANUS BEACON / J", GATE, Color("b2a2f2")]
	]

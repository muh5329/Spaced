class_name FrontierSector
extends Sector
## Frontier population specializes Sector; collision and contact rules stay shared.
var storms: Array[IonStorm] = []
var survey: SurveyBeacon
var layout_data: Dictionary


func build(model: Expedition) -> void:
	expedition = model
	layout_data = model.network.layout()
	port_position = layout_data.port
	mine_position = layout_data.mine
	wreck_position = layout_data.wreck
	raider_position = layout_data.raiders
	gate_position = layout_data.gate
	backdrop()
	var system := model.network.current
	station = SpaceEntity.new()
	station.position = port_position
	station.radius = 17
	station.entity_id = "%d/station" % system
	station.display_name = StarNetwork.PORTS[system]
	station.category = "station"
	station.contact_color = StarNetwork.COLORS[system]
	add_child(station)
	station.add_child(StationModel.new())
	MeshKit.label(
		station, station.display_name.to_upper(), Vector3(0, 12, 0), 30, station.contact_color
	)
	contacts.append(station)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(layout_data.seed)
	var wreck := Node3D.new()
	wreck.position = wreck_position + Vector3(-7, -3, -14)
	wreck.rotation_degrees = Vector3(rng.randf_range(-18, 18), rng.randf_range(-75, 75), 24)
	wreck.scale = Vector3.ONE * 1.6
	add_child(wreck)
	var wreck_model := ShipModel.new(false, true)
	wreck.add_child(wreck_model)
	wreck_model.set_process(false)
	for flame in wreck_model.flames:
		flame.visible = false
	for i in 5:
		var id := "%d/freight/%d" % [system, i]
		var angle := rng.randf_range(0, TAU)
		if model.consumed.has(id):
			continue
		var cache := SalvageCache.new()
		cache.entity_id = id
		cache.position = wreck_position + Vector3((i % 3) * 12 - 12, (i % 2) * 3, (i / 3) * 15 + 7)
		cache.rotation.y = angle
		add_child(cache)
		contacts.append(cache)
	for i in 8:
		var rock := OreAsteroid.new()
		rock.entity_id = "%d/ore/%d" % [system, i]
		rock.rock_seed = rng.randi_range(1, 999999)
		rock.radius = rng.randf_range(3, 5)
		rock.position = (
			mine_position + Vector3((i % 3) * 13 - 13, rng.randf_range(-5, 5), (i / 3) * 14)
		)
		add_child(rock)
		rock.remaining = int(model.ore_remaining.get(rock.entity_id, 40))
		rock.available = rock.remaining > 0 and not model.consumed.has(rock.entity_id)
		contacts.append(rock)
		obstacles.append(rock)
	survey = SurveyBeacon.new()
	survey.entity_id = "%d/survey" % system
	survey.position = layout_data.survey
	add_child(survey)
	survey.available = not model.network.surveyed[system]
	if not survey.available:
		survey.display_name = "Relay decoded"
	contacts.append(survey)
	for i in layout_data.storms.size():
		var storm := IonStorm.new()
		storm.position = layout_data.storms[i]
		storm.entity_id = "%d/storm/%d" % [system, i]
		storm.phase = i * 3.0
		add_child(storm)
		storms.append(storm)
		# Hazards are shown on charts but never intercept dock/scan interaction focus.
	build_gate()
	gate.display_name = "Transit relay"
	debris()


func spawn_raiders() -> Array[PirateShip]:
	var created: Array[PirateShip] = []
	for spec in expedition.network.encounter():
		if expedition.consumed.has(spec.id) or pirates.any(func(p): return p.entity_id == spec.id):
			continue
		var pirate := PirateShip.new()
		pirate.entity_id = spec.id
		pirate.role = spec.role
		pirate.position = raider_position + spec.offset
		pirate.target = player
		pirate.orbit_side = -1 if created.size() % 2 else 1
		add_child(pirate)
		pirates.append(pirate)
		contacts.append(pirate)
		created.append(pirate)
	return created


func advance_hazards(delta: float) -> void:
	var ships: Array[Ship] = [player]
	for pirate in pirates:
		if not pirate.dead:
			ships.append(pirate)
	for storm in storms:
		storm.advance(delta, ships)


func hazard_warning() -> String:
	for storm in storms:
		if storm.contains(player.position):
			return storm.warning()
	return ""


func chart_points() -> Array:
	var result: Array = [
		[station.display_name.to_upper(), port_position, MeshKit.CYAN],
		["WRECK FIELD", wreck_position, MeshKit.GOLD],
		["FERRITE FIELD", mine_position, MeshKit.CYAN],
		["HOSTILE PATROL", raider_position, MeshKit.RED],
		["TRANSIT RELAY / J", gate_position, Color("b2a2f2")]
	]
	if survey.available:
		result.append(["LOST RELAY SIGNAL", survey.position, Color("b2a2f2")])
	for storm in storms:
		result.append(["ION SHEAR ±9m", storm.position, Color("9680c9")])
	return result

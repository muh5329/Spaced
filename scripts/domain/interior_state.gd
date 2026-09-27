class_name InteriorState
extends RefCounted
## Crew, life support and station production. Runs in fixed one-second steps.
signal changed
signal notice(message: String)
const STATIONS := {
	"bridge":
	{
		## Crew, life support and station production. Runs in fixed one-second steps.
		"name": "Bridge",
		"role": "Captain",
		"power": 2.0,
		"capacity": 2,
		"function": "Navigation, tactical watch and ship command."
	},
	"quarters":
	{
		"name": "Crew quarters",
		"role": "Rest",
		"power": 1.0,
		"capacity": 3,
		"function": "Bunks and lockers. Rest lowers fatigue and restores health."
	},
	"mess":
	{
		"name": "Mess hall",
		"role": "Mess hall lead",
		"power": 3.0,
		"capacity": 2,
		"function": "Galley turns harvested crops and water into meals."
	},
	"medbay":
	{
		"name": "Medbay",
		"role": "Medical Officer",
		"power": 3.0,
		"capacity": 2,
		"function": "Treat injured crew using medicine. First aid remains available in a blackout."
	},
	"engineering":
	{
		"name": "Engineering",
		"role": "Engineer",
		"power": 3.0,
		"capacity": 2,
		"function":
		"Reactor, water recycler and oxygen scrubber. Engineers restore system condition."
	},
	"fabrication":
	{
		"name": "Fabrication",
		"role": "Fabricator",
		"power": 5.0,
		"capacity": 2,
		"function": "Build medicine, repair kits and life-support filters from spare parts."
	},
	"storage":
	{
		"name": "Storage",
		"role": "Quartermaster",
		"power": 1.0,
		"capacity": 2,
		"function":
		"Supply lockers and physical cargo. A quartermaster reduces food and water waste."
	},
	"hydroponics":
	{
		"name": "Hydroponics",
		"role": "Botanist",
		"power": 5.0,
		"capacity": 2,
		"function": "Grow food crops and produce oxygen using recycled water and grow lights."
	},
	"airlock":
	{
		"name": "Airlock",
		"role": "Security",
		"power": 2.0,
		"capacity": 2,
		"function":
		"Pressure seals and suit checks. Security reduces air loss and protects crew during impacts."
	}
}
const RESOURCE_NAMES := {
	"food": "Meals",
	"water": "Water",
	"oxygen": "Oxygen",
	"power": "Battery",
	"crops": "Crops",
	"medicine": "Medicine",
	"parts": "Spare parts",
	"repair_kits": "Repair kits",
	"filters": "Filters"
}
const UNITS := {
	"food": "meals",
	"water": "L",
	"oxygen": "%",
	"power": "%",
	"crops": "kg",
	"medicine": "doses",
	"parts": "units",
	"repair_kits": "kits",
	"filters": "filters"
}
const LIMITS := {
	"food": 100.0,
	"water": 100.0,
	"oxygen": 100.0,
	"power": 100.0,
	"crops": 60.0,
	"medicine": 30.0,
	"parts": 50.0,
	"repair_kits": 8.0,
	"filters": 8.0
}
const RECIPES := {
	"medicine": {"name": "Medical supplies", "parts": 2.0, "seconds": 18.0, "amount": 4.0},
	"repair_kits": {"name": "Repair kit", "parts": 3.0, "seconds": 24.0, "amount": 1.0},
	"filters": {"name": "Life-support filter", "parts": 2.0, "seconds": 20.0, "amount": 1.0}
}
const PRIORITY := [
	"engineering",
	"bridge",
	"hydroponics",
	"medbay",
	"mess",
	"quarters",
	"airlock",
	"storage",
	"fabrication"
]
var crew: Array[CrewMember] = []
var resources: Dictionary = {
	"food": 72.0,
	"water": 85.0,
	"oxygen": 100.0,
	"power": 80.0,
	"crops": 32.0,
	"medicine": 12.0,
	"parts": 14.0,
	"repair_kits": 1.0,
	"filters": 1.0
}
var enabled: Dictionary = {}
var condition: Dictionary = {}
var powered: Dictionary = {}
var rates: Dictionary = {}
var generation: float = 0
var demand: float = 0
var filter_condition: float = 100
var ration: String = "balanced"
var reactor: String = "balanced"
var fabrication_queue: Array[String] = []
var fabrication_progress: float = 0
var sim_seconds: float = 0
var accumulator: float = 0
var alerts: Array[String] = []
var last_error: String = ""


func _init() -> void:
	crew = [
		CrewMember.new("mara", "Mara Voss", "Captain", "bridge"),
		CrewMember.new("ivo", "Ivo Renn", "Engineer", "engineering"),
		CrewMember.new("nia", "Nia Sol", "Botanist", "hydroponics"),
		CrewMember.new("oren", "Oren Pike", "Security", "airlock"),
		CrewMember.new("tessa", "Tessa Quinn", "Mess hall lead", "mess"),
		CrewMember.new("vale", "Dr. Vale", "Medical Officer", "medbay"),
		CrewMember.new("ada", "Ada Rook", "Fabricator", "fabrication")
	]
	for key in STATIONS:
		enabled[key] = true
		condition[key] = 100.0
		powered[key] = true
	for key in LIMITS:
		rates[key] = 0.0
	update_power(0)


func member(id: String) -> CrewMember:
	for person in crew:
		if person.id == id:
			return person
	return null


func fail(reason: String) -> bool:
	last_error = reason
	return false


func assign(id: String, station: String, duration: float = 6) -> bool:
	var person := member(id)
	if person == null or not STATIONS.has(station):
		return fail("Unknown crew member or station.")
	if not is_finite(duration) or duration < 1 or duration > 120:
		return fail("No walkable route to that station.")
	if person.away:
		return fail("Recall Latch before reassigning its crew.")
	if person.health <= 15 and station not in ["medbay", "quarters"]:
		return fail("This crew member needs treatment or rest.")
	if person.station == station and not person.off_station:
		return true
	if person.travel_remaining > 0 and person.transfer_path.is_empty():
		return fail(
			"Wait for " + person.display_name + " to reach the station before changing duty."
		)
	var assigned := 0
	for other in crew:
		if other != person and other.station == station:
			assigned += 1
	if assigned >= int(STATIONS[station].capacity):
		return fail("All work positions at this station are assigned.")
	person.off_station = false
	person.transfer_path.clear()
	person.previous_station = person.station
	person.station = station
	person.travel_duration = duration
	person.travel_remaining = duration + accumulator
	last_error = ""
	changed.emit()
	return true


func move_crew(id: String, path: PackedVector3Array) -> bool:
	var person := member(id)
	if person == null or person.away:
		return fail("The selected crew member must be aboard.")
	if person.health <= 15:
		return fail("This crew member needs medical care.")
	if path.size() < 2 or path.size() > 256:
		return fail("No walkable route to that location.")
	var distance := 0.0
	for i in path.size():
		if not valid_deck_vector(path[i]):
			return fail("Destination is outside the deck.")
		if i > 0:
			distance += path[i - 1].distance_to(path[i])
	var duration := maxf(1, distance / 1.55)
	if duration > 120:
		return fail("Route is too long.")
	person.off_station = true
	person.begin_route(path, duration, accumulator)
	changed.emit()
	return true


static func valid_deck_vector(point: Vector3) -> bool:
	return (
		point.is_finite()
		and point.x >= -4
		and point.x <= 25
		and point.z >= -1
		and point.z <= 20
		and point.y >= 0
		and point.y <= 3
	)


func staffing(station: String) -> float:
	var total := 0.0
	for person in crew:
		if person.station == station:
			total += person.efficiency()
	return minf(total, 1.7)


func working(station: String) -> float:
	return (
		staffing(station) * float(condition[station]) / 100
		if powered.get(station, false) and enabled.get(station, false)
		else 0.0
	)


func toggle_station(station: String) -> void:
	if not STATIONS.has(station):
		return
	enabled[station] = not enabled[station]
	update_power(0)
	changed.emit()


func set_tug_away(value: bool) -> void:
	for id in ["mara", "ivo"]:
		var person := member(id)
		if person.away == value:
			continue
		person.away = value
		if not value:
			person.transfer_path.clear()
			person.off_station = false
			person.previous_station = "airlock"
			person.travel_duration = 6
			person.travel_remaining = 6 + accumulator
			person.has_deck_position = false


func can_launch_tug() -> bool:
	for id in ["mara", "ivo"]:
		if member(id).health <= 15:
			return false
	return true


func queue_recipe(recipe: String) -> bool:
	if not RECIPES.has(recipe):
		return fail("Unknown fabrication recipe.")
	if fabrication_queue.size() >= 5:
		return fail("The fabrication queue holds five orders.")
	var incoming := 0.0
	for item in fabrication_queue:
		if item == recipe:
			incoming += RECIPES[item].amount
	if resources[recipe] + incoming + RECIPES[recipe].amount > LIMITS[recipe]:
		return fail("Supply lockers cannot fit this production order.")
	if resources.parts < RECIPES[recipe].parts:
		return fail("Not enough spare parts. Resupply at Meridian.")
	resources.parts -= RECIPES[recipe].parts
	fabrication_queue.append(recipe)
	last_error = ""
	changed.emit()
	return true


func cancel_fabrication() -> bool:
	if fabrication_queue.is_empty():
		return fail("There are no fabrication orders to cancel.")
	# Materials are allocated once at queue time and refunded exactly once on cancellation.
	if resources.parts + RECIPES[fabrication_queue[-1]].parts > LIMITS.parts:
		return fail("Make room in the parts locker before canceling this order.")
	var recipe: String = fabrication_queue.pop_back()
	resources.parts += RECIPES[recipe].parts
	if fabrication_queue.is_empty():
		fabrication_progress = 0
	changed.emit()
	return true


func repair_station(station: String) -> bool:
	if not STATIONS.has(station):
		return fail("Unknown station.")
	if condition[station] >= 99.9:
		return fail("This station is already in good condition.")
	if resources.repair_kits < 1:
		return fail("Fabricate a repair kit first.")
	resources.repair_kits -= 1
	condition[station] = minf(100, condition[station] + 40)
	changed.emit()
	return true


func replace_filter() -> bool:
	if filter_condition >= 99.9:
		return fail("The life-support filter is already fresh.")
	if resources.filters < 1:
		return fail("Fabricate a life-support filter first.")
	resources.filters -= 1
	filter_condition = 100
	changed.emit()
	return true


func medical_treatment(id: String) -> bool:
	var person := member(id)
	if person == null or person.away:
		return fail("The patient must be aboard.")
	if person.health >= 99.9:
		return fail("This crew member does not need treatment.")
	if resources.medicine < 1:
		return fail("No medicine available. Fabricate supplies or resupply.")
	resources.medicine -= 1
	person.health = minf(100, person.health + 18)
	changed.emit()
	return true


func supply_cost() -> int:
	return ceili(
		(
			(100 - resources.food) * 0.6
			+ (100 - resources.water) * 0.3
			+ (100 - resources.oxygen) * 0.2
			+ (20 - minf(20, resources.parts)) * 2
			+ maxf(0, medicine_resupply_target() - resources.medicine)
		)
	)


func medicine_resupply_target() -> float:
	var incoming := 0.0
	for recipe in fabrication_queue:
		if recipe == "medicine":
			incoming += RECIPES.medicine.amount
	return minf(12, LIMITS.medicine - incoming)


func resupply() -> void:
	resources.food = 100.0
	resources.water = 100.0
	resources.oxygen = 100.0
	resources.power = 100.0
	resources.parts = maxf(20, resources.parts)
	resources.medicine = maxf(medicine_resupply_target(), resources.medicine)
	changed.emit()


func dock_service() -> void:
	# Meridian's existing free ship service includes restarting a damaged reactor.
	condition.engineering = 100.0
	filter_condition = maxf(50, filter_condition)
	resources.power = 100.0
	resources.oxygen = 100.0
	for person in crew:
		person.health = maxf(35, person.health)
	update_power(0)
	changed.emit()


func apply_impact(amount: float) -> void:
	if amount <= 0 or not is_finite(amount):
		return
	condition.engineering = maxf(0, condition.engineering - amount * 0.13)
	var protection := 1.0 - minf(0.65, working("airlock") * 0.5)
	for person in crew:
		if not person.away:
			person.health = maxf(0, person.health - amount * 0.10 * protection)
	changed.emit()


func advance(delta: float) -> void:
	if delta <= 0 or not is_finite(delta):
		return
	accumulator += minf(delta, 3600)
	while accumulator >= 1:
		accumulator -= 1
		step()


func update_power(delta: float) -> void:
	var multiplier := 1.25 if reactor == "overdrive" else (0.8 if reactor == "economy" else 1.0)
	generation = (
		(18 + 16 * staffing("engineering")) * float(condition.engineering) / 100 * multiplier
		if enabled.engineering
		else 0
	)
	demand = 4
	for key in STATIONS:
		if enabled[key]:
			demand += STATIONS[key].power
	resources.power = clampf(
		resources.power + (generation - demand) * delta * 0.08, 0, LIMITS.power
	)
	var available := generation - 4
	for key in PRIORITY:
		powered[key] = enabled[key] and (resources.power > 0.01 or available >= STATIONS[key].power)
		if enabled[key] and powered[key]:
			available -= STATIONS[key].power


func step() -> void:
	sim_seconds += 1
	var before := resources.duplicate()
	for person in crew:
		if person.away:
			continue
		person.advance_movement(1)
		if person.station == "quarters" and person.travel_remaining == 0 and not person.off_station:
			person.fatigue = maxf(0, person.fatigue - 0.38)
			if resources.food > 0 and resources.water > 0 and resources.oxygen > 10:
				person.health = minf(100, person.health + 0.015)
		else:
			person.fatigue = minf(100, person.fatigue + 0.018)
	update_power(1)
	var count := float(crew.size())  # Returning craft use stores from the same expedition.
	var ration_factor := 0.65 if ration == "rationed" else (1.25 if ration == "generous" else 1.0)
	var waste := 1.0 - working("storage") * 0.12
	consume("food", count * 0.006 * ration_factor * waste)
	consume("water", count * 0.010 * waste)
	consume("oxygen", count * 0.022)
	var life_support: bool = powered.engineering and enabled.engineering
	if life_support:
		var filtering := clampf(filter_condition / 65, 0.2, 1)
		add("oxygen", 0.155 * filtering * float(condition.engineering) / 100)
		add("water", 0.060 * filtering)
		filter_condition = maxf(0, filter_condition - 0.012)
	if not powered.airlock:
		consume("oxygen", 0.025)
	else:
		add("oxygen", 0.016 * working("airlock"))
	var garden := working("hydroponics")
	if resources.water > 0.02 and resources.crops < LIMITS.crops:
		var growth := minf(
			garden * 0.075, minf(LIMITS.crops - resources.crops, resources.water / 0.2)
		)
		consume("water", growth * 0.2)
		add("crops", growth)
		add("oxygen", growth / 0.075 * 0.065)
	var cooking := minf(
		working("mess") * 0.085, minf(resources.crops, (LIMITS.food - resources.food) / 1.2)
	)
	if resources.water > cooking * 0.12:
		consume("crops", cooking)
		consume("water", cooking * 0.12)
		add("food", cooking * 1.2)
	var engineer := working("engineering")
	for key in STATIONS:
		var wear := 0.0015 if enabled[key] else 0.0
		if key == "engineering" and reactor == "overdrive" and enabled.engineering:
			wear += 0.020
		condition[key] = clampf(condition[key] - wear + engineer * 0.003, 0, 100)
	var medical := working("medbay")
	for person in crew:
		if person.away:
			continue
		if resources.food <= 0:
			person.health = maxf(0, person.health - 0.025)
		if resources.water <= 0:
			person.health = maxf(0, person.health - 0.045)
		if resources.oxygen <= 10:
			person.health = maxf(0, person.health - 0.12)
		if ration == "rationed":
			person.fatigue = minf(100, person.fatigue + 0.009)
		elif ration == "generous":
			person.fatigue = maxf(0, person.fatigue - 0.010)
		if person.health < 99.9 and resources.medicine > 0.002 and medical > 0:
			var healing := minf(
				resources.medicine / 0.035,
				minf(
					100 - person.health,
					(
						medical
						* (
							0.10
							if (
								person.station == "medbay"
								and not person.off_station
								and person.travel_remaining == 0
							)
							else 0.035
						)
					)
				)
			)
			add("medicine", -healing * 0.035)
			person.health = minf(100, person.health + healing)
	if not fabrication_queue.is_empty():
		fabrication_progress += working("fabrication")
		var recipe: Dictionary = RECIPES[fabrication_queue[0]]
		if fabrication_progress >= recipe.seconds:
			var kind: String = fabrication_queue.pop_front()
			add(kind, recipe.amount)
			fabrication_progress = 0
			notice.emit(recipe.name + " ready in storage.")
	alerts.clear()
	for key in ["food", "water", "oxygen", "power"]:
		if resources[key] < 20:
			alerts.append(RESOURCE_NAMES[key] + " reserve low")
	if filter_condition < 25:
		alerts.append("Replace the life-support filter")
	if generation < demand:
		alerts.append("Power deficit: battery discharging")
	for key in LIMITS:
		rates[key] = (resources[key] - before[key]) * 60
	changed.emit()


func consume(kind: String, amount: float) -> void:
	add(kind, -maxf(0, amount))


func add(kind: String, amount: float) -> void:
	resources[kind] = clampf(resources[kind] + amount, 0, LIMITS[kind])


func snapshot() -> Dictionary:
	var people: Array = []
	for person in crew:
		people.append(person.snapshot())
	return {
		"resources": resources.duplicate(),
		"crew": people,
		"enabled": enabled.duplicate(),
		"condition": condition.duplicate(),
		"filter_condition": filter_condition,
		"ration": ration,
		"reactor": reactor,
		"queue": fabrication_queue.duplicate(),
		"progress": fabrication_progress,
		"seconds": sim_seconds,
		"accumulator": accumulator
	}


static func numeric(value: Variant, low: float, high: float) -> bool:
	return (
		(value is float or value is int)
		and is_finite(float(value))
		and value >= low
		and value <= high
	)


func restore(data: Variant, legacy_dormitory: bool = false) -> bool:
	if not data is Dictionary:
		return false
	var stores = data.get("resources")
	var people = data.get("crew")
	var switches = data.get("enabled")
	var conditions = data.get("condition")
	if (
		not stores is Dictionary
		or not people is Array
		or people.size() != crew.size()
		or not switches is Dictionary
		or not conditions is Dictionary
	):
		return false
	for key in LIMITS:
		if not numeric(stores.get(key), 0, LIMITS[key]):
			return false
	for key in STATIONS:
		if not switches.get(key) is bool or not numeric(conditions.get(key), 0, 100):
			return false
	if legacy_dormitory:
		people = people.duplicate(true)
		if not migrate_dormitory(people):
			return false
	var seen: Array[String] = []
	var counts := {}
	for item in people:
		if (
			not item is Dictionary
			or not item.get("id") is String
			or member(item.id) == null
			or item.id in seen
		):
			return false
		if (
			not STATIONS.has(item.get("station", ""))
			or not STATIONS.has(item.get("previous_station", ""))
		):
			return false
		if not numeric(item.get("travel_duration", 6), 1, 120):
			return false
		if (
			not numeric(item.get("health"), 0, 100)
			or not numeric(item.get("fatigue"), 0, 100)
			or not numeric(item.get("travel_remaining"), 0, item.get("travel_duration", 6) + 1)
		):
			return false
		if not item.get("off_station", false) is bool:
			return false
		var position_value = item.get("deck_position")
		if position_value != null and not valid_point_array(position_value):
			return false
		var route_value = item.get("route", [])
		if not route_value is Array or route_value.size() > 256:
			return false
		for point in route_value:
			if not valid_point_array(point):
				return false
		if item.get("off_station", false) and (position_value == null or route_value.size() < 2):
			return false
		counts[item.station] = counts.get(item.station, 0) + 1
		if counts[item.station] > STATIONS[item.station].capacity:
			return false
		seen.append(item.id)
	var queue = data.get("queue")
	if not queue is Array or queue.size() > 5:
		return false
	var incoming := {}
	for recipe in queue:
		if not recipe is String or not RECIPES.has(recipe):
			return false
		incoming[recipe] = incoming.get(recipe, 0) + RECIPES[recipe].amount
		if stores[recipe] + incoming[recipe] > LIMITS[recipe]:
			return false
	if (
		data.get("ration") not in ["balanced", "rationed", "generous"]
		or data.get("reactor") not in ["balanced", "economy", "overdrive"]
	):
		return false
	if (
		not numeric(data.get("filter_condition"), 0, 100)
		or not numeric(data.get("seconds"), 0, 100000000)
		or not numeric(data.get("accumulator"), 0, 0.999999999)
	):
		return false
	if not numeric(data.get("progress"), 0, 24) or (queue.is_empty() and data.progress != 0):
		return false
	if not queue.is_empty() and data.progress >= RECIPES[queue[0]].seconds:
		return false
	resources = stores.duplicate()
	enabled = switches.duplicate()
	condition = conditions.duplicate()
	for item in people:
		var person := member(item.id)
		person.station = item.station
		person.previous_station = item.previous_station
		person.health = item.health
		person.fatigue = item.fatigue
		person.travel_remaining = item.travel_remaining
		person.travel_duration = item.get("travel_duration", 6)
		person.off_station = item.get("off_station", false)
		person.has_deck_position = item.get("deck_position") != null
		if person.has_deck_position:
			person.deck_position = Vector3(
				item.deck_position[0], item.deck_position[1], item.deck_position[2]
			)
		person.transfer_path.clear()
		for point in item.get("route", []):
			person.transfer_path.append(Vector3(point[0], point[1], point[2]))
	ration = data.ration
	reactor = data.reactor
	filter_condition = data.filter_condition
	sim_seconds = data.seconds
	accumulator = data.accumulator
	fabrication_queue.assign(queue)
	fabrication_progress = data.progress
	update_power(0)
	return true


static func valid_point_array(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for number in value:
		if not numeric(number, -100, 100):
			return false
	return valid_deck_vector(Vector3(value[0], value[1], value[2]))


func migrate_dormitory(people: Array) -> bool:
	# Version three allowed seven sleepers. The modeled room has three bed berths.
	# Extra sleepers resume a valid available duty without losing health or supplies.
	var counts: Dictionary = {}
	for item in people:
		if not item is Dictionary or not item.get("id") is String or member(item.id) == null:
			return false
		var key = item.get("station", "")
		if not STATIONS.has(key):
			return false
		counts[key] = counts.get(key, 0) + 1
	var sleepers := 0
	for item in people:
		if item.station != "quarters":
			continue
		sleepers += 1
		if sleepers <= 3:
			continue
		var destination: String = member(item.id).specialty
		if counts.get(destination, 0) >= STATIONS[destination].capacity:
			for key in STATIONS:
				if key != "quarters" and counts.get(key, 0) < STATIONS[key].capacity:
					destination = key
					break
		item.station = destination
		item.previous_station = destination
		item.travel_remaining = 0
		item.travel_duration = 6
		item.off_station = false
		item.deck_position = null
		item.route = []
		counts[destination] = counts.get(destination, 0) + 1
	return true

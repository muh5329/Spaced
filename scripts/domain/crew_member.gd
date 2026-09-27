class_name CrewMember
extends RefCounted
## One named person, independent of the scene representation and controls.
var id: String
var display_name: String
var profession: String
var specialty: String
var station: String
var previous_station: String
var travel_remaining: float = 0
var travel_duration: float = 6
var health: float = 100
var fatigue: float = 8
var away: bool = false
var off_station: bool = false
var has_deck_position: bool = false
var deck_position := Vector3.ZERO
var transfer_path := PackedVector3Array()


func _init(key: String = "", title: String = "", role: String = "", home: String = "") -> void:
	id = key
	display_name = title
	profession = role
	specialty = home
	station = home
	previous_station = home


func efficiency() -> float:
	if away or off_station or travel_remaining > 0 or health <= 15:
		return 0
	return (
		(1.0 if station == specialty else 0.6)
		* clampf(health / 75, 0.25, 1)
		* clampf(1.25 - fatigue / 100, 0.3, 1)
	)


func status() -> String:
	if away:
		return "ABOARD LATCH"
	if health <= 15:
		return "NEEDS MEDICAL CARE"
	if travel_remaining > 0:
		return "WALKING TO STATION"
	if off_station:
		return "AWAITING ORDERS"
	if station == "quarters":
		return "RESTING"
	if fatigue >= 80:
		return "EXHAUSTED"
	return "ON DUTY"


func route_point(fraction: float) -> Vector3:
	if transfer_path.is_empty():
		return deck_position
	var length := 0.0
	for i in range(1, transfer_path.size()):
		length += transfer_path[i - 1].distance_to(transfer_path[i])
	var distance := length * clampf(fraction, 0, 1)
	for i in range(1, transfer_path.size()):
		var segment := transfer_path[i - 1].distance_to(transfer_path[i])
		if distance <= segment:
			return transfer_path[i - 1].lerp(transfer_path[i], distance / maxf(segment, 0.001))
		distance -= segment
	return transfer_path[-1]


func begin_route(path: PackedVector3Array, duration: float, tick_fraction: float = 0) -> void:
	transfer_path = path.duplicate()
	has_deck_position = true
	deck_position = path[0]
	travel_duration = duration
	# Remaining is measured at the last fixed tick; commands occur between ticks.
	travel_remaining = duration + tick_fraction


func advance_movement(seconds: float) -> void:
	travel_remaining = maxf(0, travel_remaining - seconds)
	if not transfer_path.is_empty():
		deck_position = route_point(1.0 - travel_remaining / travel_duration)


func snapshot() -> Dictionary:
	var route: Array = []
	for point in transfer_path:
		route.append([point.x, point.y, point.z])
	return {
		"id": id,
		"station": station,
		"previous_station": previous_station,
		"travel_remaining": travel_remaining,
		"travel_duration": travel_duration,
		"health": health,
		"fatigue": fatigue,
		"off_station": off_station,
		"deck_position":
		[deck_position.x, deck_position.y, deck_position.z] if has_deck_position else null,
		"route": route
	}

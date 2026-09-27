class_name InteriorLayout
extends RefCounted
## Meter-based deck plan reconstructed from the reference's asymmetric cutaway.
## X follows the long rear bulkhead; Z runs toward the open foreground.
const ROOMS := {
	"airlock":
	{
		"rect": Rect2(0, 0, 4, 5.8),
		"label": Vector3(1.9, 0, 3.4),
		"work": Vector3(2.8, 0, 4.3),
		"facing": 0.0
	},
	"quarters":
	{
		"rect": Rect2(4.2, 0, 5.8, 6.0),
		"label": Vector3(7.3, 0, 4.6),
		"work": Vector3(9.4, 0, 1.2),
		"facing": -1.570796
	},
	"mess":
	{
		"rect": Rect2(10.2, 0, 9.4, 9.1),
		"label": Vector3(15.8, 0, 7.0),
		"work": Vector3(12.4, 0, 1.95),
		"facing": 0.0
	},
	"bridge":
	{
		"rect": Rect2(19.8, 0, 4.2, 11.6),
		"label": Vector3(22, 0, 4.0),
		"work": Vector3(22.35, 0, 2.8),
		"facing": -1.57
	},
	"engineering":
	{
		"rect": Rect2(-3.0, 6.0, 6.5, 5.1),
		"label": Vector3(0.1, 0, 8.2),
		"work": Vector3(2.4, 0, 9.7),
		"facing": 0.0
	},
	"fabrication":
	{
		"rect": Rect2(-1.8, 11.3, 8.6, 7.0),
		"label": Vector3(2.8, 0, 15.0),
		"work": Vector3(4.65, 0, 14.1),
		"facing": -1.57
	},
	"storage":
	{
		"rect": Rect2(7.0, 10.1, 5.4, 3.4),
		"label": Vector3(9.5, 0, 11.5),
		"work": Vector3(8.1, 0, 11.6),
		"facing": 1.57
	},
	"hydroponics":
	{
		"rect": Rect2(7.0, 13.7, 8.5, 5.3),
		"label": Vector3(11.3, 0, 16.5),
		"work": Vector3(8.0, 0, 15.6),
		"facing": -1.57
	},
	"medbay":
	{
		"rect": Rect2(15.7, 12.0, 7.5, 5.5),
		"label": Vector3(19.2, 0, 14.8),
		"work": Vector3(17.7, 0, 14.9),
		"facing": -1.57
	}
}
const CORRIDORS := [
	Rect2(3.6, 6.0, 6.6, 5.1),
	Rect2(10.0, 9.15, 10.0, 0.95),
	Rect2(12.5, 9.1, 3.1, 4.6),
	Rect2(19.6, 9.0, 4.4, 3.0),
	Rect2(5.5, 10.7, 1.5, 2.7)
]
const BOUNDS := Rect2(-3.5, -0.6, 28.2, 20.2)


static func floor_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for key in ROOMS:
		result.append(ROOMS[key].rect)
	result.append_array(CORRIDORS)
	return result


static func contains_floor(point: Vector2) -> bool:
	for rect in floor_rects():
		if rect.grow(0.12).has_point(point):
			return true
	return false


static func room_at(point: Vector3) -> String:
	for key in ROOMS:
		if ROOMS[key].rect.has_point(Vector2(point.x, point.z)):
			return key
	return ""


static func station_point(key: String, index: int = 0) -> Vector3:
	if key == "quarters":
		return [Vector3(9.4, 0, 1.2), Vector3(9.4, 0, 3.1), Vector3(9.4, 0, 4.5)][mini(index, 2)]
	var point: Vector3 = (
		ROOMS[key].work + Vector3(0, 0, index * (-0.85 if key == "medbay" else 0.85))
	)
	point.y = floor_height(point)
	return point


static func floor_height(point: Vector3) -> float:
	return clampf(minf((point.x - 19.8) / 0.4, (6.5 - point.z) / 0.4), 0, 1) * 0.18

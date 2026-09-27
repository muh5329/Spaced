class_name StarNetwork
extends RefCounted
## Seeded sector descriptions are immutable; only the voyage ledger is saved.
const COUNT := 9
const NAMES := [
	"Orison Belt",
	"Cinder Reach",
	"Glasswake",
	"Sable Drift",
	"Pelagos",
	"Red March",
	"The Veil",
	"Hollow Crown",
	"Last Light"
]
const PORTS := [
	"Port Meridian",
	"Kiln Anchorage",
	"Prism Exchange",
	"Sable Freeport",
	"Pelagos Gardens",
	"Redoubt Six",
	"Lantern Station",
	"Crown Foundry",
	"Farpoint Haven"
]
const BIOMES := [
	"Frontier belt",
	"Ember nebula",
	"Glacial rings",
	"Dust graveyard",
	"Oceanic giant",
	"Iron badlands",
	"Ion veil",
	"Shattered moon",
	"Dying sun"
]
const COLORS := [
	Color("79b6cd"),
	Color("e78b56"),
	Color("79dbe7"),
	Color("b2a0d6"),
	Color("54bda7"),
	Color("d46d68"),
	Color("a789e9"),
	Color("d4c295"),
	Color("f2c576")
]
const COORDS := [
	Vector2(0, 0.45),
	Vector2(0.24, 0.14),
	Vector2(0.24, 0.76),
	Vector2(0.49, 0.03),
	Vector2(0.49, 0.44),
	Vector2(0.49, 0.92),
	Vector2(0.74, 0.21),
	Vector2(0.74, 0.73),
	Vector2(1, 0.46)
]
const LINKS := [
	[0, 1], [0, 2], [1, 3], [1, 4], [2, 4], [2, 5], [3, 6], [4, 6], [4, 7], [5, 7], [6, 8], [7, 8]
]
var world_seed: int = 457
var current: int = 0
var visited: Array = [true, false, false, false, false, false, false, false, false]
var surveyed: Array = [false, false, false, false, false, false, false, false, false]
var jumps: int = 0


func neighbors(system: int) -> Array[int]:
	var result: Array[int] = []
	for edge in LINKS:
		if edge[0] == system:
			result.append(edge[1])
		elif edge[1] == system:
			result.append(edge[0])
	return result


func route(from: int, to: int) -> Array[int]:
	var frontier: Array[int] = [from]
	var parents := {from: -1}
	while not frontier.is_empty():
		var here: int = frontier.pop_front()
		if here == to:
			break
		for next in neighbors(here):
			if not parents.has(next):
				parents[next] = here
				frontier.append(next)
	var result: Array[int] = []
	if not parents.has(to):
		return result
	var cursor := to
	while cursor != from:
		result.push_front(cursor)
		cursor = parents[cursor]
	return result


func risk(system: int) -> int:
	return [0, 1, 1, 2, 2, 2, 3, 3, 3][system]


func jump_cost(to: int) -> int:
	return 10 + 2 * risk(to)


func arrive(to: int) -> bool:
	if not neighbors(current).has(to):
		return false
	current = to
	visited[to] = true
	jumps += 1
	return true


func layout(system: int = -1) -> Dictionary:
	if system < 0:
		system = current
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + system * 7919
	var port := Vector3(rng.randf_range(-40, 35), 0, rng.randf_range(64, 86))
	var mine := Vector3(rng.randf_range(24, 53), rng.randf_range(-4, 4), -30)
	var wreck := Vector3(rng.randf_range(-65, -38), rng.randf_range(-5, 5), -26)
	var enemies := Vector3(rng.randf_range(-24, 20), rng.randf_range(-7, 7), -103)
	var survey := Vector3(rng.randf_range(74, 99), rng.randf_range(8, 20), -104)
	var storms: Array[Vector3] = []
	storms.append(wreck + Vector3(22, 0, -12))
	if risk(system) >= 2:
		storms.append(mine + Vector3(8, 0, -14))
	if risk(system) >= 3:
		storms.append(survey + Vector3(-10, -6, 14))
	return {
		"port": port,
		"mine": mine,
		"wreck": wreck,
		"raiders": enemies,
		"survey": survey,
		"gate": port + Vector3(56, 0, -6),
		"storms": storms,
		"seed": world_seed + system * 7919
	}


func encounter(system: int = -1) -> Array[Dictionary]:
	if system < 0:
		system = current
	var result: Array[Dictionary] = []
	if system == 0:
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + system * 613 + 81
	var count := risk(system) + 1
	for i in count:
		var role: String = ["interceptor", "raider", "gunship"][rng.randi_range(
			0, mini(2, risk(system) - 1)
		)]
		if i == 0 and risk(system) == 3:
			role = "gunship"
		result.append(
			{
				"id": "%d/hostile/%d" % [system, i],
				"role": role,
				"offset":
				Vector3(
					(i - (count - 1) * 0.5) * 17, rng.randf_range(-7, 7), rng.randf_range(-12, 10)
				)
			}
		)
	return result


func snapshot() -> Dictionary:
	return {
		"seed": world_seed,
		"current": current,
		"visited": visited.duplicate(),
		"surveyed": surveyed.duplicate(),
		"jumps": jumps
	}


func restore(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if (
		not Expedition.valid_number(data.get("seed"), 1, 2147483646)
		or not Expedition.valid_number(data.get("current"), 0, COUNT - 1)
		or not Expedition.valid_number(data.get("jumps"), 0, 10000000)
	):
		return false
	for key in ["visited", "surveyed"]:
		if not data.get(key) is Array or data[key].size() != COUNT:
			return false
		for value in data[key]:
			if not value is bool:
				return false
	if not data.visited[0] or not data.visited[int(data.current)]:
		return false
	for i in COUNT:
		if data.surveyed[i] and not data.visited[i]:
			return false
	world_seed = int(data.seed)
	current = int(data.current)
	visited = data.visited.duplicate()
	surveyed = data.surveyed.duplicate()
	jumps = int(data.jumps)
	return true

class_name InteriorNavigation
extends RefCounted
## A walkable meter-space grid shared by picking, routing and collision checks.
const CELL := 0.28
const CLEARANCE := 0.22
var grid := AStarGrid2D.new()
var obstacles: Array[Rect2] = []
var ready: bool = false


func build(blockers: Array[Rect2]) -> void:
	obstacles = blockers.duplicate()
	grid.region = Rect2i(
		0, 0, ceili(InteriorLayout.BOUNDS.size.x / CELL), ceili(InteriorLayout.BOUNDS.size.y / CELL)
	)
	grid.cell_size = Vector2.ONE * CELL
	grid.offset = InteriorLayout.BOUNDS.position + Vector2.ONE * CELL * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var id := Vector2i(x, y)
			grid.set_point_solid(id, not walkable(grid.get_point_position(id)))
	ready = true


func walkable(point: Vector2) -> bool:
	if not InteriorLayout.contains_floor(point):
		return false
	for rect in obstacles:
		if rect.grow(CLEARANCE).has_point(point):
			return false
	return true


func work_position(state: InteriorState, station: String, person_id: String) -> Vector3:
	# Arrival routes reserve their berth, including return through the airlock.
	# Existing residents stay put; roster ordering never displaces an operator.
	for slot in int(InteriorState.STATIONS[station].capacity):
		var destination := InteriorLayout.station_point(station, slot)
		var occupied := false
		for other in state.crew:
			if (
				other.id == person_id
				or other.station != station
				or other.off_station
				or (not other.has_deck_position and other.transfer_path.is_empty())
			):
				continue
			var reserved: Vector3 = (
				other.transfer_path[-1]
				if not other.transfer_path.is_empty()
				else other.deck_position
			)
			if reserved.distance_to(destination) < 0.5:
				occupied = true
		if not occupied:
			return destination
	return Vector3(INF, INF, INF)


func nearest(point: Vector3) -> Vector2i:
	var raw := Vector2i(((Vector2(point.x, point.z) - grid.offset) / CELL).round())
	var closest := Vector2i(-1, -1)
	var distance := INF
	for radius in range(0, 15):
		for y in range(raw.y - radius, raw.y + radius + 1):
			for x in range(raw.x - radius, raw.x + radius + 1):
				var id := Vector2i(x, y)
				if not grid.is_in_boundsv(id) or grid.is_point_solid(id):
					continue
				var d := grid.get_point_position(id).distance_squared_to(Vector2(point.x, point.z))
				if d < distance:
					closest = id
					distance = d
		if closest.x >= 0:
			return closest
	return closest


func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not ready:
		return PackedVector3Array()
	var start := nearest(from)
	var finish := nearest(to)
	if start.x < 0 or finish.x < 0:
		return PackedVector3Array()
	var points := grid.get_point_path(start, finish)
	var result := PackedVector3Array()
	if points.is_empty():
		return result
	result.append(
		from if walkable(Vector2(from.x, from.z)) else Vector3(points[0].x, 0, points[0].y)
	)
	var previous_direction := Vector2.ZERO
	for i in range(1, points.size()):
		var direction := (points[i] - points[i - 1]).normalized()
		if i > 1 and not direction.is_equal_approx(previous_direction):
			result.append(ground_point(points[i - 1]))
		previous_direction = direction
	result.append(ground_point(points[-1]))
	if walkable(Vector2(to.x, to.z)):
		result.append(to)
	return result


static func length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


static func sample(path: PackedVector3Array, fraction: float) -> Vector3:
	if path.is_empty():
		return Vector3.ZERO
	var distance := length(path) * clampf(fraction, 0, 1)
	for i in range(1, path.size()):
		var segment := path[i - 1].distance_to(path[i])
		if distance <= segment:
			return path[i - 1].lerp(path[i], distance / maxf(segment, 0.001))
		distance -= segment
	return path[-1]


static func ground_point(point: Vector2) -> Vector3:
	var world := Vector3(point.x, 0, point.y)
	world.y = InteriorLayout.floor_height(world)
	return world

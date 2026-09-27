class_name FlightNavigator
extends RefCounted
## Volumetric routes around expanded obstacle spheres, inside a bounded flight volume.
## A visibility graph is needed only when the direct course is obstructed.
const SAMPLES := 16
const BELT_RADIUS := 258.0
const ALTITUDE_LIMIT := 60.0
const ACCELERATION := 10.0
var route: Array[Vector3] = []
var destination := Vector3.ZERO
var obstacles: Array[SpaceEntity] = []
var ship_radius: float = 2.4

func cancel() -> void:
	route.clear()

func active() -> bool:
	return not route.is_empty()

func clearance(rock: SpaceEntity) -> float:
	return rock.radius * 0.8 + ship_radius + 1.0

static func constrain(point: Vector3) -> Vector3:
	var horizontal := Vector2(point.x, point.z).limit_length(BELT_RADIUS)
	return Vector3(horizontal.x, clampf(point.y, -ALTITUDE_LIMIT, ALTITUDE_LIMIT), horizontal.y)

func safe_destination(point: Vector3) -> Vector3:
	point = constrain(point)
	for attempt in 16:
		var adjusted := false
		for rock in obstacles:
			var away := point - rock.position
			var margin := clearance(rock) + 0.8
			if away.length() < margin:
				point = rock.position + (away.normalized() if away.length() > 0.01 else Vector3.BACK) * margin
				adjusted = true
		if not adjusted:
			break
	return point

func clear_segment(start: Vector3, finish: Vector3) -> bool:
	var segment := finish - start
	for rock in obstacles:
		var center := rock.position
		var fraction := clampf((center - start).dot(segment) / maxf(segment.length_squared(), 0.001), 0, 1)
		if (start + segment * fraction).distance_to(center) < clearance(rock) - 0.01:
			return false
	return true

func plan(start: Vector3, requested: Vector3) -> bool:
	cancel()
	if not requested.is_finite():
		return false
	destination = safe_destination(requested)
	# Recover when a collision or old checkpoint leaves us at a rock's edge.
	var departure := safe_destination(start)
	var nodes: Array[Vector3] = [departure, destination]
	if not clear_segment(departure, destination):
		var travel := Vector3(destination.x - departure.x, 0, destination.z - departure.z).normalized()
		if travel.length() < 0.01: travel = Vector3.RIGHT
		for rock in obstacles:
			var orbit := (clearance(rock) + 1.0) / cos(PI / SAMPLES)
			for sample in SAMPLES:
				var angle := TAU * sample / SAMPLES
				# Horizontal and vertical rings provide both lateral and over/under detours.
				for axis in [Vector3(cos(angle), 0, sin(angle)), travel * cos(angle) + Vector3.UP * sin(angle)]:
					var point: Vector3 = rock.position + axis * orbit
					if clear_segment(point, point) and point.is_equal_approx(constrain(point)):
						nodes.append(point)
	var costs: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for point in nodes:
		costs.append(INF)
		previous.append(-1)
		visited.append(false)
	costs[0] = 0
	for iteration in nodes.size():
		var nearest := -1
		for index in nodes.size():
			if not visited[index] and (nearest == -1 or costs[index] + nodes[index].distance_to(destination) < costs[nearest] + nodes[nearest].distance_to(destination)):
				nearest = index
		if nearest == -1 or costs[nearest] == INF:
			return false
		if nearest == 1:
			break
		visited[nearest] = true
		for index in nodes.size():
			if visited[index]:
				continue
			var cost := costs[nearest] + nodes[nearest].distance_to(nodes[index])
			if cost < costs[index] and clear_segment(nodes[nearest], nodes[index]):
				costs[index] = cost
				previous[index] = nearest
	if previous[1] == -1:
		return false
	var cursor := 1
	while cursor != 0:
		route.push_front(nodes[cursor])
		cursor = previous[cursor]
	if start.distance_to(departure) > 0.4:
		route.push_front(departure)
	return true

func desired_velocity(position: Vector3, top_speed: float) -> Vector3:
	if not active():
		return Vector3.ZERO
	var offset := route[0] - position
	if offset.length() < (0.25 if route.size() == 1 else 0.8):
		route.pop_front()
		return desired_velocity(position, top_speed)
	# Slow at corners as well as the final berth to keep boosted turns clear of rocks.
	var speed := minf(top_speed, minf(offset.length() * 2.0, sqrt(2.0 * ACCELERATION * offset.length()) * 0.7))
	return offset.normalized() * speed

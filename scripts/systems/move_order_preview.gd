class_name MoveOrderPreview
extends RefCounted
## Draft an order on a horizontal plane, then adjust its height without moving XZ.
## Drafts never mutate the live route until explicitly confirmed.
var active: bool = false
var origin := Vector3.ZERO
var base := Vector3.ZERO
var altitude: float = 0.0
var adjusting_height: bool = false
var height_mouse: float = 0.0
var height_anchor: float = 0.0
var height_scale: float = 0.1
var plane_offset := Vector2.ZERO

func begin(ship_position: Vector3) -> void:
	active = true
	origin = ship_position
	base = ship_position
	altitude = ship_position.y
	adjusting_height = false
	plane_offset = Vector2.ZERO

func cancel() -> void:
	active = false
	adjusting_height = false

func destination() -> Vector3:
	return FlightNavigator.constrain(Vector3(base.x, altitude, base.z))

func adjust_height(amount: float) -> void:
	var previous := altitude
	altitude = clampf(altitude + amount, -FlightNavigator.ALTITUDE_LIMIT, FlightNavigator.ALTITUDE_LIMIT)
	height_anchor += altitude - previous

func update(camera: Camera3D, mouse: Vector2, height_modifier: bool) -> void:
	if not active: return
	if height_modifier:
		if not adjusting_height:
			adjusting_height = true
			height_mouse = mouse.y
			height_anchor = altitude
			var projected := camera.unproject_position(base)
			var up := camera.unproject_position(base + Vector3.UP)
			height_scale = 1.0 / maxf(2, projected.distance_to(up))
		var requested := height_anchor + (height_mouse - mouse.y) * height_scale
		altitude = clampf(requested, -FlightNavigator.ALTITUDE_LIMIT, FlightNavigator.ALTITUDE_LIMIT)
		if not is_equal_approx(altitude, requested):
			height_anchor = altitude
			height_mouse = mouse.y
	else:
		# The release frame only unlocks height; it must not jump the horizontal target.
		if adjusting_height:
			adjusting_height = false
			plane_offset = mouse - camera.unproject_position(base)
			return
		var plane_mouse := mouse - plane_offset
		var point = Plane(Vector3.UP, origin.y).intersects_ray(camera.project_ray_origin(plane_mouse), camera.project_ray_normal(plane_mouse))
		if point != null:
			base = FlightNavigator.constrain(point)

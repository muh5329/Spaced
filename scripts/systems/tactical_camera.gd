class_name TacticalCamera
extends RefCounted
## Camera intent is independent of ship heading and orders.
const DEFAULT_ELEVATION := 0.90
const FIELD_OF_VIEW := 50.0
var azimuth: float = 0.0
var elevation: float = DEFAULT_ELEVATION
var target_azimuth: float = 0.0
var target_elevation: float = DEFAULT_ELEVATION
var drag_button: MouseButton = MOUSE_BUTTON_NONE
var drag_origin := Vector2.ZERO
var drag_last := Vector2.ZERO
var dragging: bool = false

func begin_drag(screen: Vector2, button: MouseButton) -> void:
	drag_origin = screen
	drag_last = screen
	drag_button = button
	dragging = false

func drag(screen: Vector2) -> void:
	if screen.distance_to(drag_origin) > 6: dragging = true
	if dragging: orbit(screen - drag_last)
	drag_last = screen

func end_drag() -> bool:
	var was_dragging := dragging
	drag_button = MOUSE_BUTTON_NONE
	dragging = false
	return was_dragging

func orbit(pixels: Vector2) -> void:
	target_azimuth -= pixels.x * 0.006
	target_elevation = clampf(target_elevation + pixels.y * 0.005, 0.26, 1.40)

func reset() -> void:
	target_azimuth = 0
	target_elevation = DEFAULT_ELEVATION

func update(delta: float, immediate: bool = false) -> void:
	var blend := 1.0 if immediate else 1.0 - exp(-delta * 12)
	azimuth = lerp_angle(azimuth, target_azimuth, blend)
	elevation = lerpf(elevation, target_elevation, blend)

func offset(visible_height: float) -> Vector3:
	var distance := visible_height / (2.0 * tan(deg_to_rad(FIELD_OF_VIEW) / 2.0))
	return Vector3(sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation)) * distance

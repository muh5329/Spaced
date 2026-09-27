class_name SelectionBox
extends RefCounted
## A screen-space gesture, separate from fleet membership and world commands.
const DRAG_THRESHOLD := 6.0
var active: bool = false
var dragging: bool = false
var additive: bool = false
var origin := Vector2.ZERO
var cursor := Vector2.ZERO

func begin(point: Vector2, add_to_selection: bool) -> void:
	active = true
	dragging = false
	additive = add_to_selection
	origin = point
	cursor = point

func update(point: Vector2) -> void:
	cursor = point
	if origin.distance_to(cursor) > DRAG_THRESHOLD: dragging = true

func rectangle() -> Rect2:
	return Rect2(origin, cursor - origin).abs()

func cancel() -> void:
	active = false
	dragging = false

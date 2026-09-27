class_name IonStorm
extends SpaceEntity
## Telegraph, discharge, quiet. A shallow volume can be crossed above or below.
var phase: float = 0.0
var half_height: float = 9.0
var field_material: ShaderMaterial


func _ready() -> void:
	category = "hazard"
	display_name = "Ion shear"
	contact_color = Color("b29bea")
	radius = 20
	for height in [-half_height, half_height]:
		var ring := TorusMesh.new()
		ring.inner_radius = radius - 0.10
		ring.outer_radius = radius + 0.10
		ring.rings = 64
		ring.ring_segments = 6
		MeshKit.part(self, ring, Vector3(0, height, 0), contact_color, 1.1)
	for i in 8:
		var angle := i * TAU / 8
		MeshKit.beam(
			self,
			Vector3(cos(angle) * radius, -half_height, sin(angle) * radius),
			Vector3(cos(angle) * radius, half_height, sin(angle) * radius),
			0.025,
			contact_color
		)
	var surface := CylinderMesh.new()
	surface.top_radius = radius
	surface.bottom_radius = radius
	surface.height = half_height * 2
	surface.radial_segments = 64
	var mesh := MeshKit.part(self, surface, Vector3.ZERO, contact_color)
	field_material = ShaderMaterial.new()
	field_material.shader = preload("res://shaders/ion_storm.gdshader")
	mesh.material_override = field_material
	MeshKit.label(self, "ION SHEAR / ±9m", Vector3(0, half_height + 2, 0), 24, contact_color)


func contains(point: Vector3) -> bool:
	var offset := point - global_position
	return absf(offset.y) < half_height and Vector2(offset.x, offset.z).length() < radius


func discharging() -> bool:
	return phase >= 10


func warning() -> String:
	if discharging():
		return "ION DISCHARGE / climb above %+d m" % ceili(position.y + half_height + 2)
	if phase >= 7:
		return "ION SHEAR CHARGING / %d s to discharge" % ceili(10 - phase)
	return "ION SHEAR / quiet for %d s / G + Shift changes altitude" % ceili(7 - phase)


func advance(delta: float, ships: Array[Ship]) -> void:
	phase = fposmod(phase + delta, 14)
	field_material.set_shader_parameter(
		"activity", 1.0 if discharging() else (0.4 if phase >= 7 else 0.08)
	)
	if not discharging():
		return
	for ship in ships:
		if not ship.dead and contains(ship.global_position):
			ship.take_damage(delta * 8)


func interaction_text() -> String:
	return warning()

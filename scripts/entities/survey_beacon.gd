class_name SurveyBeacon
extends SpaceEntity
var antenna: Node3D


func _ready() -> void:
	category = "survey"
	display_name = "Lost relay signal"
	radius = 4
	contact_color = Color("b29bea")
	MeshKit.cylinder(self, Vector3.ZERO, 1.5, 5, MeshKit.STEEL, 0.8)
	MeshKit.box(self, Vector3(0, 2, 0), Vector3(2.8, 0.8, 2.8), MeshKit.GOLD)
	MeshKit.sphere(self, Vector3(0, 3, 0), 0.5, contact_color, 3)
	antenna = Node3D.new()
	add_child(antenna)
	for sign_value in [-1, 1]:
		MeshKit.box(
			antenna, Vector3(sign_value * 4, 0.5, 0), Vector3(5.5, 0.15, 3), Color("24475e")
		)
		for i in 6:
			MeshKit.box(
				antenna,
				Vector3(sign_value * (1.4 + i * 0.9), 0.6, 0),
				Vector3(0.04, 0.03, 2.8),
				MeshKit.CYAN,
				0.5
			)
	MeshKit.bake(antenna)


func _process(delta: float) -> void:
	antenna.rotation.y += delta * 0.16


func interaction_text() -> String:
	return "HOLD E / DECODE SIGNAL / REMAIN NEAR THE RELAY"

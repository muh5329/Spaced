class_name StationModel
extends Node3D

func _ready() -> void:
	for i in 16:
		var angle := TAU * i / 16
		var point := Vector3(cos(angle), 0, sin(angle)) * 15
		var block := MeshKit.box(self, point, Vector3(6.2, 2.7, 6.5), MeshKit.STEEL)
		block.rotation.y = -angle
		var plate := MeshKit.box(self, point + Vector3.UP * 1.5, Vector3(5.8, 0.3, 6.1), MeshKit.PALE.darkened(0.17))
		plate.rotation.y = -angle
		var stripe := MeshKit.box(self, point + Vector3.UP * 1.72, Vector3(0.55, 0.09, 5.9), MeshKit.GOLD)
		stripe.rotation.y = -angle
		var tangent := Vector3(-sin(angle), 0, cos(angle))
		for side in [-1, 1]:
			var hatch := MeshKit.box(self, point + Vector3.UP * 1.8 + tangent * side * 1.8, Vector3(2.6, 0.16, 1.8), MeshKit.STEEL)
			hatch.rotation.y = -angle
			for slot in 4:
				var vent := MeshKit.box(self, point + Vector3.UP * 1.92 + tangent * side * 1.8 + point.normalized() * (slot - 1.5) * 0.45, Vector3(0.13, 0.09, 1.4), MeshKit.INK)
				vent.rotation.y = -angle
		for j in 3:
			var window := point.normalized() * 18.2 + Vector3(0, 0.3, 0)
			window += Vector3(-sin(angle), 0, cos(angle)) * (j - 1) * 1.2
			var light := MeshKit.box(self, window, Vector3(0.15, 0.22, 0.72), MeshKit.GOLD, 2)
			light.rotation.y = -angle
		if i % 4 == 0:
			MeshKit.box(self, point + Vector3.UP * 4, Vector3(2.3, 7, 2.3), MeshKit.INK)
			MeshKit.box(self, point + Vector3.UP * 7.6, Vector3(2.5, 0.3, 2.5), MeshKit.GOLD)
			MeshKit.box(self, point + Vector3.UP * 6.5, Vector3(2.4, 0.55, 0.15), MeshKit.CYAN, 1.2)
			for floor_index in 3:
				MeshKit.box(self, point + Vector3(0, 2.8 + floor_index * 1.1, 1.18), Vector3(1.35, 0.28, 0.08), MeshKit.PALE.darkened(0.25))
	MeshKit.box(self, Vector3(0, -1, 0), Vector3(17, 0.8, 17), MeshKit.INK)
	MeshKit.box(self, Vector3(0, -0.53, 1), Vector3(8, 0.12, 12), MeshKit.STEEL)
	for x in [-3.8, 3.8]:
		for z in 8:
			MeshKit.box(self, Vector3(x, -0.43, -4 + z * 1.6), Vector3(0.13, 0.06, 0.7), MeshKit.CYAN, 2)
	for side in [-1, 1]:
		MeshKit.box(self, Vector3(side * 6.2, 1.7, -5.5), Vector3(0.7, 5.3, 0.9), MeshKit.GOLD.darkened(0.2))
		MeshKit.box(self, Vector3(side * 4.8, 4.5, -5.5), Vector3(3.8, 0.6, 1.0), MeshKit.STEEL)
		MeshKit.cylinder(self, Vector3(side * 3.1, 3.4, -5.5), 0.035, 1.8, MeshKit.PALE)
		MeshKit.box(self, Vector3(side * 3.1, 2.45, -5.5), Vector3(0.4, 0.45, 0.4), MeshKit.GOLD)
	for i in 14:
		var point := Vector3(-6 + (i % 4) * 4, 1.7, -16 - (i / 4) * 0.6)
		MeshKit.box(self, point, Vector3(1.5, 0.6, 1.8), MeshKit.INK)
	MeshKit.bake(self)
	MeshKit.label(self, "MERIDIAN", Vector3(0, 1.71, 15), 180, MeshKit.INK)
	MeshKit.label(self, "0 4", Vector3(0, -0.42, 0), 140, MeshKit.PALE)

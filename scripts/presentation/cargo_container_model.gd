class_name CargoContainerModel
extends Node3D
## Identical dimensions and fittings in the field, on a drone and in the cargo racks.
var kind: String

func _init(cargo_kind: String = "salvage") -> void:
	kind = cargo_kind

func _ready() -> void:
	var shape := CargoBay.new().footprint(kind)
	var size := Vector3(shape.x * CargoBay.CELL_SIZE - 0.065, 0.48, shape.y * CargoBay.CELL_SIZE - 0.065)
	var tint := MeshKit.GOLD if kind == "salvage" else (Color("a992d1") if kind == "core" else MeshKit.STEEL)
	IndustrialDetail.armor(self, Vector3.ZERO, size, tint)
	for z in [-0.36, 0.36]:
		MeshKit.box(self, Vector3(0, 0, z * size.z), Vector3(size.x + 0.025, 0.49, 0.045), MeshKit.INK)
	MeshKit.box(self, Vector3(0, 0.251, 0), Vector3(size.x * 0.3, 0.018, 0.09), MeshKit.CYAN if kind == "ore" else MeshKit.PALE)
	for side in [-1, 1]:
		MeshKit.box(self, Vector3(side * size.x * 0.505, 0.02, 0), Vector3(0.018, 0.1, size.z * 0.3), MeshKit.PALE)
	MeshKit.bake(self)

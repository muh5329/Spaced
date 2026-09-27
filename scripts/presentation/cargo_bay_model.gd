class_name CargoBayModel
extends Node3D
## One geometric manifest renderer, shared by the exterior hold and inspection view.
const CELL := CargoBay.CELL_SIZE
const DECK_HEIGHT := 0.52
var contents: Node3D
var bay: CargoBay
var large_labels: bool = false

func _ready() -> void:
	MeshKit.box(self, Vector3(0, -0.10, 0), Vector3(2.62, 0.20, 3.22), MeshKit.INK)
	for x in CargoBay.WIDTH:
		for z in CargoBay.LENGTH:
			var p := cell_position(x, z, 0)
			MeshKit.box(self, p, Vector3(CELL - 0.025, 0.025, CELL - 0.025), Color("4b5150"))
	for x in [-1.29, 1.29]:
		MeshKit.box(self, Vector3(x, 0.65, 0), Vector3(0.08, 1.45, 3.2), MeshKit.STEEL)
		for z in [-1.45, 0, 1.45]:
			MeshKit.box(self, Vector3(x, 0.85, z), Vector3(0.10, 1.9, 0.09), MeshKit.INK)
	for i in 12:
		MeshKit.box(self, Vector3(-1.1 + i * 0.2, 0.022, 1.49), Vector3(0.10, 0.03, 0.14), MeshKit.GOLD)
	MeshKit.bake(self)
	contents = Node3D.new()
	add_child(contents)
	if bay != null: refresh(bay)

static func cell_position(x: int, z: int, deck: int) -> Vector3:
	return Vector3((x - 1.5) * CELL, deck * DECK_HEIGHT + 0.035, (z - 2) * CELL)

func refresh(manifest: CargoBay) -> void:
	bay = manifest
	if not is_instance_valid(contents): return
	for child in contents.get_children():
		contents.remove_child(child)
		child.free()
	for deck in range(1, bay.decks()):
		for x in [-1.2, 0, 1.2]:
			MeshKit.box(contents, Vector3(x, deck * DECK_HEIGHT, 0), Vector3(0.07, 0.05, 2.98), MeshKit.GOLD.darkened(0.2))
	for item in bay.items:
		var shape := Vector2i(item.w, item.h)
		var center := cell_position(item.x, item.z, item.deck) + Vector3((shape.x - 1) * CELL / 2, 0.25, (shape.y - 1) * CELL / 2)
		var container := CargoContainerModel.new(item.kind)
		container.position = center
		contents.add_child(container)
	MeshKit.bake(contents)

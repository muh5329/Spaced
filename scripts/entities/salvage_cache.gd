class_name SalvageCache
extends Harvestable
var is_relic: bool = false
var model_node: Node3D
var elapsed: float = 0.0
var in_tow: bool = false

func _ready() -> void:
	category = "relic" if is_relic else "salvage"
	display_name = "Asterion memory core" if is_relic else "Sealed freight container"
	contact_color = Color("b2a2f2") if is_relic else MeshKit.GOLD
	work_seconds = 4.2 if is_relic else 3.0
	radius = 0.85
	add_to_group("harvestables")
	model_node = CargoContainerModel.new("core" if is_relic else "salvage")
	add_child(model_node)

func _process(delta: float) -> void:
	if in_tow:
		model_node.position = Vector3.ZERO
		model_node.rotation = Vector3.ZERO
		return
	elapsed += delta
	model_node.position.y = sin(elapsed * 0.65) * 0.24
	model_node.rotation.y += delta * 0.07

func interaction_text() -> String:
	return "DISPATCH SALVAGE CREW / CORE" if is_relic else "CREWED TUG REQUIRED / 2×2 CELLS / 12 t"

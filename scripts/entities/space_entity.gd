class_name SpaceEntity
extends Node3D
## Addressable object in the belt. Presentation and interaction read this contract.
var entity_id: String = ""
var display_name: String = "Unknown contact"
var radius: float = 3.0
var contact_color := MeshKit.CYAN
var category: String = "contact"
var available: bool = true

func distance_to(point: Vector3) -> float:
	return maxf(0.0, global_position.distance_to(point) - radius)

func interaction_text() -> String:
	return ""

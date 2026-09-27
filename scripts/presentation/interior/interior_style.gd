class_name InteriorStyle
extends RefCounted
## A restrained geometric ink pass echoes the reference's dark edges in every camera view.
static var outlined: Dictionary = {}
static var ink: ShaderMaterial


static func apply(root: Node) -> void:
	if ink == null:
		ink = ShaderMaterial.new()
		ink.shader = load("res://shaders/interior_ink.gdshader")
	for child in root.get_children():
		if child is MeshInstance3D:
			var original: Material = (
				child.material_override
				if child.material_override != null
				else child.mesh.surface_get_material(0)
			)
			if original is StandardMaterial3D and not original.emission_enabled:
				var key := original.get_instance_id()
				if not outlined.has(key):
					var material: StandardMaterial3D = original.duplicate()
					material.next_pass = ink
					outlined[key] = material
				child.material_override = outlined[key]
		apply(child)

class_name OreAsteroid
extends Harvestable
var rock_seed: int = 17

func _ready() -> void:
	category = "ore"
	display_name = "Ferrite deposit"
	contact_color = MeshKit.CYAN
	remaining = 40
	add_to_group("harvestables")
	add_to_group("obstacles")
	MeshKit.part(self, MeshKit.rock_mesh(rock_seed, radius), Vector3.ZERO, Color("45545d"))
	var rng := RandomNumberGenerator.new()
	rng.seed = rock_seed
	for i in 12:
		var angle := rng.randf() * TAU
		var point := Vector3(cos(angle), rng.randf_range(0.3, 0.9), sin(angle)).normalized() * radius * 0.83
		var crystal := MeshKit.cylinder(self, point, radius * 0.13, radius * 0.5, MeshKit.CYAN.darkened(0.28), 0.015, 0.45)
		crystal.rotation = Vector3(rng.randf(), angle, rng.randf())
	MeshKit.bake(self)

func interaction_text() -> String:
	return "DISPATCH MINING DRONE  /  %d t remaining" % remaining

func extract(amount: int, expedition: Expedition) -> int:
	var taken := mini(maxi(0, amount), remaining)
	remaining -= taken
	expedition.ore_remaining[entity_id] = remaining
	if remaining == 0:
		available = false
		expedition.consumed[entity_id] = true
	return taken

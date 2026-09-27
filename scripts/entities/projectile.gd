class_name Projectile
extends Node3D
var velocity := Vector3.ZERO
var power: float = 24
var faction: String = "player"
var lifetime: float = 2.0
var collision_query: Callable
var impact: Callable

func _ready() -> void:
	var color := MeshKit.CYAN if faction == "player" else MeshKit.RED
	MeshKit.beam(self, Vector3.ZERO, velocity.normalized() * -1.8, 0.06 if faction == "player" else 0.11, color)
	MeshKit.sphere(self, Vector3.ZERO, 0.13, color, 3)

func _physics_process(delta: float) -> void:
	var previous := global_position
	global_position += velocity * delta
	lifetime -= delta
	var hit = collision_query.call(previous, global_position, faction)
	if hit != null:
		if hit is Ship:
			hit.take_damage(power)
		impact.call(global_position, MeshKit.CYAN if faction == "player" else MeshKit.RED, false)
		queue_free()
	elif lifetime <= 0:
		queue_free()

class_name Burst
extends Node3D
var color := MeshKit.GOLD
var large: bool = false
var age: float = 0.0
var sparks: Array[MeshInstance3D] = []
var directions: Array[Vector3] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in (22 if large else 7):
		var spark := MeshKit.box(self, Vector3.ZERO, Vector3(0.08, 0.08, 0.35) * (2.0 if large else 1.0), color, 2.5)
		sparks.append(spark)
		directions.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.6), rng.randf_range(-1, 1)).normalized() * rng.randf_range(3, 15 if large else 7))

func _process(delta: float) -> void:
	age += delta
	for i in sparks.size():
		sparks[i].position += directions[i] * delta
		sparks[i].scale = Vector3.ONE * maxf(0.01, 1.0 - age / (1.2 if large else 0.5))
	if age > (1.3 if large else 0.55):
		queue_free()

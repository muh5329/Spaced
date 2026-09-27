class_name MiningDrone
extends SupportCraft
## Carries one physical ore pod. Extraction and delivery are separate transactions.
var pod: Node3D

func _ready() -> void:
	super._ready()
	display_name = "Mole %02d" % (fleet_index + 1)
	pod = CargoContainerModel.new("ore")
	model.add_child(pod)
	pod.visible = false

func accepts(target: Harvestable) -> bool:
	return target is OreAsteroid

func finish_work() -> void:
	var rock := work_target as OreAsteroid
	payload_amount = rock.extract(mini(4, rock.remaining), expedition)
	if payload_amount == 0:
		recall()
		return
	payload_source = rock.entity_id
	phase = Phase.RETURNING
	automatic_return = true
	progress = 0
	repath = 0

func update_payload(_delta: float) -> void:
	pod.visible = payload_amount > 0
	pod.position = Vector3(0, -0.54, 0.1).lerp(model.to_local(berth()), clampf(progress, 0, 1)) if phase == Phase.UNLOADING else Vector3(0, -0.54, 0.1)

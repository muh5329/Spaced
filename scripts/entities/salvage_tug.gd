class_name SalvageTug
extends SupportCraft
## A two-person workboat physically tows the assigned container to the cargo airlock.
const CREW := ["Mara Voss / pilot", "Ivo Renn / rigger"]
var tow: SalvageCache
var cable: MeshInstance3D

func _ready() -> void:
	super._ready()
	display_name = "Latch / salvage crew"
	radius = 1.2
	navigator.ship_radius = 4.8
	cable = MeshKit.cylinder(self, Vector3.ZERO, 0.04, 1, MeshKit.GOLD, -1, 0.4)
	cable.visible = false

func is_tug() -> bool:
	return true

func accepts(target: Harvestable) -> bool:
	return target is SalvageCache

func finish_work() -> void:
	tow = work_target as SalvageCache
	tow.in_tow = true
	tow.available = false
	payload_source = tow.entity_id
	payload_amount = 8 if tow.is_relic else 12
	phase = Phase.RETURNING
	progress = 0
	repath = 0

func update_payload(delta: float) -> void:
	cable.visible = is_instance_valid(tow) and payload_amount > 0
	if not cable.visible: return
	var hitch := model.to_global(Vector3(0, 0, 1.9))
	var desired := hitch + model.global_basis.z * 3.8
	if phase == Phase.UNLOADING:
		desired = desired.lerp(berth(), clampf(progress, 0, 1))
	tow.global_position = tow.global_position.lerp(desired, 1.0 - exp(-delta * 3.5))
	tow.rotation.y = lerp_angle(tow.rotation.y, rotation.y, 1.0 - exp(-delta * 2))
	var delta_pos := tow.global_position - hitch
	if delta_pos.length() > 0.01:
		cable.global_position = (hitch + tow.global_position) * 0.5
		cable.global_basis = Basis.looking_at(delta_pos.normalized(), Vector3.FORWARD if absf(delta_pos.normalized().y) > 0.99 else Vector3.UP) * Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(1, delta_pos.length(), 1))

func unload() -> void:
	super.unload()
	if payload_amount == 0 and is_instance_valid(tow):
		tow.visible = false
		tow.claim_owner = ""
		tow = null
		cable.visible = false

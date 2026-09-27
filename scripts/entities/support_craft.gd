class_name SupportCraft
extends CommandShip
## Shared launch/recall/delivery lifecycle. Workers specialize the extraction step.
signal status(message: String)
signal delivered
enum Phase { DOCKED, IDLE, OUTBOUND, WORKING, RETURNING, UNLOADING }
var phase: Phase = Phase.DOCKED
var mothership: PlayerShip
var expedition: Expedition
var work_target: Harvestable
var payload_kind: String = ""
var payload_amount: int = 0
var payload_source: String = ""
var progress: float = 0.0
var repath: float = 0.0
var fleet_index: int = 0
var automatic_return: bool = false
var tool_beam: MeshInstance3D

func _ready() -> void:
	category = "support"
	radius = 0.8
	navigator.ship_radius = radius
	model = WorkCraftModel.new(is_tug())
	add_child(model)
	tool_beam = MeshKit.cylinder(self, Vector3.ZERO, 0.026, 1, MeshKit.CYAN, -1, 2)
	tool_beam.visible = false
	visible = false
	order_label = "BERTH SECURED"

func is_tug() -> bool:
	return false

func payload_capacity() -> int:
	return 4

func berth() -> Vector3:
	return mothership.model.to_global(Vector3(0, 0.8, 1.6))

func staging_point() -> Vector3:
	return navigator.safe_destination(FlightNavigator.constrain(berth() + Vector3(0, 5 + fleet_index * 1.5, 0)))

func launch() -> void:
	if phase != Phase.DOCKED: return
	if is_tug() and not expedition.interior_state.can_launch_tug():
		status.emit("Mara and Ivo need medical treatment before Latch can launch.")
		return
	position = FlightNavigator.constrain(berth() + Vector3((fleet_index - 1) * 0.8, 1.0, 0))
	rotation.y = mothership.rotation.y
	velocity = Vector3.ZERO
	visible = true
	phase = Phase.IDLE
	order_label = "AWAITING ORDERS"

func release_job() -> void:
	if is_instance_valid(work_target) and work_target.claim_owner == entity_id:
		work_target.claim_owner = ""
	work_target = null
	progress = 0
	if payload_amount == 0: expedition.bay.release(entity_id)

func command_move(destination: Vector3, label: String = "FOLLOWING COURSE") -> bool:
	if not selected or not enabled: return false
	launch()
	if phase == Phase.DOCKED: return false
	release_job()
	automatic_return = false
	phase = Phase.IDLE
	return super.command_move(destination, label)

func stop() -> void:
	super.stop()
	release_job()
	automatic_return = false
	if phase != Phase.DOCKED: phase = Phase.IDLE
	order_label = "HOLDING TOW" if is_tug() and payload_amount > 0 else "HOLDING POSITION"

func accepts(_target: Harvestable) -> bool:
	return false

func command_work(target: Harvestable) -> bool:
	if not enabled or not accepts(target) or not target.available: return false
	if is_tug() and phase == Phase.DOCKED and not expedition.interior_state.can_launch_tug():
		status.emit("Treat Mara and Ivo before assigning a salvage job.")
		return false
	if payload_amount > 0:
		status.emit("Return the current load before accepting another job. R recalls this craft.")
		return false
	if target.claim_owner != "" and target.claim_owner != entity_id:
		status.emit("That freight is already assigned to another crew.")
		return false
	if target is SalvageCache and target.is_relic and expedition.act < 2:
		status.emit("Core encrypted. Complete Meridian's contracts first.")
		return false
	var kind := "core" if target is SalvageCache and target.is_relic else ("salvage" if is_tug() else "ore")
	var amount := 8 if kind == "core" else (12 if kind == "salvage" else mini(4, target.remaining))
	if not expedition.bay.reserve(entity_id, kind, amount):
		status.emit("Bay cannot fit this load. Clear space at Meridian or install another rack deck.")
		return false
	if is_instance_valid(work_target) and work_target.claim_owner == entity_id: work_target.claim_owner = ""
	work_target = target
	if is_tug(): target.claim_owner = entity_id
	payload_kind = kind
	launch()
	phase = Phase.OUTBOUND
	automatic_return = false
	progress = 0
	repath = 0
	order_label = "APPROACHING " + target.display_name.to_upper()
	return true

func recall() -> void:
	if phase == Phase.DOCKED: return
	automatic_return = false
	if phase in [Phase.RETURNING, Phase.UNLOADING]:
		# Held docking/recall input must not restart an in-progress transfer.
		if is_instance_valid(work_target) and work_target.claim_owner == entity_id: work_target.claim_owner = ""
		work_target = null
		if payload_amount == 0: expedition.bay.release(entity_id)
		return
	release_job()
	phase = Phase.RETURNING
	progress = 0
	repath = 0
	order_label = "RETURNING TO CARGO AIRLOCK"

func _physics_process(delta: float) -> void:
	# Workers are noncombat craft: damage and weapon rules stay in Ship, but there is no fire order.
	super._physics_process(delta)
	if not enabled: return
	tool_beam.visible = false
	if phase == Phase.DOCKED:
		position = berth()
		return
	repath -= delta
	match phase:
		Phase.OUTBOUND:
			if not is_instance_valid(work_target) or not work_target.available:
				recall()
			elif work_target.distance_to(position) < 2.4:
				navigator.cancel()
				phase = Phase.WORKING
				progress = 0
			elif repath <= 0:
				repath = 0.6
				var away := (position - work_target.position).normalized()
				navigator.plan(position, work_target.position + away * (work_target.radius + 1.7))
		Phase.WORKING:
			if not is_instance_valid(work_target) or not work_target.available:
				recall()
			else:
				order_label = "CREW SECURING TOW" if is_tug() else "CUTTING FERRITE / 4 t POD"
				progress += delta / work_target.work_seconds
				show_tool(work_target.position)
				if progress >= 1: finish_work()
		Phase.RETURNING:
			order_label = "TOWING TO WAYFARER" if is_tug() and payload_amount > 0 else "RETURNING TO WAYFARER"
			if position.distance_to(staging_point()) < 1.1:
				navigator.cancel()
				phase = Phase.UNLOADING
				progress = 0
			elif repath <= 0:
				repath = 0.35
				navigator.plan(position, staging_point())
		Phase.UNLOADING:
			# A moving mothership aborts the transfer approach; no remote cargo deposits.
			if position.distance_to(staging_point()) > 3 or mothership.velocity.length() > 1.5:
				phase = Phase.RETURNING
				repath = 0
				progress = 0
			else:
				order_label = "CARGO AIRLOCK / TRANSFERRING"
				progress += delta / 2.0
				if progress >= 1: unload()
	var speed := 5.0 if is_tug() and payload_amount > 0 else (9.0 if is_tug() else 15.0)
	steer(delta, speed)
	sector.resolve_collision(self)
	update_payload(delta)

func finish_work() -> void:
	pass

func update_payload(_delta: float) -> void:
	pass

func show_tool(endpoint: Vector3) -> void:
	tool_beam.visible = true
	var start := position + Vector3.UP * 0.3
	var delta := endpoint - start
	if delta.length() < 0.01: return
	tool_beam.global_position = (start + endpoint) * 0.5
	tool_beam.global_basis = Basis.looking_at(delta.normalized(), Vector3.FORWARD if absf(delta.normalized().y) > 0.99 else Vector3.UP) * Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(1, delta.length(), 1))

func unload() -> void:
	if payload_amount > 0:
		if not expedition.receive_payload(entity_id, payload_kind, payload_amount, payload_source):
			phase = Phase.IDLE
			order_label = "TRANSFER BLOCKED / LOAD RETAINED"
			status.emit("Cargo transfer blocked; load remains on the craft.")
			return
		status.emit("%s delivered: %d t secured in the physical bay." % [display_name, payload_amount])
		payload_amount = 0
		delivered.emit()
	var repeat_target := work_target
	var repeat_work := automatic_return and is_instance_valid(repeat_target) and repeat_target.available and not is_tug()
	release_job()
	if repeat_work and command_work(repeat_target): return
	phase = Phase.DOCKED
	visible = false
	navigator.cancel()
	velocity = Vector3.ZERO
	order_label = "BERTH SECURED"

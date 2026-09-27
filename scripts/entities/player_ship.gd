class_name PlayerShip
extends CommandShip
## The captain issues orders. Navigation, pursuit and firing execute those orders.
var energy: float = 100.0
var boost_locked: bool = false
var engine_level: int = 0
var is_boosting: bool = false
var boost_permitted: bool = true
var attack_target: Ship
var pursuit_timer: float = 0.0
var crew_navigation_bonus: float = 0.0

func _ready() -> void:
	display_name = "Wayfarer"
	category = "player"
	radius = 2.4
	model = ShipModel.new()
	add_child(model)

func apply_upgrades(expedition: Expedition) -> void:
	engine_level = expedition.upgrades.engine
	max_hull = 120 + expedition.upgrades.shield * 40
	max_shield = 65 + expedition.upgrades.shield * 35
	weapon_power = 24 + expedition.upgrades.weapon * 9
	weapon_interval = 0.23 - expedition.upgrades.weapon * 0.025

func command_move(destination: Vector3, label: String = "FOLLOWING COURSE") -> bool:
	if not selected or dead or not enabled:
		return false
	attack_target = null
	return super.command_move(destination, label)

func command_attack(target: Ship) -> bool:
	if not selected or dead or not enabled or not is_instance_valid(target) or target.dead or target.faction == faction:
		return false
	attack_target = target
	navigator.cancel()
	pursuit_timer = 0
	order_label = "ENGAGING " + target.display_name.to_upper()
	return true

func stop() -> void:
	attack_target = null
	super.stop()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not enabled or dead:
		model.throttle = 0.15
		return
	if attack_target != null and (not is_instance_valid(attack_target) or attack_target.dead):
		stop()
		order_label = "TARGET NEUTRALIZED"
	var aim := Vector3.ZERO
	if is_instance_valid(attack_target):
		var offset := attack_target.position - position
		# Weapon clearance follows swept projectile geometry, not the wider hull route.
		var obstruction := sector.segment_hit(position + Vector3.UP * 0.5, attack_target.position + Vector3.UP * 0.4, faction)
		var clear_shot := obstruction == null or obstruction == attack_target
		pursuit_timer -= delta
		if pursuit_timer <= 0:
			pursuit_timer = 0.6
			if offset.length() > 27 or not clear_shot:
				var berth := attack_target.position - offset.normalized() * 21 if clear_shot else attack_target.position
				navigator.plan(position, berth)
			else:
				navigator.cancel()
		aim = offset + attack_target.velocity * maxf(0, (offset.length() - 4) / 74.0)
		if offset.length() < 42 and clear_shot:
			shoot(aim.normalized())
	if boost_locked and energy >= 30:
		boost_locked = false
	is_boosting = boost_permitted and Input.is_action_pressed("boost") and energy > 0 and not boost_locked and navigator.active()
	if is_boosting:
		energy = maxf(0, energy - delta * 26)
		if energy <= 0:
			boost_locked = true
	else:
		energy = minf(100, energy + delta * 18)
	var speed := (12.0 + engine_level * 2.5 + crew_navigation_bonus) * (2.1 if is_boosting else 1.0)
	steer(delta, speed, aim)

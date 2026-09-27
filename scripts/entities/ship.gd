class_name Ship
extends SpaceEntity
## Base ship owns damage, shields and weapon timing; subclasses own flight decisions.
signal destroyed(ship: Ship)
signal damaged(amount: float)
signal fired(origin: Vector3, direction: Vector3, power: float, faction: String)
var hull: float = 120.0
var max_hull: float = 120.0
var shield: float = 65.0
var max_shield: float = 65.0
var velocity := Vector3.ZERO
var cooldown: float = 0.0
var damage_delay: float = 0.0
var faction: String = "player"
var dead: bool = false
var enabled: bool = false
var model: ShipModel
var weapon_power: float = 24.0
var weapon_interval: float = 0.23

func _physics_process(delta: float) -> void:
	if not enabled or dead:
		return
	cooldown = maxf(cooldown - delta, 0)
	damage_delay = maxf(damage_delay - delta, 0)
	if damage_delay <= 0:
		shield = minf(max_shield, shield + delta * 8)

func take_damage(amount: float) -> void:
	if dead:
		return
	damage_delay = 5.0
	var absorbed := minf(shield, amount)
	shield -= absorbed
	hull = maxf(0, hull - (amount - absorbed))
	damaged.emit(amount)
	if hull <= 0:
		dead = true
		destroyed.emit(self)

func shoot(direction: Vector3) -> void:
	if cooldown > 0 or dead:
		return
	cooldown = weapon_interval
	var origin := global_position + direction * 4 + Vector3.UP * 0.5
	fired.emit(origin, direction.normalized(), weapon_power, faction)

func restore() -> void:
	hull = max_hull
	shield = max_shield
	dead = false

func update_attitude(direction: Vector3, delta: float, turn_rate: float = 1.6) -> void:
	if not is_instance_valid(model): return
	var yaw_error := 0.0
	var pitch := 0.0
	if direction.length() > 0.15:
		var horizontal := Vector2(direction.x, direction.z).length()
		if horizontal > 0.01:
			var heading := atan2(-direction.x, -direction.z)
			yaw_error = angle_difference(rotation.y, heading)
			rotation.y = rotate_toward(rotation.y, heading, turn_rate * delta)
		pitch = atan2(direction.y, horizontal)
	model.rotation.x = rotate_toward(model.rotation.x, pitch, turn_rate * delta)
	var bank := clampf(yaw_error * 0.24, -0.30, 0.30)
	model.rotation.z = lerpf(model.rotation.z, bank, 1.0 - exp(-delta * 4))

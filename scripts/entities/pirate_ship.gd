class_name PirateShip
extends Ship
var role: String = "legacy"
var cruise_speed: float = 7.5
var preferred_range: float = 21.0
var strafe: float = 0.65
var target: PlayerShip
var home := Vector3.ZERO
var orbit_side: float = 1.0
var activated: bool = false


func _ready() -> void:
	display_name = "Choir raider"
	category = "hostile"
	contact_color = MeshKit.RED
	faction = "hostile"
	radius = 2.5
	hull = 64
	max_hull = 64
	shield = 18
	max_shield = 18
	weapon_power = 10
	weapon_interval = 1.45
	cooldown = 1.2
	model = ShipModel.new(true)
	add_child(model)
	add_to_group("hostiles")
	home = position
	match role:
		"interceptor":
			display_name = "Razor interceptor"
			cruise_speed = 13
			preferred_range = 14
			strafe = 1.0
			hull = 52
			max_hull = 52
			weapon_power = 6
			weapon_interval = 0.8
			model.scale = Vector3(0.72, 0.8, 1.08)
		"raider":
			display_name = "Reaver raider"
			cruise_speed = 9
			hull = 80
			max_hull = 80
			weapon_power = 12
		"gunship":
			display_name = "Bastion gunship"
			cruise_speed = 5
			preferred_range = 34
			strafe = 0.3
			hull = 145
			max_hull = 145
			shield = 40
			max_shield = 40
			weapon_power = 22
			weapon_interval = 2.5
			model.scale = Vector3(1.4, 1.2, 1.2)
			for x in [-2.7, 2.7]:
				MeshKit.box(model, Vector3(x, 1.3, -1), Vector3(0.5, 0.6, 3.5), MeshKit.STEEL)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not enabled or dead or not is_instance_valid(target) or target.dead:
		return
	var offset := target.global_position - global_position
	var distance := offset.length()
	if distance > 65 and not activated:
		rotation.y += delta * 0.12
		return
	activated = distance < 100
	if not activated:
		return
	var dir := offset.normalized()
	var tangent := Vector3(-dir.z, 0, dir.x).normalized() * orbit_side
	var drive := dir * clampf((distance - preferred_range) / 14, -1, 1) + tangent * strafe
	velocity = velocity.move_toward(drive * cruise_speed, delta * 9)
	position += velocity * delta
	position = FlightNavigator.constrain(position)
	update_attitude(offset, delta, 2.6)
	model.throttle = 0.5 + velocity.length() / 10
	if distance < 44:
		var intercept := (offset + target.velocity * distance / 46).normalized()
		shoot(intercept)

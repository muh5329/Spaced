class_name CommandShip
extends Ship
## Shared order/navigation contract for the mothership and its controllable work craft.
var selected: bool = false
var sector: Sector
var navigator := FlightNavigator.new()
var order_label: String = "HOLDING POSITION"

func command_move(destination: Vector3, label: String = "FOLLOWING COURSE") -> bool:
	if not selected or dead or not enabled: return false
	var planned := navigator.plan(position, destination)
	order_label = label if planned else "NO CLEAR ROUTE"
	return planned

func stop() -> void:
	navigator.cancel()
	order_label = "HOLDING POSITION"

func steer(delta: float, speed: float, facing_when_stopped: Vector3 = Vector3.ZERO) -> void:
	var was_navigating := navigator.active()
	var desired := navigator.desired_velocity(position, speed)
	update_attitude(desired if desired.length() > 0.15 else facing_when_stopped, delta)
	if desired.length() > 0.15:
		desired *= clampf((-model.global_basis.z).dot(desired.normalized()), 0, 1)
	velocity = velocity.move_toward(desired, delta * (FlightNavigator.ACCELERATION if navigator.active() else 16))
	position = FlightNavigator.constrain(position + velocity * delta)
	if was_navigating and not navigator.active(): order_label = "DESTINATION REACHED"
	model.throttle = 0.22 + velocity.length() / 17

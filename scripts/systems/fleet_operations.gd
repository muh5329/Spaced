class_name FleetOperations
extends RefCounted
## Owns the small working fleet, task dispatch and the crew accounting boundary.
signal message(text: String)
signal cargo_changed
var craft: Array[SupportCraft] = []
var player: PlayerShip
var expedition: Expedition

func setup(sector: Sector, model: Expedition) -> void:
	player = sector.player
	expedition = model
	for i in 3:
		var unit: SupportCraft = SalvageTug.new() if i == 2 else MiningDrone.new()
		unit.entity_id = "latch" if i == 2 else "mole_%d" % i
		unit.fleet_index = i
		unit.mothership = player
		unit.expedition = model
		unit.sector = sector
		unit.navigator.obstacles = sector.obstacles
		sector.add_child(unit)
		sector.contacts.append(unit)
		unit.status.connect(func(text): message.emit(text))
		unit.delivered.connect(func(): cargo_changed.emit())
		craft.append(unit)

func request_job(target: Harvestable) -> bool:
	for unit in craft:
		if unit.accepts(target) and unit.phase in [SupportCraft.Phase.DOCKED, SupportCraft.Phase.IDLE] and unit.payload_amount == 0:
			if unit.command_work(target):
				message.emit("%s dispatched. Select it with %d to change its orders." % [unit.display_name, unit.fleet_index + 2])
				return true
			return false
	message.emit("All suitable work craft are busy. Select one to redirect it, or R to recall.")
	return false

func all_aboard() -> bool:
	return craft.all(func(unit): return unit.phase == SupportCraft.Phase.DOCKED)

func recall_all() -> void:
	for unit in craft: unit.recall()

func crew_away() -> int:
	return 2 if craft.size() == 3 and craft[2].phase != SupportCraft.Phase.DOCKED else 0

func set_enabled(value: bool) -> void:
	for unit in craft: unit.enabled = value

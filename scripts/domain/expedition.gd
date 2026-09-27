class_name Expedition
extends RefCounted
## Authoritative campaign/economy model. No rendering, input, or scene dependencies.

signal changed
signal milestone(message: String)

const CAPACITIES := [80, 120, 180]
const UPGRADE_COSTS := [240, 520]
const UPGRADE_NAMES := {
	"engine": "Vector drives",
	"weapon": "Rail accelerators",
	"shield": "Hull & shielding",
	"cargo": "Cargo racks"
}
const TITLES := [
	"A debt to the dark", "The silent choir", "A home between stars", "Beyond the quiet"
]
var credits: int = 200
var ore: int = 0
var scrap: int = 0
var mined: int = 0
var salvaged: int = 0
var kills: int = 0
var act: int = 0
var relic: bool = false
var upgrades: Dictionary = {"engine": 0, "weapon": 0, "shield": 0, "cargo": 0}
var consumed: Dictionary = {}
var ore_remaining: Dictionary = {}
var crew_role: String = "Engineering"
var play_seconds: float = 0.0
var bay := CargoBay.new()
var cargo_serial: int = 0
var interior_state := InteriorState.new()
var network := StarNetwork.new()
var contracts := StationContracts.new()
var ship_condition := {"hull": 1.0, "shield": 1.0, "boost": 100.0}


func capacity() -> int:
	return CAPACITIES[upgrades.cargo]


func cargo_used() -> int:
	return ore + scrap + (8 if relic else 0)


func add_ore(amount: int) -> int:
	if amount <= 0:
		return 0
	var accepted := 0
	bay.level = upgrades.cargo
	while accepted < amount:
		var pod := mini(4, mini(amount - accepted, capacity() - cargo_used() - accepted))
		cargo_serial += 1
		if not bay.store("ore_%d" % cargo_serial, "ore", pod):
			break
		accepted += pod
	ore += accepted
	mined += accepted
	changed.emit()
	return accepted


func add_salvage(id: String, amount: int = 12) -> bool:
	bay.level = upgrades.cargo
	if amount != 12 or consumed.has(id) or not bay.store(id, "salvage", amount):
		return false
	scrap += amount
	salvaged += 1
	consumed[id] = true
	changed.emit()
	return true


func record_kill(id: String) -> void:
	if consumed.has(id):
		return
	consumed[id] = true
	kills += 1
	credits += 90
	changed.emit()


func upgrade_cost(kind: String) -> int:
	var level: int = upgrades.get(kind, 2)
	return UPGRADE_COSTS[level] if level < 2 else 0


func purchase(kind: String) -> bool:
	if not upgrades.has(kind) or upgrades[kind] >= 2:
		return false
	var price := upgrade_cost(kind)
	if credits < price:
		return false
	credits -= price
	upgrades[kind] += 1
	bay.level = upgrades.cargo
	changed.emit()
	return true


func sell_cargo() -> int:
	var total := ore * 8 + scrap * 12
	credits += total
	ore = 0
	scrap = 0
	bay.sellable_clear()
	changed.emit()
	return total


func choir_kills() -> int:
	var count := 0
	for id in ["raider_0", "raider_1", "raider_2"]:
		if consumed.has(id):
			count += 1
	return count


func contract_ready() -> bool:
	return (act == 0 and mined >= 24 and salvaged >= 3) or (act == 1 and choir_kills() >= 3)


func process_ore_for_parts() -> bool:
	if interior_state.resources.parts + 4 > InteriorState.LIMITS.parts:
		return interior_state.fail("Spare-parts lockers are full.")
	if ore < 4 or not bay.take_ore(4):
		return interior_state.fail("Deliver at least 4 t of ore to the cargo bay first.")
	ore -= 4
	interior_state.resources.parts += 4
	changed.emit()
	interior_state.changed.emit()
	return true


func turn_in() -> bool:
	if not contract_ready():
		return false
	credits += 650 if act == 0 else 1100
	act += 1
	milestone.emit("CONTRACT COMPLETE  /  " + TITLES[act])
	changed.emit()
	return true


func finish() -> bool:
	if act != 2 or not relic:
		return false
	act = 3
	changed.emit()
	return true


func objective_lines() -> Array[String]:
	match act:
		0:
			return [
				"Recover freight   %d / 3" % mini(salvaged, 3),
				"Mine ferrite   %d / 24" % mini(mined, 24),
				"Return to Port Meridian"
			]
		1:
			return [
				"Destroy raiders   %d / 3" % mini(choir_kills(), 3),
				"Return to Port Meridian",
				"Click a raider to engage"
			]
		2:
			return [
				"Recover the Asterion core" if not relic else "Asterion core secured",
				"Bring the core to the jump beacon",
				"Hold E to open the way home"
			]
	return ["The corridor is open", "Your crew has a way home", "Explore the belt at your own pace"]


func receive_payload(owner: String, kind: String, amount: int, source_id: String) -> bool:
	if source_id.is_empty() or not CargoBay.valid_payload(kind, amount):
		return false
	if not bay.reservations.has(owner) or bay.reservations[owner].kind != kind:
		return false
	if kind != "ore" and consumed.has(source_id):
		return false
	if kind == "core" and act < 2:
		return false
	var id := "pod_%d" % (cargo_serial + 1) if kind == "ore" else source_id
	if not bay.receive(owner, id, amount):
		return false
	cargo_serial += 1
	match kind:
		"ore":
			ore += amount
			mined += amount
		"salvage":
			scrap += amount
			salvaged += 1
			consumed[source_id] = true
		"core":
			relic = true
			consumed[source_id] = true
	changed.emit()
	return true


func snapshot() -> Dictionary:
	return {
		"version": 5,
		"ship_condition": ship_condition.duplicate(),
		"network": network.snapshot(),
		"contracts": contracts.snapshot(),
		"interior": interior_state.snapshot(),
		"credits": credits,
		"ore": ore,
		"scrap": scrap,
		"mined": mined,
		"salvaged": salvaged,
		"kills": kills,
		"act": act,
		"relic": relic,
		"upgrades": upgrades.duplicate(),
		"consumed": consumed.duplicate(),
		"ore_remaining": ore_remaining.duplicate(),
		"crew_role": crew_role,
		"play_seconds": play_seconds,
		"bay": bay.snapshot(),
		"cargo_serial": cargo_serial
	}


static func from_snapshot(data: Dictionary) -> Expedition:
	if not valid_number(data.get("version"), 1, 5):
		return null
	var model := Expedition.new()
	for field in ["credits", "ore", "scrap", "mined", "salvaged", "kills"]:
		var value = data.get(field, 0)
		if (
			not (value is float or value is int)
			or not is_finite(float(value))
			or value < 0
			or value > 10000000
		):
			return null
		model.set(field, int(value))
	if not valid_number(data.get("act", 0), 0, 3):
		return null
	model.act = int(data.get("act", 0))
	model.relic = bool(data.get("relic", false))
	var levels = data.get("upgrades", {})
	if not levels is Dictionary:
		return null
	for kind in model.upgrades:
		if not valid_number(levels.get(kind, 0), 0, 2):
			return null
		model.upgrades[kind] = int(levels.get(kind, 0))
	var used = data.get("consumed", {})
	if not used is Dictionary or used.size() > 1000:
		return null
	model.consumed = used.duplicate()
	var deposits = data.get("ore_remaining", {})
	if not deposits is Dictionary or deposits.size() > 100:
		return null
	for id in deposits:
		if not id is String or not valid_number(deposits[id], 0, 40):
			return null
		model.ore_remaining[id] = int(deposits[id])
	var watch = data.get("crew_role", "Engineering")
	if not watch is String or watch not in ["Engineering", "Gunnery", "Survey"]:
		return null
	model.crew_role = watch
	if not valid_number(data.get("play_seconds", 0), 0, 100000000, false):
		return null
	model.play_seconds = float(data.get("play_seconds", 0))
	model.bay.level = model.upgrades.cargo
	if int(data.version) >= 2:
		if (
			not valid_number(data.get("cargo_serial", 0), 0, 10000000)
			or not model.bay.restore(data.get("bay"))
		):
			return null
		model.cargo_serial = int(data.get("cargo_serial", 0))
		var totals := {"ore": 0, "salvage": 0, "core": 0}
		for item in model.bay.items:
			totals[item.kind] += int(item.amount)
		if (
			totals.ore != model.ore
			or totals.salvage != model.scrap
			or totals.core != (8 if model.relic else 0)
		):
			return null
	else:
		# Legacy numeric cargo becomes physical freight/pods; expand racks only if required.
		for tier in range(model.upgrades.cargo, 3):
			model.bay = CargoBay.new()
			model.bay.level = tier
			var fits := true
			for i in ceili(model.scrap / 12.0):
				if not model.bay.store("legacy_freight_%d" % i, "salvage", 12):
					fits = false
			for i in ceili(model.ore / 4.0):
				if not model.bay.store("legacy_ore_%d" % i, "ore", mini(4, model.ore - i * 4)):
					fits = false
			if model.relic and not model.bay.store("asterion", "core", 8):
				fits = false
			if fits:
				model.upgrades.cargo = tier
				break
			if tier == 2:
				return null
	if (
		int(data.version) >= 3
		and not model.interior_state.restore(data.get("interior"), int(data.version) == 3)
	):
		return null
	if int(data.version) >= 5:
		var condition_data = data.get("ship_condition")
		if not condition_data is Dictionary:
			return null
		for field in ["hull", "shield", "boost"]:
			if not valid_number(
				condition_data.get(field), 0, 100 if field == "boost" else 1, false
			):
				return null
			model.ship_condition[field] = float(condition_data[field])
		if model.ship_condition.hull <= 0:
			return null
		if (
			not model.network.restore(data.get("network"))
			or not model.contracts.restore(data.get("contracts"), model.network)
		):
			return null
	if model.cargo_used() > model.capacity():
		return null
	return model


static func valid_number(
	value: Variant, minimum: float, maximum: float, integer: bool = true
) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and value >= minimum
		and value <= maximum
		and (not integer or float(value) == floorf(float(value)))
	)

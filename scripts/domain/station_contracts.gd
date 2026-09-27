class_name StationContracts
extends RefCounted
## Four immutable offers per office rotation. Saved statuses never contain editable rewards.
const OFFER := 0
const ACTIVE := 1
const PAID := 2
const CLOSED := 3
const KINDS := ["ore", "salvage", "bounty", "survey"]
const TITLES := [
	"Keep the furnaces lit", "A ship worth saving", "Clear the shipping lane", "Listen to the dark"
]
var boards: Array[Dictionary] = []
var completed: int = 0
var tracked: String = ""


func _init() -> void:
	for i in StarNetwork.COUNT:
		boards.append({"cycle": 0, "states": [0, 0, 0, 0]})


func definition(network: StarNetwork, office: int, slot: int) -> Dictionary:
	var cycle: int = boards[office].cycle
	var rng := RandomNumberGenerator.new()
	rng.seed = network.world_seed + office * 1013 + cycle * 47 + slot * 171
	var neighbors := network.neighbors(office)
	var target: int = neighbors[rng.randi_range(0, neighbors.size() - 1)]
	# Home has no generated combat or survey site; use the nearest frontier instead.
	if target == 0:
		target = 1 if office != 1 else 2
	var amount: int = [
		rng.randi_range(3, 5) * 4, rng.randi_range(1, 2) * 12, network.encounter(target).size(), 1
	][slot]
	var reward: int = [
		180 + amount * 12,
		220 + amount * 16,
		380 + network.risk(target) * 140,
		300 + network.risk(target) * 70
	][slot]
	return {
		"id": "%d:%d:%d" % [office, cycle, slot],
		"office": office,
		"slot": slot,
		"target": target,
		"kind": KINDS[slot],
		"title": TITLES[slot],
		"amount": amount,
		"reward": reward,
		"status": int(boards[office].states[slot])
	}


func office_jobs(network: StarNetwork, office: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in 4:
		result.append(definition(network, office, slot))
	return result


func active_jobs(network: StarNetwork) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for office in StarNetwork.COUNT:
		for slot in 4:
			if boards[office].states[slot] == ACTIVE:
				result.append(definition(network, office, slot))
	return result


func find_job(network: StarNetwork, id: String) -> Dictionary:
	for office in StarNetwork.COUNT:
		for job in office_jobs(network, office):
			if job.id == id:
				return job
	return {}


func progress(job: Dictionary, model: Expedition) -> int:
	match job.kind:
		"ore":
			return mini(model.ore, job.amount)
		"salvage":
			return mini(model.scrap, job.amount)
		"survey":
			return 1 if model.network.surveyed[job.target] else 0
		"bounty":
			var count := 0
			for hostile in model.network.encounter(job.target):
				if model.consumed.has(hostile.id):
					count += 1
			return count
	return 0


func can_accept(job: Dictionary, model: Expedition) -> bool:
	if (
		job.is_empty()
		or job.status != OFFER
		or job.office != model.network.current
		or active_jobs(model.network).size() >= 3
	):
		return false
	# A closed signal or destroyed squadron can never mint fresh commissions.
	return (
		available_stock(job.kind, model) >= int(job.amount)
		if job.kind in ["ore", "salvage"]
		else progress(job, model) < int(job.amount)
	)


func accept(id: String, model: Expedition) -> bool:
	var job := find_job(model.network, id)
	if not can_accept(job, model):
		return false
	boards[job.office].states[job.slot] = ACTIVE
	tracked = id
	model.changed.emit()
	return true


func ready(job: Dictionary, model: Expedition) -> bool:
	return not job.is_empty() and job.status == ACTIVE and progress(job, model) >= int(job.amount)


func claim(id: String, model: Expedition) -> bool:
	var job := find_job(model.network, id)
	if not ready(job, model) or job.office != model.network.current:
		return false
	if job.kind == "ore":
		if not model.bay.take_ore(job.amount):
			return false
		model.ore -= int(job.amount)
	elif job.kind == "salvage":
		if not model.bay.take_salvage(job.amount):
			return false
		model.scrap -= int(job.amount)
	boards[job.office].states[job.slot] = PAID
	completed += 1
	model.credits += int(job.reward)
	if tracked == id:
		tracked = ""
	model.changed.emit()
	return true


func abandon(id: String, model: Expedition) -> bool:
	var job := find_job(model.network, id)
	if job.is_empty() or job.status != ACTIVE:
		return false
	boards[job.office].states[job.slot] = CLOSED
	if tracked == id:
		tracked = ""
	model.changed.emit()
	return true


func rotate(office: int) -> bool:
	if boards[office].states.has(ACTIVE):
		return false
	boards[office].cycle += 1
	boards[office].states = [0, 0, 0, 0]
	return true


func tracked_job(network: StarNetwork) -> Dictionary:
	var job := find_job(network, tracked)
	if not job.is_empty() and job.status == ACTIVE:
		return job
	var jobs := active_jobs(network)
	return jobs[0] if not jobs.is_empty() else {}


func summary(job: Dictionary, model: Expedition) -> String:
	var unit := (
		"t aboard"
		if job.kind in ["ore", "salvage"]
		else ("hostiles cleared" if job.kind == "bounty" else "signal decoded")
	)
	return "%d / %d %s" % [progress(job, model), job.amount, unit]


func snapshot() -> Dictionary:
	return {"boards": boards.duplicate(true), "completed": completed, "tracked": tracked}


func restore(data: Variant, network: StarNetwork) -> bool:
	if (
		not data is Dictionary
		or not data.get("boards") is Array
		or data.boards.size() != StarNetwork.COUNT
	):
		return false
	if (
		not Expedition.valid_number(data.get("completed"), 0, 10000000)
		or not data.get("tracked") is String
	):
		return false
	var staged: Array[Dictionary] = []
	var active := 0
	for board in data.boards:
		if not board is Dictionary or not Expedition.valid_number(board.get("cycle"), 0, 10000000):
			return false
		if not board.get("states") is Array or board.states.size() != 4:
			return false
		var states: Array[int] = []
		for status in board.states:
			if not Expedition.valid_number(status, OFFER, CLOSED):
				return false
			states.append(int(status))
			if int(status) == ACTIVE:
				active += 1
		staged.append({"cycle": int(board.cycle), "states": states})
	if active > 3:
		return false
	boards = staged
	completed = int(data.completed)
	tracked = data.tracked
	if not tracked.is_empty():
		var job := find_job(network, tracked)
		if job.is_empty() or job.status != ACTIVE:
			return false
	return true


func available_stock(kind: String, model: Expedition) -> int:
	var stock := model.ore if kind == "ore" else model.scrap
	for system in StarNetwork.COUNT:
		var count := (7 if system == 0 else 8) if kind == "ore" else 5
		for i in count:
			var id := (
				("ore_%d" if kind == "ore" else "freight_%d") % i
				if system == 0
				else ("%d/ore/%d" if kind == "ore" else "%d/freight/%d") % [system, i]
			)
			if model.consumed.has(id):
				continue
			stock += int(model.ore_remaining.get(id, 40)) if kind == "ore" else 12
	for job in active_jobs(model.network):
		if job.kind == kind:
			stock -= int(job.amount)
	return maxi(stock, 0)


func unavailable_reason(job: Dictionary, model: Expedition) -> String:
	if active_jobs(model.network).size() >= 3:
		return "Active contract limit reached."
	if job.kind in ["ore", "salvage"]:
		return "Uncommitted recoverable supplies exhausted."
	return "Target already resolved. Request new offers."

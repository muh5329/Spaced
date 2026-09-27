class_name CargoBay
extends RefCounted
## Fixed deck geometry. Reservations prevent two returning craft claiming one space.
const WIDTH := 4
const LENGTH := 5
const CELL_SIZE := 0.58
const MASS_LIMITS := [80, 120, 180]
var level: int = 0
var items: Array[Dictionary] = []
var reservations: Dictionary = {}


func decks() -> int:
	return level + 1


func cell_count() -> int:
	return WIDTH * LENGTH * decks()


func occupied_cells(include_reservations: bool = true) -> int:
	var count := 0
	for item in items:
		count += int(item.w) * int(item.h)
	if include_reservations:
		for item in reservations.values():
			count += int(item.w) * int(item.h)
	return count


func mass(include_reservations: bool = false) -> int:
	var total := 0
	for item in items:
		total += int(item.amount)
	if include_reservations:
		for item in reservations.values():
			total += int(item.amount)
	return total


func footprint(kind: String) -> Vector2i:
	match kind:
		"salvage":
			return Vector2i(2, 2)
		"core":
			return Vector2i(2, 1)
	return Vector2i.ONE


func placement(kind: String, amount: int, ignore_owner: String = "") -> Dictionary:
	if not valid_payload(kind, amount):
		return {}
	var used: Array[Dictionary] = items.duplicate()
	var booked_mass := mass()
	for owner in reservations:
		if owner != ignore_owner:
			used.append(reservations[owner])
			booked_mass += int(reservations[owner].amount)
	if amount <= 0 or booked_mass + amount > MASS_LIMITS[level]:
		return {}
	var shape := footprint(kind)
	for deck in decks():
		for z in LENGTH:
			for x in WIDTH:
				var rect := Rect2i(x, z, shape.x, shape.y)
				if x + shape.x > WIDTH or z + shape.y > LENGTH:
					continue
				var clear := true
				for item in used:
					if (
						int(item.deck) == deck
						and rect.intersects(
							Rect2i(int(item.x), int(item.z), int(item.w), int(item.h))
						)
					):
						clear = false
						break
				if clear:
					return {
						"kind": kind,
						"amount": amount,
						"x": x,
						"z": z,
						"deck": deck,
						"w": shape.x,
						"h": shape.y
					}
	return {}


func reserve(owner: String, kind: String, amount: int) -> bool:
	if owner.is_empty():
		return false
	var slot := placement(kind, amount, owner)
	if slot.is_empty():
		return false
	reservations[owner] = slot
	return true


func release(owner: String) -> void:
	reservations.erase(owner)


func receive(owner: String, id: String, amount: int = -1) -> bool:
	if id.is_empty() or not reservations.has(owner) or items.any(func(item): return item.id == id):
		return false
	var item: Dictionary = reservations[owner].duplicate()
	if amount >= 0:
		if amount == 0 or amount > int(item.amount):
			return false
		item.amount = amount
	if not valid_payload(item.kind, item.amount):
		return false
	item.id = id
	items.append(item)
	reservations.erase(owner)
	return true


func store(id: String, kind: String, amount: int) -> bool:
	if id.is_empty() or items.any(func(item): return item.id == id):
		return false
	var slot := placement(kind, amount)
	if slot.is_empty():
		return false
	slot.id = id
	items.append(slot)
	return true


static func valid_payload(kind: String, amount: int) -> bool:
	return (
		(kind == "ore" and amount >= 1 and amount <= 4)
		or (kind == "salvage" and amount == 12)
		or (kind == "core" and amount == 8)
	)


func sellable_clear() -> void:
	items = items.filter(func(item): return item.kind == "core")


func take_ore(amount: int) -> bool:
	if amount <= 0:
		return false
	var stored := 0
	for item in items:
		if item.kind == "ore":
			stored += int(item.amount)
	if stored < amount:
		return false
	var remaining := amount
	for i in range(items.size() - 1, -1, -1):
		if items[i].kind != "ore":
			continue
		var used := mini(remaining, int(items[i].amount))
		items[i].amount -= used
		remaining -= used
		if items[i].amount == 0:
			items.remove_at(i)
		if remaining == 0:
			break
	return true


func snapshot() -> Array:
	return items.duplicate(true)


func restore(data: Variant) -> bool:
	if not data is Array or data.size() > 60:
		return false
	var staged: Array[Dictionary] = []
	var ids: Dictionary = {}
	var total := 0
	for entry in data:
		if not entry is Dictionary:
			return false
		if not entry.get("id") is String or entry.id.is_empty() or ids.has(entry.id):
			return false
		if entry.get("kind", "") not in ["ore", "salvage", "core"]:
			return false
		for field in ["x", "z", "deck", "w", "h", "amount"]:
			var value = entry.get(field)
			if (
				not (value is int or value is float)
				or not is_finite(float(value))
				or value < 0
				or value > 180
				or float(value) != floorf(float(value))
			):
				return false
		var shape := footprint(entry.kind)
		if int(entry.w) != shape.x or int(entry.h) != shape.y:
			return false
		if (
			int(entry.x) + shape.x > WIDTH
			or int(entry.z) + shape.y > LENGTH
			or int(entry.deck) >= decks()
		):
			return false
		if (
			(entry.kind == "ore" and (entry.amount < 1 or entry.amount > 4))
			or (entry.kind == "salvage" and entry.amount != 12)
			or (entry.kind == "core" and entry.amount != 8)
		):
			return false
		var rect := Rect2i(entry.x, entry.z, entry.w, entry.h)
		for other in staged:
			if (
				int(entry.deck) == int(other.deck)
				and rect.intersects(Rect2i(other.x, other.z, other.w, other.h))
			):
				return false
		ids[entry.id] = true
		total += int(entry.amount)
		staged.append(entry.duplicate())
	if total > MASS_LIMITS[level]:
		return false
	items = staged
	reservations.clear()
	return true


func take_salvage(amount: int) -> bool:
	if amount <= 0 or amount % 12 != 0:
		return false
	var count := 0
	for item in items:
		if item.kind == "salvage":
			count += 12
	if count < amount:
		return false
	var remaining := amount
	for i in range(items.size() - 1, -1, -1):
		if items[i].kind != "salvage":
			continue
		items.remove_at(i)
		remaining -= 12
		if remaining == 0:
			break
	return true

class_name InteriorUI
extends Control
## Individual crew and station controls surrounding the real 3D interior viewport.
const WHITE := Color("e1e9e9")
const MUTED := Color("8299aa")
const AMBER := Color("edbd70")
const CYAN := Color("83dce5")
var game: Node
var state: InteriorState
var deck: InteriorDeck
var selected_crew: String = "mara"
var selected_station: String = "bridge"
var buttons: Array[Button] = []
var roster_buttons: Dictionary = {}
var regular: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
var bold: Font = preload("res://assets/fonts/Barlow-SemiBold.ttf")
var display: Font = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
var message: String = "Click a crew member or room. Assign jobs using the station buttons."
var message_seconds: float = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	deck = InteriorDeck.new()
	add_child(deck)
	deck.crew_picked.connect(select_crew)
	deck.station_picked.connect(select_station)
	deck.movement_ordered.connect(
		func(value):
			message = value
			message_seconds = 7
	)
	resized.connect(layout)
	layout()


func open(model: InteriorState) -> void:
	state = model
	deck.state = model
	deck.selected_crew = selected_crew
	deck.selected_station = selected_station
	visible = true
	rebuild()


func layout() -> void:
	var factor := size / Vector2(1600, 1000)
	if is_instance_valid(deck):
		deck.position = Vector2(12, 166) * factor
		deck.size = Vector2(1170, 818) * factor
	for button in buttons:
		var rect: Rect2 = button.get_meta("rect")
		button.position = rect.position * factor
		button.size = rect.size * factor
		button.add_theme_font_size_override("font_size", maxi(10, int(16 * factor.y)))


func button_at(text: String, rect: Rect2, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.set_meta("rect", rect)
	button.add_theme_font_override("font", bold)
	button.add_theme_color_override("font_color", Color("13212a") if primary else WHITE)
	for key in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = AMBER if primary else Color("10202c")
		if key == "hover":
			style.bg_color = AMBER.lightened(0.15) if primary else Color("203e4c")
		style.border_color = Color("486173") if not primary else AMBER
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		button.add_theme_stylebox_override(key, style)
	button.pressed.connect(
		func():
			game.audio.play("ui", 0.5)
			action.call()
	)
	add_child(button)
	buttons.append(button)
	return button


func rebuild() -> void:
	for button in buttons:
		remove_child(button)
		button.queue_free()
	buttons.clear()
	roster_buttons.clear()
	button_at(
		"RETURN TO %s / TAB" % ("DOCK" if game.interior_return == "dock" else "FLIGHT"),
		Rect2(1210, 22, 362, 40),
		game.toggle_interior
	)
	button_at(
		"RESUME SYSTEMS" if game.interior_paused else "PAUSE SYSTEMS",
		Rect2(1210, 76, 178, 34),
		toggle_pause
	)
	button_at("RESET VIEW", Rect2(1400, 76, 172, 34), deck.reset_view)
	for i in state.crew.size():
		var person := state.crew[i]
		var button := button_at(
			person.display_name,
			Rect2(1210, 175 + i * 31, 362, 27),
			select_crew.bind(person.id),
			selected_crew == person.id
		)
		roster_buttons[person.id] = button
	var index := 0
	for key in InteriorState.STATIONS:
		var station_button := button_at(
			InteriorState.STATIONS[key].name,
			Rect2(1210 + (index % 2) * 186, 553 + floori(index / 2.0) * 34, 176, 29),
			assign_to.bind(key)
		)
		station_button.tooltip_text = (
			"Rest and recover fatigue."
			if key == "quarters"
			else (
				"%s: %d%% training efficiency; health and fatigue also affect output. Duties start after walking to the station."
				% [
					InteriorState.STATIONS[key].role,
					100 if state.member(selected_crew).specialty == key else 60
				]
			)
		)
		index += 1
	button_at(
		"OFF" if state.enabled[selected_station] else "ON",
		Rect2(1513, 737, 59, 26),
		func():
			state.toggle_station(selected_station)
			rebuild()
	)
	match selected_station:
		"bridge":
			button_at("TAKE COMMAND", Rect2(1210, 834, 362, 36), game.toggle_interior, true)
			button_at("SECTOR CHART", Rect2(1210, 878, 362, 34), game.toggle_map)
		"quarters":
			button_at(
				"REST SELECTED CREW", Rect2(1210, 834, 362, 36), assign_to.bind("quarters"), true
			)
			button_at(
				"RETURN TO SPECIALTY",
				Rect2(1210, 878, 362, 34),
				func(): assign_to(state.member(selected_crew).specialty)
			)
		"mess":
			button_at(
				"RATIONS: " + state.ration.to_upper(),
				Rect2(1210, 834, 362, 36),
				cycle_rations,
				true
			)
		"medbay":
			button_at("FIRST AID / 1 MEDICINE", Rect2(1210, 834, 362, 36), treat, true)
			button_at(
				"SEND SELECTED CREW TO MEDBAY", Rect2(1210, 878, 362, 34), assign_to.bind("medbay")
			)
		"engineering":
			button_at(
				"REACTOR: " + state.reactor.to_upper(),
				Rect2(1210, 822, 362, 33),
				cycle_reactor,
				true
			)
			button_at("REPLACE FILTER / 1 FILTER", Rect2(1210, 862, 362, 33), replace_filter)
			button_at("REPAIR SYSTEM / 1 KIT", Rect2(1210, 902, 362, 33), repair)
		"fabrication":
			var y := 804
			for key in InteriorState.RECIPES:
				var recipe: Dictionary = InteriorState.RECIPES[key]
				button_at(
					"%s / %d PARTS" % [recipe.name.to_upper(), recipe.parts],
					Rect2(1210, y, 362, 30),
					fabricate.bind(key)
				)
				y += 35
			button_at(
				"CANCEL LAST ORDER",
				Rect2(1210, 912, 362, 29),
				func():
					feedback(state.cancel_fabrication(), "Order canceled and materials refunded.")
			)
		"storage":
			button_at("INSPECT PHYSICAL CARGO", Rect2(1210, 822, 362, 33), game.toggle_cargo, true)
			button_at("4 t ORE → 4 SPARE PARTS", Rect2(1210, 862, 362, 33), refine)
			button_at(
				"RESUPPLY / %d CR AT MERIDIAN" % state.supply_cost(),
				Rect2(1210, 902, 362, 33),
				resupply
			)
		"hydroponics":
			button_at(
				"ASSIGN TO GROW BEDS",
				Rect2(1210, 834, 362, 36),
				assign_to.bind("hydroponics"),
				true
			)
			button_at("REPAIR IRRIGATION / 1 KIT", Rect2(1210, 878, 362, 34), repair)
		"airlock":
			button_at("BOARD LATCH / MARA + IVO", Rect2(1210, 822, 362, 33), launch_tug, true)
			button_at("RECALL FLEET & RESUME FLIGHT", Rect2(1210, 862, 362, 33), recall)
			button_at("REPAIR SEALS / 1 KIT", Rect2(1210, 902, 362, 33), repair)
	layout()


func select_crew(id: String) -> void:
	selected_crew = id
	deck.selected_crew = id
	selected_station = state.member(id).station
	deck.selected_station = selected_station
	rebuild()


func select_station(id: String) -> void:
	selected_station = id
	deck.selected_station = id
	rebuild()


func feedback(success: bool, text: String) -> void:
	message = text if success else state.last_error
	message_seconds = 7
	rebuild()


func assign_to(station: String) -> void:
	var success := deck.assign_selected(selected_crew, station)
	if success:
		selected_station = station
		deck.selected_station = station
	feedback(
		success,
		(
			state.member(selected_crew).display_name
			+ " assigned to "
			+ InteriorState.STATIONS[station].name
			+ ". Duties start on arrival."
		)
	)


func toggle_pause() -> void:
	game.interior_paused = not game.interior_paused
	rebuild()


func cycle_rations() -> void:
	var choices := ["balanced", "rationed", "generous"]
	state.ration = choices[(choices.find(state.ration) + 1) % choices.size()]
	feedback(
		true, "Rationing reduces meal use and increases fatigue; generous meals reduce fatigue."
	)


func cycle_reactor() -> void:
	var choices := ["balanced", "economy", "overdrive"]
	state.reactor = choices[(choices.find(state.reactor) + 1) % choices.size()]
	state.update_power(0)
	feedback(
		true,
		"Overdrive raises output and reactor wear. Economy lowers both output and demand on the reactor."
	)


func fabricate(recipe: String) -> void:
	feedback(
		state.queue_recipe(recipe),
		"Order queued. A powered fabrication station and operator are required."
	)


func repair() -> void:
	feedback(
		state.repair_station(selected_station),
		"Repair kit installed. Station condition restored by 40%."
	)


func replace_filter() -> void:
	feedback(state.replace_filter(), "Fresh life-support filter installed.")


func treat() -> void:
	feedback(
		state.medical_treatment(selected_crew),
		"First aid completed. The medical officer continues treatment while on duty."
	)


func refine() -> void:
	feedback(
		game.expedition.process_ore_for_parts(),
		"Four tonnes removed from the physical hold; four spare parts stored."
	)


func resupply() -> void:
	if game.interior_return != "dock":
		feedback(false, "")
		message = "Dock at Meridian to purchase supplies."
		return
	game.toggle_interior()
	game.resupply_interior()


func launch_tug() -> void:
	if game.interior_return == "dock":
		game.set_mode("dock")
		game.undock()
	else:
		game.set_mode("flight")
	game.select_fleet_unit(3)


func recall() -> void:
	if game.interior_return == "dock":
		game.set_mode("dock")
		game.undock()
	else:
		game.set_mode("flight")
	game.player.stop()
	game.fleet.recall_all()


func _process(delta: float) -> void:
	if not visible or state == null:
		return
	message_seconds = maxf(0, message_seconds - delta)
	for person in state.crew:
		if roster_buttons.has(person.id):
			var place: String = (
				"LATCH" if person.away else InteriorState.STATIONS[person.station].name.to_upper()
			)
			roster_buttons[person.id].text = "%s  /  %s" % [person.display_name.to_upper(), place]
	queue_redraw()


func text(
	value: String, point: Vector2, pixels: int = 18, color: Color = WHITE, face: Font = null
) -> void:
	draw_string(
		face if face != null else regular,
		point,
		value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		pixels,
		color
	)


func wrapped(
	value: String, point: Vector2, width: float, pixels: int = 16, color: Color = MUTED
) -> void:
	var line := ""
	var y := point.y
	for word in value.split(" "):
		if regular.get_string_size(line + word, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > width:
			text(line, Vector2(point.x, y), pixels, color)
			y += pixels + 4
			line = ""
		line += word + " "
	text(line, Vector2(point.x, y), pixels, color)


func _draw() -> void:
	if state == null:
		return
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(1600, 1000))
	draw_rect(Rect2(0, 0, 1600, 1000), Color("080e17"))
	text("WAYFARER / LIFE ABOARD", Vector2(30, 40), 27, WHITE, display)
	text(
		"LIVE SYSTEMS" if not game.interior_paused else "SYSTEMS PAUSED",
		Vector2(380, 37),
		13,
		CYAN if not game.interior_paused else AMBER,
		bold
	)
	text(
		"%02d:%02d SHIP TIME" % [int(state.sim_seconds) / 60, int(state.sim_seconds) % 60],
		Vector2(950, 37),
		14,
		MUTED
	)
	var resource_keys := ["food", "water", "oxygen", "power"]
	for i in 4:
		var key: String = resource_keys[i]
		var x := 30 + i * 290
		draw_rect(Rect2(x, 64, 277, 82), Color("0f202c"))
		var tint := AMBER if state.resources[key] < 20 else CYAN
		text(
			(
				("FOOD" if key == "food" else InteriorState.RESOURCE_NAMES[key].to_upper())
				+ " / "
				+ InteriorState.UNITS[key]
			),
			Vector2(x + 14, 87),
			13,
			MUTED,
			bold
		)
		text(
			"%05.1f / %d" % [state.resources[key], InteriorState.LIMITS[key]],
			Vector2(x + 14, 118),
			27,
			tint,
			display
		)
		text("%+.1f / min" % state.rates[key], Vector2(x + 163, 115), 14, MUTED)
		draw_rect(Rect2(x + 14, 130, 249, 3), Color("293843"))
		draw_rect(
			Rect2(x + 14, 130, 249 * state.resources[key] / InteriorState.LIMITS[key], 3), tint
		)
	draw_rect(Rect2(1196, 136, 386, 838), Color("0d1a24"))
	var aboard := state.crew.filter(func(person): return not person.away).size()
	text(
		"CREW / %02d ABOARD / %02d ON LATCH" % [aboard, state.crew.size() - aboard],
		Vector2(1210, 158),
		14,
		CYAN,
		bold
	)
	var person := state.member(selected_crew)
	text(person.display_name, Vector2(1210, 421), 29, WHITE, display)
	text("SPECIALTY: " + person.profession, Vector2(1210, 445), 14, AMBER)
	text("HEALTH %03d%%" % person.health, Vector2(1210, 472), 15, WHITE)
	text(
		"FATIGUE %03d%%" % person.fatigue,
		Vector2(1395, 472),
		15,
		AMBER if person.fatigue > 80 else WHITE
	)
	text(
		person.status() + " / " + InteriorState.STATIONS[person.station].role,
		Vector2(1210, 499),
		13,
		CYAN if person.health > 25 else AMBER
	)
	text("ASSIGN SELECTED CREW", Vector2(1210, 537), 13, MUTED, bold)
	var station: Dictionary = InteriorState.STATIONS[selected_station]
	text(station.name.to_upper(), Vector2(1210, 757), 19, AMBER, display)
	var online: bool = state.powered[selected_station] and state.enabled[selected_station]
	text(
		(
			"%s / %.0f%% CONDITION / %.0f%% STAFF"
			% [
				"ONLINE" if online else "OFFLINE",
				state.condition[selected_station],
				state.staffing(selected_station) * 100
			]
		),
		Vector2(1210, 786),
		12,
		CYAN if online else AMBER
	)
	match selected_station:
		"bridge":
			text(
				(
					"NAV +%.1f m/s / DISPATCH +%.1f m"
					% [state.working("bridge") * 2, state.working("bridge") * 5]
				),
				Vector2(1210, 814),
				14,
				MUTED
			)
		"quarters":
			text("Rest: −22.8 fatigue/min; slowly heals.", Vector2(1210, 814), 14, MUTED)
		"mess":
			text(
				"CROPS %.1f / GALLEY → MEALS" % state.resources.crops, Vector2(1210, 814), 14, MUTED
			)
		"medbay":
			text(
				(
					"MEDICINE %.1f / %.0f%% MEDICAL COVER"
					% [state.resources.medicine, state.working("medbay") * 100]
				),
				Vector2(1210, 814),
				14,
				MUTED
			)
		"engineering":
			text(
				(
					"%.1f kW / %.1f kW LOAD · FILTER %.0f%%"
					% [state.generation, state.demand, state.filter_condition]
				),
				Vector2(1210, 812),
				14,
				MUTED
			)
		"fabrication":
			if not state.fabrication_queue.is_empty():
				var job: String = state.fabrication_queue[0]
				text(
					(
						"%s / %d%% / %d QUEUED"
						% [
							job.to_upper(),
							100 * state.fabrication_progress / InteriorState.RECIPES[job].seconds,
							state.fabrication_queue.size()
						]
					),
					Vector2(1210, 958),
					12,
					CYAN
				)
			else:
				text(
					"PARTS %.0f / QUEUE EMPTY" % state.resources.parts,
					Vector2(1210, 958),
					13,
					MUTED
				)
		"storage":
			text(
				(
					"PARTS %.0f · KITS %.0f · FILTERS %.0f"
					% [state.resources.parts, state.resources.repair_kits, state.resources.filters]
				),
				Vector2(1210, 812),
				14,
				MUTED
			)
		"hydroponics":
			text(
				"CROPS %.1f / WATER → CROPS + OXYGEN" % state.resources.crops,
				Vector2(1210, 814),
				14,
				MUTED
			)
		"airlock":
			text(
				(
					"SEALS SECURED / SECURITY %.0f%%" % (state.working("airlock") * 100)
					if online
					else "SEAL POWER LOST / OXYGEN LEAK"
				),
				Vector2(1210, 812),
				14,
				MUTED if online else AMBER
			)
	if selected_station not in ["fabrication", "engineering", "storage", "airlock"]:
		wrapped(station.function, Vector2(1210, 935), 360, 13)
	if message_seconds > 0:
		text(message, Vector2(32, 162), 14, AMBER)
	elif not state.alerts.is_empty():
		text(" • ".join(state.alerts), Vector2(32, 162), 14, AMBER)
	else:
		text(
			"3D DECK · CLICK TO SELECT · RIGHT-CLICK MOVE · RIGHT-DRAG ORBIT · WHEEL ZOOM · MIDDLE-DRAG PAN",
			Vector2(32, 162),
			13,
			MUTED
		)

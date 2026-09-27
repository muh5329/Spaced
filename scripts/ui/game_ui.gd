class_name GameUI
extends Control
## Read-only presentation of domain state. All buttons invoke application commands.
const WHITE := Color("e1e9e9")
const MUTED := Color("8198a6")
const AMBER := Color("edbd70")
const CYAN := Color("83dce5")
const DARK := Color(0.027, 0.049, 0.067, 0.94)
const LINE := Color(0.40, 0.56, 0.65, 0.27)
var regular: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
var bold: Font = preload("res://assets/fonts/Barlow-SemiBold.ttf")
var display: Font = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
var game: Node
var buttons: Array[Button] = []
var toast_text: String = ""
var toast_time: float = 0.0
var time: float = 0.0
var damage_flash: float = 0.0
var hints_visible: bool = true
var menu_shade: GradientTexture2D
var interior_panel: InteriorUI
var voyage_view := VoyageUI.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout_buttons)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray(
		[
			Color(0.023, 0.043, 0.06, 0.99),
			Color(0.023, 0.043, 0.06, 0.88),
			Color(0.023, 0.043, 0.06, 0.0)
		]
	)
	menu_shade = GradientTexture2D.new()
	menu_shade.gradient = gradient
	menu_shade.width = 1024
	menu_shade.height = 4
	menu_shade.fill_from = Vector2.ZERO
	menu_shade.fill_to = Vector2.RIGHT
	interior_panel = InteriorUI.new()
	interior_panel.game = game
	add_child(interior_panel)
	interior_panel.visible = false


func _process(delta: float) -> void:
	time += delta
	toast_time = maxf(0, toast_time - delta)
	damage_flash = maxf(0, damage_flash - delta * 1.5)
	if is_instance_valid(game) and game.fleet != null:
		for button in buttons:
			if button.has_meta("fleet_index"):
				var index: int = button.get_meta("fleet_index")
				var unit: CommandShip = game.player if index == 0 else game.fleet.craft[index - 1]
				var state := (
					"MOTHERSHIP"
					if index == 0
					else (
						"ABOARD"
						if unit.phase == SupportCraft.Phase.DOCKED
						else (
							"%d t LOAD" % unit.payload_amount
							if unit.payload_amount > 0
							else "DEPLOYED"
						)
					)
				)
				button.text = (
					"%s%d  %s  /  %s"
					% [
						"● " if unit.selected else "",
						index + 1,
						["WAYFARER", "MOLE 01", "MOLE 02", "LATCH"][index],
						state
					]
				)
	queue_redraw()


func _layout_buttons() -> void:
	for button in buttons:
		var rect: Rect2 = button.get_meta("design_rect")
		button.position = rect.position * size / Vector2(1600, 1000)
		button.size = rect.size * size / Vector2(1600, 1000)
		button.add_theme_font_size_override("font_size", int(18 * size.y / 1000))


func toast(message: String, seconds: float = 4.0) -> void:
	toast_text = message
	toast_time = seconds


func rebuild() -> void:
	for button in buttons:
		button.queue_free()
	buttons.clear()
	interior_panel.visible = game.mode == "interior"
	if game.mode == "interior":
		interior_panel.open(game.expedition.interior_state)
		return
	if game.mode in ["galaxy", "jobs", "jump"]:
		voyage_view.rebuild(self)
		return
	match game.mode:
		"menu":
			var saved: bool = SaveStore.load_game() != null
			if saved:
				button_at(
					"CONTINUE EXPEDITION   →", Rect2(74, 548, 420, 61), game.continue_game, true
				)
			button_at(
				"NEW EXPEDITION   →",
				Rect2(74, 625 if saved else 548, 420, 61),
				game.request_new_game,
				not saved
			)
			button_at(
				"FLIGHT MANUAL",
				Rect2(74, 702 if saved else 625, 201, 50),
				func(): game.open_manual("menu")
			)
			button_at(
				"SETTINGS",
				Rect2(290, 702 if saved else 625, 204, 50),
				func(): game.open_settings("menu")
			)
			button_at("EXIT", Rect2(74, 808, 106, 41), game.quit_game)
		"confirm_new":
			button_at("BEGIN NEW EXPEDITION", Rect2(542, 554, 516, 58), game.new_game, true)
			button_at("KEEP MY CHECKPOINT", Rect2(542, 630, 516, 52), func(): game.set_mode("menu"))
		"flight":
			button_at("J / STAR NETWORK", Rect2(632, 115, 208, 38), game.voyage.open_chart)
			button_at("L / CONTRACTS", Rect2(853, 115, 179, 38), game.voyage.open_jobs)
			button_at("C  /  CARGO", Rect2(1045, 115, 162, 38), game.toggle_cargo)
			button_at("TAB  /  SHIP", Rect2(1220, 115, 157, 38), game.toggle_interior)
			button_at("M  /  CHART", Rect2(1390, 115, 164, 38), game.toggle_map)
			for index in 4:
				button_at(
					"", Rect2(40, 523 + index * 49, 334, 40), game.select_fleet_unit.bind(index)
				)
				buttons[-1].set_meta("fleet_index", index)
		"dock":
			button_at(
				"STATION COMMISSIONS / L", Rect2(70, 598, 590, 50), game.voyage.open_jobs, true
			)
			button_at("STAR NETWORK / J", Rect2(70, 664, 590, 50), game.voyage.open_chart)
			button_at("CREW & LIFE SUPPORT / TAB", Rect2(70, 730, 590, 48), game.toggle_interior)
			button_at(
				"RESUPPLY / %d CR" % game.expedition.interior_state.supply_cost(),
				Rect2(926, 801, 590, 44),
				game.resupply_interior
			)
			button_at(
				"SELL CARGO  /  +%d CR" % (game.expedition.ore * 8 + game.expedition.scrap * 12),
				Rect2(926, 358, 590, 55),
				game.sell_cargo,
				true
			)
			button_at(
				(
					(
						"COMPLETE STORY CONTRACT"
						if game.expedition.contract_ready()
						else "STORY CONTRACT IN PROGRESS"
					)
					if game.expedition.network.current == 0
					else "MERIDIAN STORY / RETURN TO ORISON"
				),
				Rect2(926, 431, 590, 52),
				game.complete_contract,
				false,
				game.expedition.network.current != 0 or not game.expedition.contract_ready()
			)
			var i := 0
			for kind in ["engine", "weapon", "shield", "cargo"]:
				var level: int = game.expedition.upgrades[kind]
				var cost: int = game.expedition.upgrade_cost(kind)
				var caption := (
					"%s   /   %s"
					% [
						Expedition.UPGRADE_NAMES[kind].to_upper(),
						"MAXED" if level == 2 else str(cost) + " CR"
					]
				)
				button_at(
					caption,
					Rect2(926, 560 + i * 66, 590, 50),
					game.buy_upgrade.bind(kind),
					false,
					level == 2 or game.expedition.credits < cost
				)
				i += 1
			button_at("UNDOCK   →", Rect2(926, 868, 590, 58), game.undock, true)
		"cargo":
			button_at(
				"RETURN TO %s / C" % game.cargo_return.to_upper(),
				Rect2(1140, 871, 375, 56),
				game.toggle_cargo,
				true
			)
		"pause":
			button_at(
				"RESUME %s   →" % game.pause_return.to_upper(),
				Rect2(590, 390, 420, 58),
				game.resume,
				true
			)
			button_at("SETTINGS", Rect2(590, 467, 420, 52), func(): game.open_settings("pause"))
			button_at("FLIGHT MANUAL", Rect2(590, 537, 420, 52), func(): game.open_manual("pause"))
			button_at("RETURN TO TITLE", Rect2(590, 633, 420, 52), game.return_to_title)
		"settings":
			button_at("−", Rect2(996, 368, 52, 45), game.adjust_audio.bind("music", -0.1))
			button_at("+", Rect2(1060, 368, 52, 45), game.adjust_audio.bind("music", 0.1))
			button_at("−", Rect2(996, 450, 52, 45), game.adjust_audio.bind("effects", -0.1))
			button_at("+", Rect2(1060, 450, 52, 45), game.adjust_audio.bind("effects", 0.1))
			button_at("TOGGLE", Rect2(996, 532, 116, 45), game.toggle_shake)
			button_at("TOGGLE", Rect2(996, 614, 116, 45), game.toggle_fullscreen)
			button_at("BACK", Rect2(486, 749, 626, 55), game.close_settings, true)
		"manual":
			button_at("UNDERSTOOD   →", Rect2(1110, 863, 340, 57), game.close_manual, true)
		"map":
			button_at(
				"RETURN TO %s / M" % game.map_return.to_upper(),
				Rect2(1110, 875, 400, 56),
				game.toggle_map,
				true
			)
		"lost":
			button_at("RETRY FROM CHECKPOINT   →", Rect2(550, 568, 500, 58), game.retry, true)
			button_at("RETURN TO TITLE", Rect2(550, 651, 500, 52), game.return_to_title)
		"won":
			button_at("KEEP EXPLORING   →", Rect2(550, 673, 500, 58), game.resume, true)
			button_at("RETURN TO TITLE", Rect2(550, 755, 500, 52), game.return_to_title)
	_layout_buttons()


func button_at(
	caption: String, rect: Rect2, action: Callable, primary: bool = false, disabled: bool = false
) -> void:
	var button := Button.new()
	button.text = caption
	button.set_meta("design_rect", rect)
	button.disabled = disabled
	if game.mode == "flight":
		button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", bold)
	button.add_theme_color_override("font_color", Color("172028") if primary else WHITE)
	button.add_theme_color_override("font_hover_color", Color("172028") if primary else AMBER)
	button.add_theme_color_override("font_pressed_color", Color("172028"))
	button.add_theme_color_override("font_disabled_color", Color("687c88"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = AMBER if primary else Color(0.04, 0.07, 0.095, 0.94)
		if state == "hover":
			style.bg_color = AMBER.lightened(0.15) if primary else Color("172c37")
		if state == "pressed":
			style.bg_color = CYAN
		if state == "disabled":
			style.bg_color = Color("111e27")
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
		style.border_color = AMBER if state == "focus" or state == "hover" else LINE
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(2)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(
		func():
			game.audio.play("ui")
			action.call()
	)
	add_child(button)
	buttons.append(button)


func ink(
	value: String, pos: Vector2, font_size: int = 18, color: Color = WHITE, font: Font = null
) -> void:
	draw_string(
		regular if font == null else font,
		pos,
		value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)


func line(a: Vector2, b: Vector2, color: Color = LINE) -> void:
	draw_line(a, b, color, 1.0, true)


func panel(rect: Rect2, alpha: float = 0.94) -> void:
	draw_rect(rect, Color(DARK, alpha))
	line(rect.position, rect.position + Vector2(rect.size.x, 0))


func diamond(point: Vector2, radius: float, color: Color = AMBER) -> void:
	draw_polyline(
		PackedVector2Array(
			[
				point + Vector2(0, -radius),
				point + Vector2(radius, 0),
				point + Vector2(0, radius),
				point + Vector2(-radius, 0),
				point + Vector2(0, -radius)
			]
		),
		color,
		1.5,
		true
	)


func _draw() -> void:
	if not is_instance_valid(game) or game.expedition == null:
		return
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(1600, 1000))
	match game.mode:
		"menu":
			draw_menu()
		"flight":
			draw_flight()
		"dock":
			draw_dock()
		"interior":
			pass  # InteriorUI owns this entire interactive screen.
		"cargo":
			draw_cargo()
		"map":
			draw_map()
		"galaxy", "jobs", "jump":
			voyage_view.draw(self)
		"manual":
			draw_manual()
		"pause":
			draw_pause()
		"settings":
			draw_settings()
		"confirm_new":
			draw_confirm()
		"lost", "won":
			draw_ending()
	if toast_time > 0 and game.mode not in ["menu", "interior", "jump"]:
		var bounds := toast_bounds()
		panel(bounds, minf(0.95, toast_time))
		draw_rect(Rect2(bounds.position, Vector2(3, bounds.size.y)), AMBER)
		var lines := toast_lines()
		for i in lines.size():
			ink(
				lines[i],
				bounds.position + Vector2(24, 28 + i * 24),
				19,
				Color(WHITE, minf(1, toast_time))
			)

	if damage_flash > 0 and game.mode == "flight":
		draw_rect(Rect2(0, 0, 1600, 1000), Color(0.8, 0.18, 0.07, damage_flash * 0.1))
		for i in 4:
			draw_rect(
				Rect2(i * 3, i * 3, 1600 - i * 6, 1000 - i * 6),
				Color(1, 0.35, 0.2, damage_flash * 0.15),
				false,
				3
			)
	if game.mode == "flight" and game.selection_box.dragging:
		# Gesture coordinates are viewport pixels, unlike the scaled design layout.
		draw_set_transform(Vector2.ZERO)
		var bounds: Rect2 = game.selection_box.rectangle()
		draw_rect(bounds, Color(CYAN, 0.09))
		draw_rect(bounds, Color(CYAN, 0.9), false, 1.5)


func topbar(subtitle: String) -> void:
	panel(Rect2(0, 0, 1600, 98), 0.90)
	diamond(Vector2(61, 46), 17)
	line(Vector2(61, 32), Vector2(61, 60), AMBER)
	ink("W A Y F A R E R", Vector2(98, 47), 26, WHITE, bold)
	ink("W F – 0 7   /   " + subtitle, Vector2(99, 72), 12, MUTED)
	ink(StarNetwork.NAMES[game.expedition.network.current].to_upper(), Vector2(690, 43), 15, WHITE)
	ink(
		"FRONTIER NETWORK    /    SYSTEM %02d" % (game.expedition.network.current + 1),
		Vector2(687, 67),
		12,
		MUTED
	)
	ink(
		(
			"CARGO  %d/%d CELLS"
			% [game.expedition.bay.occupied_cells(false), game.expedition.bay.cell_count()]
		),
		Vector2(1190, 38),
		12,
		MUTED
	)
	ink(
		"%d / %d t" % [game.expedition.cargo_used(), game.expedition.capacity()],
		Vector2(1190, 65),
		23,
		WHITE,
		display
	)
	line(Vector2(1343, 25), Vector2(1343, 72))
	ink("ACCOUNT", Vector2(1380, 38), 12, MUTED)
	ink("%s CR" % game.expedition.credits, Vector2(1380, 65), 25, AMBER, display)


func draw_menu() -> void:
	draw_texture_rect(menu_shade, Rect2(0, 0, 1040, 1000), false)
	ink("AN ORISON EXPEDITION", Vector2(76, 87), 15, AMBER)
	line(Vector2(76, 108), Vector2(474, 108))
	diamond(Vector2(99, 198), 24)
	ink("W A Y F A R E R", Vector2(70, 338), 93, WHITE, display)
	ink("A HOME BETWEEN STARS", Vector2(78, 386), 20, AMBER)
	ink("An old ship. A scattered crew. One last way home.", Vector2(78, 455), 21, WHITE)
	ink("Salvage the forgotten. Survive the belt. Build your future.", Vector2(78, 487), 18, MUTED)
	ink("01  /  THE LONG WAY HOME", Vector2(1066, 746), 15, AMBER)
	line(Vector2(1066, 765), Vector2(1480, 765))
	ink("WF–07   ·   INDEPENDENT SALVAGE VESSEL", Vector2(1066, 792), 13, MUTED)
	panel(Rect2(0, 926, 1600, 74), 0.90)
	ink(
		"S A L V A G E .   T R A D E .   F I G H T .   S U R V I V E .", Vector2(76, 969), 13, MUTED
	)
	ink("SINGLE PLAYER   /   KEYBOARD + MOUSE", Vector2(1172, 969), 12, MUTED)


func draw_flight() -> void:
	draw_orders()
	draw_markers()
	topbar("VOLUMETRIC FLIGHT ONLINE")
	panel(Rect2(40, 132, 335, 218), 0.84)
	var job: Dictionary = game.expedition.contracts.tracked_job(game.expedition.network)
	ink(
		(
			"TRACKED COMMISSION / L"
			if not job.is_empty()
			else ("MERIDIAN STORY" if game.expedition.network.current == 0 else "OPEN EXPEDITION")
		),
		Vector2(60, 161),
		12,
		AMBER
	)
	ink(
		(
			job.title.to_upper()
			if not job.is_empty()
			else (
				Expedition.TITLES[game.expedition.act].to_upper()
				if game.expedition.network.current == 0
				else "FIND YOUR NEXT JOB"
			)
		),
		Vector2(60, 194),
		25,
		WHITE,
		display
	)
	line(Vector2(60, 211), Vector2(351, 211))
	var objectives: Array[String] = game.voyage.objective_lines()
	for i in objectives.size():
		diamond(Vector2(67, 238 + i * 34), 3, AMBER if i == 0 else MUTED)
		ink(objectives[i], Vector2(83, 244 + i * 34), 16, WHITE if i == 0 else MUTED)
	var hazard: String = game.sector.hazard_warning()
	if not hazard.is_empty():
		var hazard_y := 308 if toast_time > 0 else 242
		panel(Rect2(520, hazard_y, 740, 44), 0.94)
		ink(hazard, Vector2(543, hazard_y + 28), 18, AMBER)
	if game.sector.threat_level() > 0:
		var threat_y := 250 if toast_time > 0 else 190
		panel(Rect2(612, threat_y, 376, 46), 0.88)
		ink(
			"HOSTILE CONTACTS  /  %d" % game.sector.threat_level(),
			Vector2(656, threat_y + 29),
			18,
			MeshKit.RED,
			bold
		)
	panel(Rect2(40, 370, 335, 126), 0.88)
	var life: InteriorState = game.expedition.interior_state
	ink("LIFE SUPPORT / TAB", Vector2(60, 394), 13, CYAN if life.alerts.is_empty() else AMBER, bold)
	ink(
		"FOOD %03d   WATER %03d L" % [life.resources.food, life.resources.water],
		Vector2(60, 422),
		16,
		WHITE
	)
	ink(
		"OXYGEN %03d%%   BATTERY %03d%%" % [life.resources.oxygen, life.resources.power],
		Vector2(60, 448),
		15,
		WHITE
	)
	ink(
		life.alerts[0] if not life.alerts.is_empty() else "All stations nominal. Tab assigns crew.",
		Vector2(60, 477),
		13,
		AMBER if not life.alerts.is_empty() else MUTED
	)
	var player: PlayerShip = game.player
	var controlled: CommandShip = game.selected_unit
	ink("WORKING FLEET / 1–4 SELECT", Vector2(58, 513), 12, CYAN)
	panel(Rect2(40, 745, 334, 53), 0.88)
	draw_rect(Rect2(40, 745, 3, 53), CYAN if controlled.selected else AMBER)
	var selection_count: int = game.selected_units().size()
	var selection_label := (
		"%d CRAFT / GROUP SELECTED" % selection_count
		if selection_count > 1
		else (
			controlled.display_name.to_upper()
			+ " / "
			+ ("SELECTED" if controlled.selected else "AWAITING SELECTION")
		)
	)
	ink(selection_label, Vector2(58, 766), 12, CYAN)
	ink(
		controlled.order_label if controlled.selected else "CLICK THE SHIP TO TAKE COMMAND",
		Vector2(58, 785),
		11,
		MUTED
	)
	panel(Rect2(40, 810, 334, 137), 0.88)
	ink("WAYFARER", Vector2(58, 838), 16, WHITE, bold)
	ink("ALT %+03d m" % roundi(player.position.y), Vector2(163, 838), 12, AMBER)
	ink("%02d m/s" % int(player.velocity.length()), Vector2(279, 838), 16, CYAN, display)
	bar(
		"HULL",
		player.hull,
		player.max_hull,
		Vector2(60, 858),
		WHITE if player.hull > 35 else MeshKit.RED
	)
	bar("SHIELD", player.shield, player.max_shield, Vector2(60, 887), CYAN)
	bar("BOOST", player.energy, 100, Vector2(60, 916), AMBER)
	draw_radar()
	draw_interaction()
	panel(Rect2(0, 967, 1600, 33), 0.93)
	var controls := "DRAG  SELECT     SHIFT-DRAG  ADD     CLICK  COMMAND     G  3D MOVE     RMB DRAG  ORBIT     R  RECALL     X  STOP"
	if game.move_preview.active:
		controls = "MOVE  HORIZONTAL PLANE     SHIFT + MOVE / WHEEL  ALTITUDE     CLICK  CONFIRM     RMB / ESC  CANCEL"
	ink(controls, Vector2(204, 989), 13, MUTED)
	ink("ESC  PAUSE", Vector2(1460, 989), 12, MUTED)


func world_to_hud(point: Vector3) -> Vector2:
	return game.camera.unproject_position(point) * Vector2(1600, 1000) / size


func draw_orders() -> void:
	var members: Array[CommandShip] = game.selected_units()
	if members.is_empty():
		members.append(game.player)
	for unit in members:
		if unit.visible and not game.camera.is_position_behind(unit.position):
			draw_unit_order(unit)
	if game.move_preview.active:
		draw_move_preview()


func draw_unit_order(player: CommandShip) -> void:
	var ring := PackedVector2Array()
	for i in 65:
		var angle := TAU * i / 64
		ring.append(
			world_to_hud(
				(
					player.position
					+ Vector3(cos(angle), 0, sin(angle)) * (2.8 if player is SupportCraft else 8.5)
				)
			)
		)
	draw_polyline(ring, Color(CYAN, 0.8) if player.selected else Color(AMBER, 0.35), 1.5, true)
	var center := world_to_hud(player.position)
	if absf(player.position.y) > 1:
		var ground := Vector3(player.position.x, 0, player.position.z)
		draw_world_line(player.position, ground, Color(CYAN, 0.28), true)
		if not game.camera.is_position_behind(ground):
			diamond(world_to_hud(ground), 5, Color(CYAN, 0.5))
	if not player.selected:
		ink("CLICK TO SELECT", center + Vector2(-49, 92), 12, AMBER)
		return
	if player.navigator.active():
		var previous := player.position
		for point in player.navigator.route:
			draw_world_line(previous, point, Color(CYAN, 0.65), true)
			if not game.camera.is_position_behind(point):
				draw_circle(world_to_hud(point), 3, CYAN)
			previous = point
		if not game.camera.is_position_behind(player.navigator.destination):
			var finish := world_to_hud(player.navigator.destination)
			draw_arc(finish, 15 + sin(time * 4) * 2, 0, TAU, 32, CYAN, 1.5, true)
			diamond(finish, 6, CYAN)
			ink(
				(
					"COURSE %d m  /  ALT %+d"
					% [
						int(player.position.distance_to(player.navigator.destination)),
						roundi(player.navigator.destination.y)
					]
				),
				finish + Vector2(23, -8),
				12,
				CYAN
			)
	if (
		player is PlayerShip
		and is_instance_valid(player.attack_target)
		and not game.camera.is_position_behind(player.attack_target.position)
	):
		var target := world_to_hud(player.attack_target.position)
		draw_arc(target, 41, time * 0.3, time * 0.3 + PI * 1.6, 40, MeshKit.RED, 2, true)
		ink("ENGAGING", target + Vector2(-27, 62), 12, MeshKit.RED)


func draw_world_line(start: Vector3, finish: Vector3, color: Color, dashed: bool = false) -> void:
	if game.camera.is_position_behind(start) or game.camera.is_position_behind(finish):
		return
	if dashed:
		draw_dashed_line(world_to_hud(start), world_to_hud(finish), color, 1.5, 8, true)
	else:
		draw_line(world_to_hud(start), world_to_hud(finish), color, 1, true)


func draw_move_preview() -> void:
	var draft: MoveOrderPreview = game.move_preview
	var destination := draft.destination()
	var center: Vector3 = game.selection_center()
	var plane_origin := Vector3(center.x, draft.origin.y, center.z)
	for radius in [10.0, 20.0, 30.0, 40.0]:
		for i in 64:
			var a: Vector3 = (
				plane_origin + Vector3(cos(TAU * i / 64), 0, sin(TAU * i / 64)) * radius
			)
			var b: Vector3 = (
				plane_origin + Vector3(cos(TAU * (i + 1) / 64), 0, sin(TAU * (i + 1) / 64)) * radius
			)
			draw_world_line(a, b, Color(CYAN, 0.18))
	for i in 12:
		var direction := Vector3(cos(TAU * i / 12), 0, sin(TAU * i / 12))
		draw_world_line(
			plane_origin + direction * 6.5, plane_origin + direction * 40, Color(CYAN, 0.16)
		)
	draw_world_line(center, draft.base, Color(AMBER, 0.75), true)
	draw_world_line(draft.base, destination, AMBER)
	draw_world_line(center, destination, Color(AMBER, 0.45), true)
	if not game.camera.is_position_behind(draft.base):
		draw_arc(world_to_hud(draft.base), 10, 0, TAU, 32, AMBER, 1.5, true)
	if not game.camera.is_position_behind(destination):
		var point := world_to_hud(destination)
		diamond(point, 12, AMBER)
		line(point + Vector2(-19, 0), point + Vector2(19, 0), AMBER)
		ink("ALT %+d m" % roundi(destination.y), point + Vector2(25, -8), 15, AMBER, bold)
	for height in range(
		int(minf(draft.base.y, destination.y)), int(maxf(draft.base.y, destination.y)) + 1, 5
	):
		var tick := Vector3(destination.x, height, destination.z)
		if not game.camera.is_position_behind(tick):
			var point := world_to_hud(tick)
			line(point + Vector2(-5, 0), point + Vector2(5, 0), Color(AMBER, 0.7))
	panel(Rect2(461, 739, 688, 69), 0.92)
	ink(
		(
			"3D MOVE  /  RANGE %d m  /  ALTITUDE %+d m"
			% [int(game.selected_unit.position.distance_to(destination)), roundi(destination.y)]
		),
		Vector2(484, 765),
		15,
		AMBER,
		bold
	)
	ink(
		"Move: plane     Shift: height     Wheel: height step     Click: confirm",
		Vector2(484, 790),
		16,
		WHITE
	)


func blocks_world_input(screen: Vector2) -> bool:
	var point := screen * Vector2(1600, 1000) / size
	for button in buttons:
		if button.get_global_rect().has_point(screen):
			return true
	var panels: Array[Rect2] = [
		Rect2(0, 0, 1600, 98),
		Rect2(0, 967, 1600, 33),
		Rect2(40, 132, 335, 218),
		Rect2(40, 745, 334, 202)
	]
	panels.append(Rect2(40, 370, 335, 126))
	if is_instance_valid(game.interaction_target):
		panels.append(Rect2(571, 824, 458, 105))
	if game.move_preview.active:
		panels.append(Rect2(461, 739, 688, 69))
	if game.sector.threat_level() > 0:
		panels.append(Rect2(612, 250 if toast_time > 0 else 190, 376, 46))
	if not game.sector.hazard_warning().is_empty():
		panels.append(Rect2(520, 308 if toast_time > 0 else 242, 740, 44))
	if toast_time > 0:
		panels.append(toast_bounds())
	return (
		point.distance_to(Vector2(1450, 844)) < 98
		or panels.any(func(rect): return rect.has_point(point))
	)


func navigation_marker(point: Vector3) -> Vector2:
	# Keep the entire click disc below the threat banner and above the radar.
	var screen := world_to_hud(point)
	if game.camera.is_position_behind(point):
		screen = Vector2(800, 500) - (screen - Vector2(800, 500)).normalized() * 2000
	var top := 265
	if not game.sector.hazard_warning().is_empty():
		top = 370 if toast_time > 0 else 302
	elif game.sector.threat_level() > 0 and toast_time > 0:
		top = 315
	return screen.clamp(Vector2(415, top), Vector2(1510, 710))


func navigation_goal_at(screen: Vector2) -> Variant:
	var point := screen * Vector2(1600, 1000) / size
	for goal in game.navigation_points():
		if point.distance_to(navigation_marker(goal[1])) < 24:
			return goal[1]
	return null


func bar(title: String, value: float, maximum: float, pos: Vector2, color: Color) -> void:
	ink(title, pos + Vector2(0, 9), 11, MUTED)
	draw_rect(Rect2(pos + Vector2(67, 0), Vector2(161, 5)), Color("23333e"))
	draw_rect(Rect2(pos + Vector2(67, 0), Vector2(161 * clampf(value / maximum, 0, 1), 5)), color)
	ink("%d" % int(value), pos + Vector2(250, 9), 14, color, display)


func draw_interaction() -> void:
	if is_instance_valid(game.interaction_target):
		var target: SpaceEntity = game.interaction_target
		panel(Rect2(571, 824, 458, 105), 0.90)
		ink(
			"[ E ]  " + target.display_name.to_upper(),
			Vector2(595, 856),
			20,
			target.contact_color,
			display
		)
		var caption := target.interaction_text()
		if target.category == "station":
			caption = "HOLD TO DOCK  /  FREE REPAIRS & TRADE"
		if target.category == "gate":
			caption = (
				"J / STAR NETWORK"
				if game.expedition.network.current > 0
				else "J / TRANSIT   ·   HOLD E / STORY CORRIDOR"
			)
		if target is Harvestable:
			caption = (
				"PRESS E TO DISPATCH  /  "
				+ ("TWO-PERSON SALVAGE CREW" if target is SalvageCache else "MINING DRONE")
			)
		ink(caption, Vector2(596, 883), 13, MUTED)
		draw_rect(Rect2(595, 901, 409, 3), Color("243740"))
		draw_rect(Rect2(595, 901, 409 * game.interaction_progress, 3), target.contact_color)
	else:
		ink("%s" % game.navigation_hint(), Vector2(573, 918), 15, MUTED)
	if game.scan_timer > 0:
		ink("SURVEY PULSE  /  CONTACTS REVEALED", Vector2(617, 791), 12, CYAN)


func draw_markers() -> void:
	for unit in game.fleet.craft:
		if not unit.visible or game.camera.is_position_behind(unit.position):
			continue
		var point := world_to_hud(unit.position)
		if point.x > 390 and point.x < 1500 and point.y > 195 and point.y < 745:
			diamond(point, 17, AMBER if unit.is_tug() else CYAN)
			ink(
				"%d / %s" % [unit.fleet_index + 2, unit.display_name.to_upper()],
				point + Vector2(24, -6),
				12,
				AMBER if unit.is_tug() else CYAN
			)
			if unit.payload_amount > 0:
				ink("%d t IN TRANSIT" % unit.payload_amount, point + Vector2(24, 12), 11, MUTED)
	if game.scan_timer > 0:
		for contact in game.sector.contacts:
			if (
				not is_instance_valid(contact)
				or not contact.available
				or contact is Ship
				or contact.position.distance_to(game.player.position) > 65
				or game.camera.is_position_behind(contact.position)
			):
				continue
			var p: Vector2 = (
				game.camera.unproject_position(contact.position) * Vector2(1600, 1000) / size
			)
			if p.x > 390 and p.x < 1490 and p.y > 210 and p.y < 790:
				draw_arc(p, 26, 0, TAU, 24, Color(contact.contact_color, 0.45), 1, true)
				ink(contact.display_name.to_upper(), p + Vector2(33, -7), 11, contact.contact_color)
				if contact is OreAsteroid:
					ink("%d t AVAILABLE" % contact.remaining, p + Vector2(33, 12), 11, MUTED)
	var goals: Array = game.navigation_points()
	for goal in goals:
		var point: Vector3 = goal[1]
		var screen: Vector2 = game.camera.unproject_position(point) * Vector2(1600, 1000) / size
		var offscreen: bool = (
			game.camera.is_position_behind(point)
			or screen.x < 400
			or screen.x > 1520
			or screen.y < 200
			or screen.y > 780
		)
		screen = navigation_marker(point)
		var distance: float = game.player.position.distance_to(point)
		var color: Color = goal[2]
		diamond(screen, 9 if offscreen else 14, Color(color, 0.8))
		if not offscreen:
			line(screen + Vector2(0, 18), screen + Vector2(0, 34), Color(color, 0.5))
		var label_pos := screen + Vector2(18, 6) if offscreen else screen + Vector2(18, 39)
		label_pos.x = minf(label_pos.x, 1380)
		ink(goal[0], label_pos, 13, color)
		ink("%d m" % int(distance), label_pos + Vector2(0, 18), 12, MUTED)
	for pirate in game.sector.pirates:
		if (
			not is_instance_valid(pirate)
			or pirate.dead
			or game.camera.is_position_behind(pirate.position)
		):
			continue
		var pos: Vector2 = (
			game.camera.unproject_position(pirate.position + Vector3(0, 0, -4))
			* Vector2(1600, 1000)
			/ size
		)
		if pos.x > 380 and pos.x < 1530 and pos.y > 190 and pos.y < 790:
			ink(pirate.display_name.to_upper(), pos + Vector2(-37, -12), 11, MeshKit.RED)
			draw_rect(Rect2(pos + Vector2(-35, -4), Vector2(80, 3)), Color("372928"))
			draw_rect(
				Rect2(pos + Vector2(-35, -4), Vector2(80 * pirate.hull / pirate.max_hull, 3)),
				MeshKit.RED
			)
	if is_instance_valid(game.interaction_target):
		var target: SpaceEntity = game.interaction_target
		var p: Vector2 = (
			game.camera.unproject_position(target.position) * Vector2(1600, 1000) / size
		)
		var r := 35.0
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			line(p + corner * r, p + corner * r - Vector2(corner.x * 12, 0), target.contact_color)
			line(p + corner * r, p + corner * r - Vector2(0, corner.y * 12), target.contact_color)


func draw_radar() -> void:
	var center := Vector2(1450, 844)
	draw_circle(center, 98, Color(0.03, 0.07, 0.095, 0.85))
	for r in [32, 65, 98]:
		draw_arc(center, r, 0, TAU, 80, LINE, 1, true)
	line(center + Vector2(-98, 0), center + Vector2(98, 0))
	line(center + Vector2(0, -98), center + Vector2(0, 98))
	var sweep := Vector2(cos(time * 0.4), sin(time * 0.4))
	line(center, center + sweep * 98, Color(CYAN, 0.3))
	for contact in game.sector.contacts:
		if (
			not is_instance_valid(contact)
			or not contact.available
			or (contact is Ship and contact.dead)
		):
			continue
		var delta: Vector3 = contact.position - game.player.position
		var point := Vector2(delta.x, delta.z) * 0.63
		if point.length() > 91:
			point = point.normalized() * 91
		draw_circle(
			center + point, 2.5 if contact.category != "station" else 4, contact.contact_color
		)
	var heading := Vector2(-sin(game.player.rotation.y), -cos(game.player.rotation.y))
	draw_colored_polygon(
		PackedVector2Array(
			[
				center + heading * 8,
				center + heading.rotated(2.4) * 6,
				center + heading.rotated(-2.4) * 6
			]
		),
		WHITE
	)
	ink("LOCAL TELEMETRY", Vector2(1388, 960), 11, MUTED)
	ink("N", center + Vector2(-4, -80), 11, MUTED)


func draw_dock() -> void:
	topbar("BERTH 04  /  DOCKED")
	panel(Rect2(876, 98, 724, 902), 0.97)
	ink(game.sector.station.display_name.to_upper(), Vector2(926, 177), 15, AMBER)
	ink("A light in the belt.", Vector2(926, 238), 51, WHITE, display)
	ink("Hull repaired. Shields restored. Crew accounted for.", Vector2(926, 279), 18, CYAN)
	ink(
		"CHECKPOINT SAVED" if game.save_ok else "SAVE FAILED — CHECK DISK SPACE",
		Vector2(926, 307),
		12,
		MUTED if game.save_ok else MeshKit.RED
	)
	ink("SHIPYARD  /  FIT YOUR NEXT CHAPTER", Vector2(926, 528), 13, MUTED)
	ink(
		"Drives: speed   ·   Rails: damage   ·   Shielding: durability",
		Vector2(926, 841),
		15,
		MUTED
	)
	panel(Rect2(44, 777, 624, 159), 0.88)
	ink(
		"LOCAL DISPATCH" if game.expedition.network.current > 0 else "MERIDIAN DISPATCH",
		Vector2(69, 814),
		13,
		AMBER
	)
	var dialog: Array = [
		[
			"Freight from the wreck. Ferrite from the rocks.",
			"Bring us both, and we'll help you get home."
		],
		[
			"The Choir is blocking our outbound corridor.",
			"Clear three raiders. We'll decode your beacon key."
		],
		[
			"The Asterion core is still out there, east of the Choir.",
			"Recover it, then wake the Janus beacon. Good luck."
		],
		[
			"Your signal made it through. The corridor is open.",
			"There will always be a berth for you here, Wayfarer."
		]
	]
	ink(
		(
			"Choose a commission, outfit your ship, then pick a lane."
			if game.expedition.network.current > 0
			else dialog[game.expedition.act][0]
		),
		Vector2(69, 855),
		20,
		WHITE
	)
	ink(
		(
			"Every station is a home port. Every system leaves a mark."
			if game.expedition.network.current > 0
			else dialog[game.expedition.act][1]
		),
		Vector2(69, 888),
		18,
		MUTED
	)


func draw_cargo() -> void:
	topbar("PHYSICAL CARGO BAY / INSPECTION")
	panel(Rect2(1093, 98, 507, 902), 0.96)
	var bay: CargoBay = game.expedition.bay
	ink("EVERY LOAD NEEDS A BERTH", Vector2(1140, 174), 14, AMBER)
	ink("Space is finite.", Vector2(1140, 232), 46, WHITE, display)
	ink(
		"%d / %d CELLS OCCUPIED" % [bay.occupied_cells(false), bay.cell_count()],
		Vector2(1140, 277),
		19,
		CYAN,
		bold
	)
	ink(
		"%d t / %d t structural limit" % [bay.mass(), game.expedition.capacity()],
		Vector2(1140, 310),
		18,
		WHITE
	)
	ink(
		"%d cells reserved for inbound craft" % (bay.occupied_cells() - bay.occupied_cells(false)),
		Vector2(1140, 343),
		16,
		AMBER
	)
	line(Vector2(1140, 366), Vector2(1515, 366))
	ink("Freight: 2 × 2 cells / 12 t", Vector2(1140, 400), 18, WHITE)
	ink("Ore pod: 1 cell / up to 4 t", Vector2(1140, 431), 18, WHITE)
	ink("Core: 2 × 1 cells / 8 t", Vector2(1140, 462), 18, WHITE)
	for deck in bay.decks():
		var origin := Vector2(1140 + deck * 129, 518)
		ink("DECK %d" % (deck + 1), origin - Vector2(0, 12), 12, MUTED)
		for x in CargoBay.WIDTH:
			for z in CargoBay.LENGTH:
				draw_rect(Rect2(origin + Vector2(x, z) * 25, Vector2(23, 23)), Color("21333d"))
		for item in bay.items:
			if int(item.deck) != deck:
				continue
			var tint := (
				CYAN if item.kind == "ore" else (Color("b2a2f2") if item.kind == "core" else AMBER)
			)
			draw_rect(
				Rect2(
					origin + Vector2(item.x, item.z) * 25,
					Vector2(item.w, item.h) * 25 - Vector2(2, 2)
				),
				tint.darkened(0.23)
			)
		for item in bay.reservations.values():
			if int(item.deck) != deck:
				continue
			draw_rect(
				Rect2(
					origin + Vector2(item.x, item.z) * 25,
					Vector2(item.w, item.h) * 25 - Vector2(2, 2)
				),
				AMBER,
				false,
				2
			)
	ink("A full deck can block a light load.", Vector2(1140, 687), 18, WHITE)
	ink("Inbound cargo reserves its exact footprint.", Vector2(1140, 719), 16, MUTED)
	ink("Sell or deliver at a station to clear cells.", Vector2(1140, 751), 16, MUTED)
	ink("Rack upgrades add a second or third deck.", Vector2(1140, 783), 16, MUTED)
	ink("WAYFARER / OPEN HOLD", Vector2(48, 944), 15, AMBER)
	ink(
		"Physical containers share the same manifest as this deck plan.",
		Vector2(48, 975),
		15,
		MUTED
	)


func draw_pause() -> void:
	draw_rect(Rect2(0, 0, 1600, 1000), Color(0.02, 0.04, 0.06, 0.86))
	panel(Rect2(520, 228, 560, 560))
	ink("THE BELT CAN WAIT", Vector2(654, 282), 13, AMBER)
	ink(
		"Ship systems paused" if game.pause_return == "interior" else "Flight suspended",
		Vector2(590, 340),
		45,
		WHITE,
		display
	)
	ink("Progress saves at stations and after each jump.", Vector2(626, 738), 16, MUTED)


func draw_settings() -> void:
	draw_rect(Rect2(0, 0, 1600, 1000), Color(0.02, 0.04, 0.06, 0.92))
	panel(Rect2(426, 206, 746, 650))
	ink("SHIP CONFIGURATION", Vector2(486, 267), 13, AMBER)
	ink("Make yourself at home.", Vector2(486, 321), 43, WHITE, display)
	var rows := [
		["AMBIENT MUSIC", "%d%%" % roundi(game.audio.music_volume * 100)],
		["SOUND EFFECTS", "%d%%" % roundi(game.audio.effects_volume * 100)],
		["CAMERA SHAKE", "ON" if game.shake_enabled else "OFF"],
		[
			"FULLSCREEN",
			(
				"ON"
				if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				else "OFF"
			)
		]
	]
	for i in rows.size():
		ink(rows[i][0], Vector2(486, 398 + i * 82), 17, WHITE)
		ink(rows[i][1], Vector2(901, 398 + i * 82), 18, CYAN)
		line(Vector2(486, 432 + i * 82), Vector2(1112, 432 + i * 82))


func draw_manual() -> void:
	draw_rect(Rect2(0, 0, 1600, 1000), Color(0.02, 0.04, 0.06, 0.97))
	ink("THE INDEPENDENT CAPTAIN'S", Vector2(100, 117), 15, AMBER)
	ink("Flight manual", Vector2(95, 196), 72, WHITE, display)
	line(Vector2(100, 226), Vector2(1500, 226))
	var entries := [
		["1 / 2 / 3 / 4", "Wayfarer / Mole 01 / Mole 02 / Latch"],
		["CLICK / DRAG", "Select one craft / box-select the fleet"],
		["DRONE → ROCK", "Click a deposit to mine and return pods"],
		["TUG → FREIGHT", "Crew attaches a tow and hauls it home"],
		["R / X", "Recall selected craft / hold position"],
		["G  /  3D MOVE", "Plot a course on the movement plane"],
		["SHIFT / WHEEL", "While plotting: set height; click confirms"],
		["RMB DRAG / F", "Orbit camera / reset the view"],
		["E / HOLD E", "Dispatch nearby job / dock or activate"],
		["C / TAB / M", "Cargo bay / interior / local chart"],
		["SPACE / SHIFT", "Survey pulse / mothership boost"],
		["ESCAPE", "Cancel draft course / pause flight"]
	]
	for i in entries.size():
		ink(entries[i][0], Vector2(103, 284 + i * 44), 17, CYAN, bold)
		ink(entries[i][1], Vector2(344, 284 + i * 44), 18, WHITE)
	ink("YOUR FIRST CONTRACT", Vector2(908, 291), 16, AMBER)
	var steps := [
		"01   Send Latch to tow 3 freight containers home.",
		"02   Send mining drones to deliver 24 t of ferrite.",
		"03   Recover all craft, then dock at Meridian.",
		"04   Sell cargo, turn in the contract, improve the ship."
	]
	for i in steps.size():
		ink(steps[i], Vector2(909, 337 + i * 49), 18, WHITE)
	ink("GOOD TO KNOW", Vector2(908, 583), 16, AMBER)
	var tips := [
		"Shift-drag adds craft. Click space orders the group.",
		"Freight needs a clear 2×2 footprint, not just spare mass.",
		"Each drone carries one 4 t pod, then returns for more.",
		"Cargo counts only after unloading at the Wayfarer.",
		"Hold the mothership still for the transfer approach.",
		"Latch carries Mara (pilot) and Ivo (rigger).",
		"R with Wayfarer selected recalls the entire fleet."
	]
	for i in tips.size():
		ink(tips[i], Vector2(909, 626 + i * 31), 16, MUTED)
	ink("J / STAR NETWORK     L / COMMISSIONS", Vector2(103, 861), 25, CYAN, display)
	ink(
		"Dock at any station to pick up jobs. Jump from a port or transit relay.",
		Vector2(103, 905),
		17,
		MUTED
	)


func draw_map() -> void:
	draw_rect(Rect2(0, 0, 1600, 1000), Color(0.02, 0.04, 0.06, 0.96))
	topbar("NAVIGATION CHART")
	ink(
		StarNetwork.NAMES[game.expedition.network.current].to_upper(),
		Vector2(74, 173),
		36,
		WHITE,
		display
	)
	ink("A SMALL CORNER OF A VERY BIG NOTHING", Vector2(76, 204), 12, MUTED)
	var origin := Vector2(771, 535)
	for x in range(120, 1510, 70):
		line(Vector2(x, 251), Vector2(x, 830), Color(LINE, 0.13))
	for y in range(270, 830, 70):
		line(Vector2(90, y), Vector2(1510, y), Color(LINE, 0.13))
	var points: Array = game.sector.chart_points()
	for point in points:
		var p := origin + Vector2(point[1].x, point[1].z) * 2.7
		draw_arc(p, 22, 0, TAU, 32, Color(point[2], 0.25), 1, true)
		diamond(p, 8, point[2])
		ink(point[0], p + Vector2(28, 5), 14, point[2])
	var player_pos := origin + Vector2(game.player.position.x, game.player.position.z) * 2.7
	draw_circle(player_pos, 5, WHITE)
	draw_arc(player_pos, 13 + sin(time * 3) * 2, 0, TAU, 32, WHITE, 1, true)
	ink("YOU / WF–07", player_pos + Vector2(22, -17), 13, WHITE)
	ink(
		(
			"CLICK A CONTACT TO SET COURSE  /  Escape or M to return"
			if game.map_return == "flight"
			else "Escape or M to return"
		),
		Vector2(77, 918),
		15,
		MUTED
	)


func draw_confirm() -> void:
	draw_rect(Rect2(0, 0, 1600, 1000), Color(0.02, 0.04, 0.06, 0.94))
	ink("A NEW CHAPTER", Vector2(542, 353), 14, AMBER)
	ink("Leave this voyage behind?", Vector2(542, 420), 48, WHITE, display)
	ink("Starting again replaces your saved checkpoint.", Vector2(542, 474), 21, WHITE)


func draw_ending() -> void:
	draw_rect(Rect2(0, 0, 1600, 1000), Color(0.02, 0.04, 0.06, 0.86))
	if game.mode == "won":
		diamond(Vector2(800, 234), 34, CYAN)
		ink("TRANSMISSION RECEIVED", Vector2(668, 310), 15, CYAN)
		ink("A home between stars.", Vector2(481, 413), 77, WHITE, display)
		ink(
			"The beacon answers. Beyond the static, a familiar voice.", Vector2(536, 478), 23, WHITE
		)
		ink("Seven souls aboard. Seven souls coming home.", Vector2(586, 518), 21, MUTED)
		ink(
			(
				"EXPEDITION COMPLETE   /   %02d:%02d   /   %d RAIDERS DEFEATED"
				% [
					int(game.expedition.play_seconds) / 60,
					int(game.expedition.play_seconds) % 60,
					game.expedition.kills
				]
			),
			Vector2(576, 598),
			14,
			AMBER
		)
	else:
		diamond(Vector2(800, 268), 27, MeshKit.RED)
		ink("SIGNAL LOST", Vector2(609, 390), 80, WHITE, display)
		ink("The crew's escape capsule reached a safe port.", Vector2(535, 462), 23, WHITE)
		ink("Retry restores your last station or jump checkpoint.", Vector2(619, 502), 18, MUTED)


func chart_goal_at(screen: Vector2) -> Variant:
	var point := screen * Vector2(1600, 1000) / size
	for entry in game.sector.chart_points():
		if entry[0].begins_with("ION"):
			continue
		var marker := Vector2(771, 535) + Vector2(entry[1].x, entry[1].z) * 2.7
		if point.distance_to(marker) < 26:
			return entry[1]
	return null


func toast_lines() -> Array[String]:
	var lines: Array[String] = []
	var current := ""
	for word in toast_text.split(" "):
		var next := current + ("" if current.is_empty() else " ") + word
		if (
			not current.is_empty()
			and regular.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x > 812
		):
			lines.append(current)
			current = word
		else:
			current = next
	lines.append(current)
	return lines


func toast_bounds() -> Rect2:
	return Rect2(410, 160 if game.mode == "flight" else 170, 860, 24 + 24 * toast_lines().size())

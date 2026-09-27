extends SceneTree
## Run with godot --headless --path . --script res://tests/test_suite.gd
## Tests deliberately use an isolated save path, never the player's checkpoint.
var passed: int = 0
var failures: Array[String] = []
var game: Node
const TEST_SAVE := "user://wayfarer-test-checkpoint.json"

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(description)
		push_error("FAIL: " + description)

func run() -> void:
	test_domain()
	test_geometry()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.save_path = TEST_SAVE
	game.capture_mode = "test"
	await process_frame
	game.new_game()
	check(game.mode == "manual", "New expedition teaches controls before flight")
	game.close_manual()
	await process_frame
	check(game.mode == "flight", "First manual returns to flight")
	await test_navigation()
	await test_spatial_flight()
	await test_drag_selection()
	game.player.stop()
	game.player.velocity = Vector3.ZERO
	var cache: SalvageCache
	for contact in game.sector.contacts:
		if contact is SalvageCache and not contact.is_relic:
			cache = contact
			break
	game.player.position = cache.position + Vector3(0, 0, 10)
	Input.action_press("interact")
	game.update_interaction(1.9)
	Input.action_release("interact")
	check(game.expedition.salvaged == 0 and cache.available, "Mothership proximity and held E cannot directly collect salvage")
	await test_operations(cache)
	for contact in game.sector.contacts:
		if contact is SalvageCache and not contact.is_relic and contact.available and game.expedition.salvaged < 3:
			game.expedition.add_salvage(contact.entity_id)
			contact.available = false
	var ore: OreAsteroid
	for contact in game.sector.contacts:
		if contact is OreAsteroid:
			ore = contact
			break
	for i in 5: game.expedition.add_ore(ore.extract(4, game.expedition))
	check(game.expedition.contract_ready(), "Freight plus ferrite completes the first contract")
	game.assign_crew("Gunnery")
	game.player.take_damage(100)
	game.player.model.rotation = Vector3(0.7, 0, 0.25)
	game.dock()
	check(game.player.model.rotation == Vector3.ZERO, "Docking levels flight pitch and bank for the berth")
	check(not game.player.navigator.active() and game.player.attack_target == null, "Docking clears flight and attack orders")
	check(game.player.hull == game.player.max_hull and game.player.shield == game.player.max_shield, "Dock repairs hull and shields for free")
	check(game.mode == "dock" and game.save_ok, "Dock writes a checkpoint")
	var saved := SaveStore.load_game(TEST_SAVE)
	check(saved != null and saved.ore_remaining[ore.entity_id] == 16, "Partial mining depletion survives disk serialization")
	check(saved.crew_role == "Gunnery", "Crew assignment survives disk serialization")
	var old_credits: int = game.expedition.credits
	game.sell_cargo()
	check(game.expedition.credits == old_credits + 624, "Station pays correct cargo price")
	check(game.expedition.contract_ready(), "Selling does not erase contract progress")
	game.complete_contract()
	check(game.expedition.act == 1 and game.sector.pirates.size() == 3, "First turn-in unlocks the combat act")
	game.buy_upgrade("weapon")
	check(game.expedition.upgrades.weapon == 1 and game.player.weapon_power > 33 and game.player.weapon_power <= 38, "Paid weapon upgrade and individually staffed security bonus apply")
	game.undock()
	check(not game.player.navigator.active() and game.player.velocity == Vector3.ZERO, "Undocking starts stationary without a stale course")
	var pirate: PirateShip = game.sector.pirates[0]
	game.player.position = pirate.position + Vector3(0, 0, 20)
	game.update_camera(1, true)
	click_at(game.camera.unproject_position(pirate.position))
	check(game.player.attack_target == pirate, "Clicking a live raider issues an attack order")
	game.player.command_move(game.player.position + Vector3(10, 0, 0))
	check(game.player.attack_target == null and game.player.navigator.active(), "A new course cancels pursuit and automatic fire")
	game.player.stop()
	check(not game.player.command_attack(game.player), "An attack order cannot target a friendly ship")
	pirate.activated = true
	var marker: Vector2 = game.ui.navigation_marker(pirate.position + Vector3(0, 0, -400)) * game.ui.size / Vector2(1600, 1000)
	check(not game.ui.blocks_world_input(marker), "Northern navigation markers stay outside the hostile banner")
	pirate.activated = false
	var hit = game.sector.segment_hit(pirate.position + Vector3(-20, 0.4, 0), pirate.position + Vector3(20, 0.4, 0), "player")
	check(hit == pirate, "Swept projectiles hit ships even across a long frame")
	var before_shield := pirate.shield
	pirate.take_damage(10)
	check(pirate.shield == before_shield - 10 and pirate.hull == pirate.max_hull, "Damage drains shields before hull")
	game.spawn_projectile(pirate.position + Vector3(0, 0.4, 6), Vector3.FORWARD, 1000, "player")
	for i in 12: await physics_frame
	check(pirate.dead and game.expedition.kills == 1, "Live projectile collision destroys enemy and records bounty")
	for other in game.sector.pirates:
		if not other.dead: other.take_damage(1000)
	check(game.expedition.kills == 3, "Three unique enemy deaths progress the contract")
	var active_projectiles := 0
	for child in game.sector.get_children():
		if child is Projectile: active_projectiles += 1
	for i in 135: await physics_frame
	var remaining_projectiles := 0
	for child in game.sector.get_children():
		if child is Projectile: remaining_projectiles += 1
	check(remaining_projectiles == 0, "Projectiles expire instead of accumulating")
	game.dock()
	game.complete_contract()
	check(game.expedition.act == 2, "Combat contract unlocks final act")
	game.undock()
	var relic: SalvageCache
	for contact in game.sector.contacts:
		if contact is SalvageCache and contact.is_relic: relic = contact
	game.expedition.bay.reserve("test_tug", "core", 8)
	game.expedition.receive_payload("test_tug", "core", 8, relic.entity_id)
	check(game.expedition.relic, "Final act allows the memory core to be recovered")
	game.player.position = Sector.GATE
	Input.action_press("interact")
	game.update_interaction(4)
	Input.action_release("interact")
	check(game.expedition.act == 3 and game.mode == "won", "Core and beacon interaction trigger the ending")
	check(SaveStore.load_game(TEST_SAVE).act == 3, "Victory is persisted")
	game.resume()
	check(game.mode == "flight", "Postgame exploration resumes")
	game.open_manual("pause")
	game.close_manual()
	check(game.mode == "pause", "Pause manual returns to pause")
	game.return_to_title()
	game.open_manual("menu")
	game.close_manual()
	check(game.mode == "menu", "Title manual returns to title after a completed voyage")
	game.continue_game()
	check(not game.player.selected and not game.player.navigator.active(), "Checkpoint restoration resets selection and transient orders")
	check(game.expedition.act == 3 and game.crew_role == "Gunnery", "Continue restores campaign and saved crew")
	for screen in ["pause", "map", "interior", "settings", "manual", "dock"]:
		game.set_mode(screen)
		check(not game.player.enabled and game.sector.process_mode == Node.PROCESS_MODE_DISABLED, screen + " suspends simulation")
	game.set_mode("flight")
	game.player.take_damage(10000)
	check(game.mode == "lost", "Lethal player damage enters recoverable loss screen")
	game.retry()
	check(game.mode == "flight" and not game.player.dead and game.player.hull == game.player.max_hull, "Retry restores a live, repaired checkpoint")
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	DirAccess.remove_absolute(TEST_SAVE)
	print("WAYFARER TESTS: %d passed, %d failed" % [passed, failures.size()])
	for failure in failures: print("  FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)

func click_at(point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		mouse_button_at(point, button, pressed)

func mouse_button_at(point: Vector2, button: MouseButton, pressed: bool, shift: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	event.shift_pressed = shift
	root.push_input(event, true)

func drag_between(start: Vector2, finish: Vector2, additive: bool = false) -> void:
	mouse_button_at(start, MOUSE_BUTTON_LEFT, true, additive)
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	motion.relative = finish - start
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.shift_pressed = additive
	root.push_input(motion, true)
	mouse_button_at(finish, MOUSE_BUTTON_LEFT, false, additive)

func test_drag_selection() -> void:
	game.select_unit(game.player)
	game.player.position = Vector3(0, 0, 5)
	game.player.velocity = Vector3.ZERO
	game.player.command_move(Vector3(-25, 0, 5))
	var mother_course: Vector3 = game.player.navigator.destination
	for unit in game.fleet.craft: unit.launch()
	var first: SupportCraft = game.fleet.craft[0]
	var second: SupportCraft = game.fleet.craft[1]
	var tug: SupportCraft = game.fleet.craft[2]
	first.position = Vector3(-8, 12, 5)
	second.position = Vector3(8, 12, 5)
	tug.position = Vector3(13, 0, 19)
	game.tactical_camera.reset()
	game.update_camera(1, true)
	game.ui.toast_time = 0
	var a: Vector2 = game.camera.unproject_position(first.position)
	var b: Vector2 = game.camera.unproject_position(second.position)
	var start := a.min(b) - Vector2(8, 8)
	var finish := a.max(b) + Vector2(8, 8)
	mouse_button_at(start, MOUSE_BUTTON_LEFT, true)
	check(game.selection_box.active and game.player.navigator.destination == mother_course, "Press begins selection without issuing an accidental move")
	press_key(KEY_ESCAPE)
	mouse_button_at(finish, MOUSE_BUTTON_LEFT, false)
	check(game.mode == "flight" and not game.selection_box.active and game.player.navigator.destination == mother_course, "Escape cancels selection and its delayed release without pausing or ordering")
	drag_between(finish, start)
	check(game.selected_units().size() == 2 and first.selected and second.selected and not game.player.selected and not tug.selected, "Reverse drag selects precisely the two enclosed friendly drones")
	check(game.player.navigator.destination == mother_course and not first.navigator.active() and not second.navigator.active(), "Box selection preserves existing orders and issues no movement")
	var destination := Vector3(14, 12, 22)
	click_at(game.camera.unproject_position(destination))
	check(first.navigator.active() and second.navigator.active() and first.navigator.destination.distance_to(second.navigator.destination) >= 7.9, "Group click assigns distinct arrival berths to both drones")
	check(game.player.navigator.destination == mother_course, "Group movement leaves unselected craft orders intact")
	press_key(KEY_X)
	check(not first.navigator.active() and not second.navigator.active() and game.player.navigator.active(), "Stop affects every selected craft and leaves unselected craft running")
	press_key(KEY_G)
	game.move_preview.adjust_height(9)
	var plotted: Vector3 = game.move_preview.destination()
	click_at(game.camera.unproject_position(destination))
	check(not game.move_preview.active and is_equal_approx(first.navigator.destination.y, plotted.y) and is_equal_approx(second.navigator.destination.y, plotted.y), "One confirmed 3D draft applies its altitude to the whole group")
	game.move_selected(Vector3(400, 12, 0))
	check(first.navigator.destination.distance_to(second.navigator.destination) >= 7.9 and Vector2(first.navigator.destination.x, first.navigator.destination.z).length() <= FlightNavigator.BELT_RADIUS and Vector2(second.navigator.destination.x, second.navigator.destination.z).length() <= FlightNavigator.BELT_RADIUS, "Out-of-bounds group orders retain distinct arrival berths inside the sector")
	var first_course: Vector3 = first.navigator.destination
	var empty_start: Vector2 = Vector2(880, 660) * game.ui.size / Vector2(1600, 1000)
	drag_between(empty_start, empty_start + Vector2(30, 25), true)
	check(game.selected_units().size() == 2, "Shift-drag over empty space preserves the selection")
	drag_between(empty_start, empty_start + Vector2(30, 25))
	check(game.selected_units().is_empty() and first.navigator.destination == first_course, "Empty box clears selection without replacing live courses")
	drag_between(start, finish)
	var mother_screen: Vector2 = game.camera.unproject_position(game.player.position)
	drag_between(mother_screen - Vector2(7, 7), mother_screen + Vector2(7, 7), true)
	check(game.selected_units().size() == 3 and game.player.selected and first.selected and second.selected, "Shift-drag adds enclosed craft to an existing selection")
	var tug_screen: Vector2 = game.camera.unproject_position(tug.position)
	mouse_button_at(tug_screen, MOUSE_BUTTON_LEFT, true, true)
	mouse_button_at(tug_screen + Vector2(1, 1), MOUSE_BUTTON_LEFT, false, true)
	check(game.selected_units().size() == 4, "Shift-click adds a friendly craft despite sub-threshold pointer jitter")
	press_key(KEY_2)
	check(game.selected_units().size() == 1 and first.selected, "Fleet hotkey replaces group selection with one craft")
	game.ui.toast_time = 0
	var hud_point: Vector2 = Vector2(90, 190) * game.ui.size / Vector2(1600, 1000)
	drag_between(hud_point, finish)
	check(game.selected_units().size() == 1 and not game.selection_box.active and first.navigator.destination == first_course, "A drag starting on the HUD cannot select or order world craft")
	mouse_button_at(start, MOUSE_BUTTON_RIGHT, true)
	drag_between(start, finish)
	mouse_button_at(start, MOUSE_BUTTON_RIGHT, false)
	check(not game.selection_box.active and game.selected_units().size() == 1, "An active orbit gesture cannot start box selection")
	drag_between(start, finish)
	press_key(KEY_R)
	check(first.phase == SupportCraft.Phase.RETURNING and second.phase == SupportCraft.Phase.RETURNING and tug.phase == SupportCraft.Phase.IDLE, "Group recall returns selected workers only")
	mouse_button_at(start, MOUSE_BUTTON_LEFT, true)
	game.set_mode("map")
	mouse_button_at(finish, MOUSE_BUTTON_LEFT, false)
	check(not game.selection_box.active and game.mode == "map", "Management transition discards an unfinished selection gesture")
	game.set_mode("flight")
	await process_frame
	mouse_button_at(start, MOUSE_BUTTON_LEFT, true)
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	mouse_button_at(finish, MOUSE_BUTTON_LEFT, false)
	check(not game.selection_box.active, "Window focus loss cancels a pending drag")
	first.visible = false
	second.position = game.camera.position + game.camera.global_basis.z * 20
	tug.dead = true
	game.select_rectangle(root.get_visible_rect())
	check(game.selected_units().size() == 1 and game.player.selected, "Box selection excludes hidden, behind-camera and destroyed craft")
	tug.dead = false
	first.visible = true
	var rock: OreAsteroid = game.sector.obstacles[0]
	game.player.position = rock.position + Vector3(0, 0, 24)
	for index in 3:
		var unit: SupportCraft = game.fleet.craft[index]
		unit.stop()
		unit.position = game.player.position + Vector3(index * 3, 2, 0)
		game.select_unit(unit, index > 0)
	game.update_camera(1, true)
	game.ui.toast_time = 0
	click_at(game.camera.unproject_position(rock.position))
	check(first.work_target is OreAsteroid and second.work_target == first.work_target and tug.phase == SupportCraft.Phase.IDLE, "A group resource click assigns both compatible miners and leaves the tug idle")
	# Restore the fixture without extracting or delivering any resources.
	for unit in game.fleet.craft:
		unit.stop()
		unit.phase = SupportCraft.Phase.DOCKED
		unit.visible = false
		unit.velocity = Vector3.ZERO
	game.select_unit(game.player)
	game.player.stop()
	game.player.velocity = Vector3.ZERO
	game.player.position = Vector3(0, 0, 5)
	game.update_camera(1, true)

func test_navigation() -> void:
	if DisplayServer.get_name() == "headless": root.notify_mouse_entered()
	var initial: Vector3 = game.player.position
	var destination := initial + Vector3(18, 0, 0)
	game.update_camera(1, true)
	click_at(game.camera.unproject_position(destination))
	check(not game.player.navigator.active(), "An empty-space click needs a selected ship")
	click_at(game.camera.unproject_position(initial))
	check(game.player.selected and not game.player.navigator.active(), "Clicking the ship selects it without moving or firing")
	check(not InputMap.has_action("forward") and not InputMap.has_action("fire"), "Direct WASD and mouse-fire bindings are removed")
	click_at(game.camera.unproject_position(destination))
	check(game.player.navigator.active() and game.player.navigator.destination.distance_to(destination) < 0.1, "A world click produces the projected destination")
	var course: Vector3 = game.player.navigator.destination
	click_at(Vector2(90, 190) * game.ui.size / Vector2(1600, 1000))
	check(game.player.navigator.destination == course, "Clicking a HUD panel cannot replace the course")
	click_at(Vector2(1470, 133) * game.ui.size / Vector2(1600, 1000))
	check(game.mode == "map" and game.player.navigator.destination == course, "Chart button consumes its click before world orders")
	for i in 10: await physics_frame
	check(game.player.position == initial, "Management screens freeze an active route")
	game.set_mode("flight")
	for i in 30: await physics_frame
	check(game.player.position.x > initial.x + 0.5, "Selected ship follows a course without holding a movement key")
	check(game.player.energy == 100, "Ordinary flight cannot strand the player")
	Input.action_press("boost")
	for i in 20: await physics_frame
	Input.action_release("boost")
	check(game.player.energy < 100, "Boost accelerates the route using rechargeable energy")
	for i in 230: await physics_frame
	check(not game.player.navigator.active() and game.player.position.distance_to(destination) < 0.5 and game.player.velocity.length() < 0.01, "Autopilot brakes and holds at its destination")
	game.update_camera(1, true)
	click_at(game.camera.unproject_position(initial), MOUSE_BUTTON_RIGHT)
	check(game.player.navigator.active(), "Right click also accepts a course for the selected ship")
	var stop_event := InputEventKey.new()
	stop_event.physical_keycode = KEY_X
	stop_event.pressed = true
	root.push_input(stop_event)
	stop_event.pressed = false
	root.push_input(stop_event)
	check(not game.player.navigator.active(), "X cancels the order")
	var planner: FlightNavigator = game.player.navigator
	var start := Sector.MINE + Vector3(-35, 0, 0)
	var finish := Sector.MINE + Vector3(35, 0, 0)
	check(planner.plan(start, finish) and planner.route.size() > 1, "Asteroid crossing creates a detour")
	var previous := start
	var clear := true
	for point in planner.route:
		clear = clear and planner.clear_segment(previous, point)
		previous = point
	check(clear, "Every planned route segment clears expanded obstacle radii")
	check(planner.plan(start, game.sector.obstacles[0].position) and planner.clear_segment(planner.destination, planner.destination), "An order inside an asteroid ends at a safe berth")
	check(planner.plan(initial, Vector3(1000, 0, 1000)) and planner.destination.length() <= 258.01, "Orders outside the belt clamp to reachable space")
	check(not planner.plan(initial, Vector3(NAN, 0, 0)), "Invalid navigation coordinates are rejected")
	# Actual boosted steering through rocks, including momentum, must honor the route.
	game.player.stop()
	game.player.position = start
	game.player.velocity = Vector3.ZERO
	game.player.command_move(finish)
	var shield_before: float = game.player.shield
	Input.action_press("boost")
	Engine.time_scale = 4
	for i in 360:
		await physics_frame
		if not game.player.navigator.active(): break
	Input.action_release("boost")
	Engine.time_scale = 1
	check(not game.player.navigator.active() and game.player.position.distance_to(finish) < 0.5, "Boosted autopilot traverses the asteroid field and arrives")
	check(game.player.shield >= shield_before and game.player.hull == game.player.max_hull, "Obstacle detour avoids collision damage")
	game.player.stop()
	game.player.velocity = Vector3.ZERO
	game.update_camera(1, true)
	var marker: Vector2 = game.ui.navigation_marker(game.player.position + Vector3(40, 0, 400)) * game.ui.size / Vector2(1600, 1000)
	check(not game.ui.blocks_world_input(marker), "Southern navigation markers stay outside the radar")
	# The clicked freight remains the interaction target even if a neighbor is nearer.
	var freight: SpaceEntity
	for contact in game.sector.contacts:
		if contact.entity_id == "freight_1": freight = contact
	game.player.position = initial
	game.approach_contact(freight)
	game.player.position = game.player.navigator.destination
	game.update_interaction(0)
	check(game.sector.nearest_interactable(game.player.position) != freight and game.interaction_target == freight, "Approaching freight preserves the clicked contact for E")
	game.player.stop()
	game.interaction_focus = null
	# A blocked shot at close range must navigate to the far side, not a near-side berth.
	var rock := SpaceEntity.new()
	rock.position = Vector3(200, 0, -100)
	rock.radius = 3
	game.sector.add_child(rock)
	game.sector.obstacles.append(rock)
	var enemy := Ship.new()
	enemy.faction = "hostile"
	enemy.position = rock.position + Vector3(7, 0, 0)
	game.sector.add_child(enemy)
	game.player.position = rock.position + Vector3(-8, 0, 0)
	game.player.velocity = Vector3.ZERO
	game.player.command_attack(enemy)
	game.player._physics_process(0.01)
	check(game.player.navigator.active() and game.player.navigator.destination.x > rock.position.x and game.player.navigator.route.size() > 1, "Obstructed close-range pursuit routes around the rock toward the target")
	game.player.stop()
	enemy.position = rock.position + Vector3(5, 0, 0)
	game.player.position = rock.position + Vector3(15, 0, 0)
	game.player.velocity = Vector3.ZERO
	game.player.cooldown = 0
	game.player.command_attack(enemy)
	game.player._physics_process(0.01)
	check(game.player.cooldown > 0 and not game.player.navigator.active(), "A clear shot near a rock uses projectile clearance, not padded hull clearance")
	game.player.stop()
	game.sector.obstacles.erase(rock)
	rock.free()
	enemy.free()
	game.player.position = initial
	game.player.velocity = Vector3.ZERO

func press_key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = pressed
		root.push_input(event, true)

func test_spatial_flight() -> void:
	var initial := Vector3(-10, 12, 10)
	game.player.position = initial
	game.player.velocity = Vector3.ZERO
	game.player.stop()
	game.player.selected = false
	game.update_camera(1, true)
	click_at(game.camera.unproject_position(initial))
	check(game.player.selected, "Ray selection finds the ship above the belt plane")
	check(game.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Flight uses a perspective camera")
	var foreground := PirateShip.new()
	game.sector.add_child(foreground)
	foreground.position = initial + (game.camera.position - initial).normalized() * 14
	game.sector.contacts.append(foreground)
	click_at(game.camera.unproject_position(initial))
	check(game.player.attack_target == foreground, "A foreground enemy wins ray picking over the ship behind it")
	foreground.position = game.camera.position + game.camera.global_basis.z * 10
	check(game.camera.is_position_behind(foreground.position) and WorldPicker.hit_distance(game.camera, game.camera.unproject_position(foreground.position), foreground) == INF, "A contact behind the camera cannot be selected through mirrored projection")
	game.player.stop()
	game.sector.contacts.erase(foreground)
	foreground.free()
	var live_course := initial + Vector3(25, 0, -15)
	game.player.command_move(live_course)
	press_key(KEY_G)
	check(game.move_preview.active and game.player.navigator.destination == live_course, "G drafts a 3D course without replacing the live order")
	check(not game.player.boost_permitted, "Altitude placement suppresses Shift boost")
	var draft: MoveOrderPreview = game.move_preview
	var horizontal := initial + Vector3(16, 0, -6)
	var mouse: Vector2 = game.camera.unproject_position(horizontal)
	draft.update(game.camera, mouse, false)
	check(draft.base.distance_to(horizontal) < 0.01, "Movement-plane projection works at the ship's altitude")
	draft.update(game.camera, mouse, true)
	draft.update(game.camera, mouse + Vector2(0, -75), true)
	check(draft.altitude > initial.y + 3 and draft.base.distance_to(horizontal) < 0.01, "Shift raises height while locking the horizontal footprint")
	var raised := draft.destination()
	draft.update(game.camera, mouse + Vector2(0, -75), false)
	draft.update(game.camera, mouse + Vector2(0, -75), false)
	check(draft.destination().distance_to(raised) < 0.01, "Releasing Shift preserves the full 3D destination")
	draft.adjust_height(-200)
	check(draft.altitude == -60, "Draft altitude clamps at the lower flight boundary")
	draft.adjust_height(400)
	check(draft.altitude == 60, "Draft altitude clamps at the upper flight boundary")
	draft.update(game.camera, mouse, true)
	draft.update(game.camera, mouse + Vector2(0, -1000), true)
	draft.adjust_height(200)
	draft.update(game.camera, mouse + Vector2(0, -999), true)
	check(draft.altitude < 60, "Clamped height changes reverse immediately without hidden wheel or drag overshoot")
	draft.update(game.camera, mouse + Vector2(0, -999), false)
	draft.altitude = 28
	var confirmed := draft.destination()
	click_at(Vector2(1100, 550) * game.ui.size / Vector2(1600, 1000))
	check(not draft.active and game.player.navigator.destination.distance_to(confirmed) < 0.01, "Click confirms the preview's altitude, not a flat ground projection")
	press_key(KEY_G)
	press_key(KEY_ESCAPE)
	check(not draft.active and game.mode == "flight" and game.player.navigator.destination == confirmed, "Escape cancels only the draft and retains the previous order")
	var click: Vector2 = Vector2(1050, 560) * game.ui.size / Vector2(1600, 1000)
	press_key(KEY_G)
	mouse_button_at(click, MOUSE_BUTTON_RIGHT, true)
	click_at(click + Vector2(20, 0))
	check(draft.active and game.player.navigator.destination == confirmed, "An orbit gesture owns mouse clicks and cannot accidentally confirm a draft")
	mouse_button_at(click, MOUSE_BUTTON_MIDDLE, true)
	check(game.tactical_camera.drag_button == MOUSE_BUTTON_RIGHT, "A second orbit button cannot replace the active gesture")
	mouse_button_at(click, MOUSE_BUTTON_MIDDLE, false)
	press_key(KEY_ESCAPE)
	mouse_button_at(click, MOUSE_BUTTON_RIGHT, false)
	check(not draft.active and game.player.navigator.destination == confirmed, "Releasing a pending right click after Escape does not issue a move")
	press_key(KEY_G)
	mouse_button_at(click, MOUSE_BUTTON_RIGHT, true)
	press_key(KEY_X)
	mouse_button_at(click, MOUSE_BUTTON_RIGHT, false)
	check(not draft.active and not game.player.navigator.active(), "Releasing a pending right click after Stop cannot restart flight")
	game.player.command_move(confirmed)
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.position = click
	right.pressed = true
	root.push_input(right, true)
	var motion := InputEventMouseMotion.new()
	motion.position = click + Vector2(80, 30)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	root.push_input(motion, true)
	right.position = motion.position
	right.pressed = false
	root.push_input(right, true)
	game.update_camera(1, true)
	check(absf(game.tactical_camera.azimuth) > 0.1 and game.player.navigator.destination == confirmed, "Right dragging orbits without issuing an accidental move")
	check(WorldPicker.hit_distance(game.camera, game.camera.unproject_position(initial), game.player) < INF, "Ship picking works after orbiting the camera")
	press_key(KEY_F)
	game.update_camera(1, true)
	check(absf(game.tactical_camera.azimuth) < 0.01 and game.player.navigator.destination == confirmed, "F restores the tactical view without changing the order")
	press_key(KEY_G)
	game.set_mode("interior")
	check(not draft.active and game.tactical_camera.drag_button == MOUSE_BUTTON_NONE, "Management screens discard unfinished placement and orbit gestures")
	game.set_mode("flight")
	press_key(KEY_G)
	press_key(KEY_X)
	check(not draft.active and not game.player.navigator.active(), "Stop cancels both draft and committed routes")
	var planner: FlightNavigator = game.player.navigator
	var rock: SpaceEntity = game.sector.obstacles[0]
	var over := rock.position + Vector3(0, 18, 0)
	check(planner.plan(over + Vector3(-12, 0, 0), over + Vector3(12, 0, 0)) and planner.route.size() == 1, "A clear course above an asteroid stays direct")
	game.player.position = over
	game.sector.resolve_collision(game.player)
	check(game.player.position == over, "Flying over a rock is not flattened or pushed by a 2D collision")
	check(planner.plan(rock.position + Vector3(0, 20, 0), rock.position + Vector3(0, -20, 0)) and planner.route.size() > 1, "Vertical travel through a rock gets a spatial detour")
	check(planner.plan(initial, Vector3(0, 500, 0)) and planner.destination.y == 60, "Live navigation enforces the altitude ceiling")
	game.player.stop()
	game.player.position = initial
	game.player.rotation = Vector3.ZERO
	game.player.model.rotation = Vector3.ZERO
	game.player.velocity = Vector3.ZERO
	var finish := Vector3(16, 32, -14)
	game.player.command_move(finish)
	var bank_seen := false
	var pitch_seen := false
	Engine.time_scale = 4
	for frame in 360:
		await physics_frame
		bank_seen = bank_seen or absf(game.player.model.rotation.z) > 0.03
		pitch_seen = pitch_seen or game.player.model.rotation.x > 0.10
		if not game.player.navigator.active(): break
	for frame in 10: await physics_frame
	check(game.player.position.distance_to(finish) < 0.5 and game.player.velocity.length() < 0.01, "Actual 3D steering climbs and brakes at the full destination")
	check(bank_seen and pitch_seen, "The ship banks during a turn and pitches into a climb")
	var dive := Vector3(-10, -20, 10)
	game.player.command_move(dive)
	for frame in 420:
		await physics_frame
		if not game.player.navigator.active(): break
	check(game.player.position.distance_to(dive) < 0.5, "The ship can descend through and below the belt plane")
	Engine.time_scale = 1
	# Enemy chase and interactions use the same full 3D distances.
	var enemy := PirateShip.new()
	game.sector.add_child(enemy)
	enemy.position = Vector3(-100, 0, 20)
	enemy.target = game.player
	enemy.enabled = true
	game.player.position = Vector3(-100, 40, 20)
	enemy._physics_process(0.1)
	check(enemy.velocity.y > 0 and enemy.model.rotation.x > 0, "Raiders climb toward elevated targets")
	enemy.free()
	game.player.position = Sector.PORT + Vector3.UP * 45
	game.interaction_focus = null
	game.update_interaction(0)
	check(game.interaction_target == null, "A ship far above the station cannot interact through vertical distance")
	game.approach_contact(game.sector.station)
	check(game.player.navigator.destination.y < game.player.position.y and game.player.navigator.destination.distance_to(Sector.PORT) < 24, "Clicking a station from altitude plans a reachable 3D approach")
	game.player.stop()
	game.player.velocity = Vector3.ZERO
	game.player.position = Vector3(0, 0, 5)
	game.interaction_focus = null
	game.update_camera(1, true)

func test_domain() -> void:
	var model := Expedition.new()
	check(model.add_ore(-4) == 0 and model.ore == 0, "Negative collection cannot corrupt cargo")
	check(not model.add_salvage("negative", -3), "Negative freight is rejected")
	check(not model.turn_in(), "Incomplete contract cannot be turned in")
	check(not model.finish(), "Cannot skip to ending")
	check(not model.purchase("unknown"), "Unknown upgrade rejected")
	check(not model.purchase("weapon"), "Unaffordable purchase is atomic")
	check(model.credits == 200, "Rejected purchase does not spend credits")
	check(model.add_salvage("test", 12), "Cargo accepts salvage")
	check(not model.add_salvage("test", 12), "Duplicate salvage is rejected")
	check(model.add_ore(1000) == 64, "Freight footprint limits ore before the mass ceiling")
	check(model.add_ore(4) == 0, "Full cargo accepts no ore")
	check(not model.add_salvage("other", 12), "Full cargo cannot swallow a freight crate")
	check(model.cargo_used() == 76 and model.bay.occupied_cells() == 20, "Cargo respects both physical cell space and mass")
	model.credits = 5000
	check(model.purchase("cargo") and model.capacity() == 120, "Cargo upgrade expands capacity")
	check(model.purchase("cargo") and model.capacity() == 180, "Second cargo upgrade applies")
	check(not model.purchase("cargo"), "Maxed upgrade rejected")
	var earned := model.sell_cargo()
	check(earned == 656 and model.cargo_used() == 0 and model.bay.items.is_empty(), "Cargo sale value and physical clearing are atomic")
	model.record_kill("p1")
	model.record_kill("p1")
	check(model.kills == 1, "Duplicate kill cannot award a second bounty")
	for field in ["credits", "ore", "scrap", "mined", "salvaged", "kills", "act", "play_seconds"]:
		var invalid := model.snapshot()
		invalid[field] = -1
		check(Expedition.from_snapshot(invalid) == null, "Save rejects negative " + field)
	for field in ["version", "act", "upgrades", "consumed", "ore_remaining", "crew_role", "play_seconds"]:
		var invalid := model.snapshot()
		invalid[field] = []
		check(Expedition.from_snapshot(invalid) == null, "Save rejects wrong type for " + field)
	var invalid_level := model.snapshot()
	invalid_level.upgrades.weapon = []
	check(Expedition.from_snapshot(invalid_level) == null, "Save rejects malformed upgrade level")
	check(Expedition.from_snapshot({"version": 99}) == null, "Future save versions are rejected safely")
	check(SaveStore.load_game("user://missing-wayfarer-test.json") == null, "Missing save is safe")
	var bay := CargoBay.new()
	check(bay.reserve("tug", "salvage", 12) and bay.occupied_cells() == 4, "Inbound freight reserves four cells")
	check(bay.reserve("drone", "ore", 4) and bay.occupied_cells() == 5, "Concurrent work craft reserve distinct cells")
	check(bay.receive("tug", "freight") and not bay.receive("tug", "freight"), "Delivery consumes its reservation exactly once")
	bay.release("drone")
	check(bay.occupied_cells() == 4 and bay.mass() == 12, "Cancelling an empty worker releases only its reservation")
	var full := CargoBay.new()
	for i in 4: check(full.store("box_%d" % i, "salvage", 12), "A freight footprint fits its allotted cells")
	check(not full.store("box_5", "salvage", 12) and full.mass() == 48, "Insufficient contiguous footprint blocks freight despite spare mass and four free cells")
	var malformed := bay.snapshot()
	malformed.append(malformed[0].duplicate())
	check(not CargoBay.new().restore(malformed), "Save rejects overlapping or duplicate physical cargo")
	var valid := Expedition.new()
	valid.add_salvage("saved_freight")
	valid.add_ore(7)
	var restored := Expedition.from_snapshot(valid.snapshot())
	check(restored != null and restored.bay.items.size() == 3 and restored.bay.mass() == 19, "Version two preserves crate footprints and partial pods")
	var mismatch := valid.snapshot()
	mismatch.ore = 0
	check(Expedition.from_snapshot(mismatch) == null, "Save rejects numeric cargo inconsistent with physical manifest")
	var legacy := valid.snapshot()
	legacy.version = 1
	legacy.erase("bay")
	legacy.erase("cargo_serial")
	check(Expedition.from_snapshot(legacy).bay.mass() == 19, "Legacy cargo migrates into physical slots")
	var guarded := Expedition.new()
	guarded.bay.reserve("worker", "ore", 4)
	check(not guarded.receive_payload("worker", "salvage", 4, "freight") and guarded.salvaged == 0, "Payload kind must match the reserved footprint before mutation")
	check(not guarded.receive_payload("worker", "ore", -1, "ore_source") and guarded.ore == 0, "Negative delivery cannot corrupt counters")
	check(not guarded.receive_payload("worker", "ore", 4, ""), "A delivery needs an identified source")
	check(guarded.bay.reservations.has("worker") and guarded.bay.items.is_empty(), "Rejected deliveries preserve reservations and the manifest")
	check(not guarded.bay.store("invalid", "unknown", 4), "Unknown physical cargo types are rejected")
	var freight_bay := CargoBay.new()
	freight_bay.reserve("crew", "salvage", 12)
	check(not freight_bay.receive("crew", "partial", 4), "A sealed freight container cannot arrive as a fractional load")

func wait_for_condition(predicate: Callable, seconds: float = 45) -> bool:
	for i in int(seconds * 60 / Engine.time_scale):
		if predicate.call(): return true
		await physics_frame
	return predicate.call()

func test_operations(cache: SalvageCache) -> void:
	Engine.time_scale = 4
	var tug: SalvageTug = game.fleet.craft[2]
	game.select_fleet_unit(3)
	check(tug.selected and not game.player.selected and tug.phase == SupportCraft.Phase.IDLE, "Selecting the tug launches it and transfers command")
	check(game.fleet.crew_away() == 2, "Exactly two crew leave aboard the salvage vessel")
	check(tug.command_work(cache), "Tug accepts a freight recovery order")
	check(game.expedition.bay.reservations.has(tug.entity_id), "Tug reserves an actual cargo footprint before departure")
	check(await wait_for_condition(func(): return tug.payload_amount > 0), "Crew reaches freight and secures it after work time")
	check(game.expedition.salvaged == 0 and cache.in_tow and cache.visible, "Secured freight remains visible outside the ship and is not credited early")
	var before := cache.position
	for i in 20: await physics_frame
	check(cache.position.distance_to(before) > 0.1 and tug.cable.visible, "Freight moves behind the tug with a physical tow cable")
	tug.stop()
	check(tug.payload_amount == 12 and game.expedition.bay.reservations.has(tug.entity_id), "Stop retains the tow and reserved bay space")
	tug.recall()
	check(await wait_for_condition(func(): return tug.phase == SupportCraft.Phase.DOCKED), "Recalled salvage vessel returns and unloads")
	check(game.expedition.salvaged == 1 and not cache.visible and game.expedition.bay.mass() == 12, "Only completed unloading stores physical freight and awards progress")
	check(game.fleet.crew_away() == 0, "Both salvage crew return with the vessel")
	var drone: MiningDrone = game.fleet.craft[0]
	var ore: OreAsteroid = game.sector.obstacles[0]
	game.player.position = ore.position + Vector3(0, 7, 18)
	game.select_fleet_unit(1)
	check(drone.command_work(ore), "Mining drone accepts an ore cutting order")
	check(await wait_for_condition(func(): return drone.payload_amount == 4), "Drone travels and extracts one bounded ore pod")
	check(game.expedition.ore == 0 and ore.remaining == 36, "Extracted ore is in transit, not magically in the mothership")
	drone.stop()
	check(drone.payload_amount == 4, "Stopping a loaded drone preserves its pod")
	game.dock()
	check(game.mode == "flight", "Docking waits for deployed craft instead of discarding their payloads")
	check(await wait_for_condition(func(): return game.fleet.all_aboard()), "Recall brings loaded drone home and unloads it")
	check(game.expedition.ore == 4 and game.expedition.mined == 4, "Ore counts toward the contract only after delivery")
	game.player.position = Vector3(258, 60, 0)
	game.select_fleet_unit(1)
	check(drone.staging_point().is_equal_approx(FlightNavigator.constrain(drone.staging_point())), "Recovery point stays inside the flight cylinder at both boundaries")
	drone.recall()
	check(await wait_for_condition(func(): return drone.phase == SupportCraft.Phase.DOCKED, 15), "Craft can recover at the altitude ceiling and sector rim")
	game.select_fleet_unit(1)
	game.move_preview.begin(drone.position)
	press_key(KEY_R)
	check(not game.move_preview.active and drone.phase == SupportCraft.Phase.RETURNING, "Recall cancels an unfinished 3D draft without replacing the return order")
	await wait_for_condition(func(): return drone.phase == SupportCraft.Phase.DOCKED, 15)
	game.select_fleet_unit(0)
	game.player.command_move(Vector3(220, 40, 0))
	press_key(KEY_R)
	check(not game.player.navigator.active(), "Fleet recall orders the mothership to hold for recovery")
	game.player.position = Sector.PORT + Vector3(-12, 0, 13)
	game.select_fleet_unit(1)
	drone.position = game.player.position + Vector3(0, 12, 0)
	game.interaction_focus = game.sector.station
	Input.action_press("interact")
	check(await wait_for_condition(func(): return game.mode == "dock", 25), "Holding E throughout recovery lets unloading finish and then docks")
	Input.action_release("interact")
	check(game.fleet.all_aboard(), "Dock checkpoint accounts for every work craft")
	game.undock()
	# The remaining campaign fixture uses 24 total ore, including the delivered pod.
	game.select_fleet_unit(0)
	Engine.time_scale = 1

func test_geometry() -> void:
	var parts := Node3D.new()
	MeshKit.box(parts, Vector3.ZERO, Vector3(2, 1, 3), MeshKit.STEEL)
	MeshKit.cylinder(parts, Vector3(2, 0, 0), 1, 2, MeshKit.STEEL)
	var before := 0
	for child in parts.get_children(): before += child.mesh.get_faces().size()
	MeshKit.bake(parts)
	var after := 0
	for child in parts.get_children(): after += child.mesh.get_faces().size()
	check(before == after, "Baking mixed generated/primitive meshes preserves all faces")
	check(parts.get_child_count() == 1, "Static geometry batches into one surface per material")
	parts.free()

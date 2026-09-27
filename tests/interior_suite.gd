extends SceneTree
## Behavioral tests for individual crew, survival loops, checkpoint migration and deck input.
var passed := 0
var failures: Array[String] = []
var game: Node
const SAVE := "user://wayfarer-interior-test.json"

func _initialize() -> void: call_deferred("run")

func check(ok: bool, description: String) -> void:
	if ok: passed += 1
	else:
		failures.append(description)
		push_error("FAIL: " + description)

func run() -> void:
	test_crew()
	test_resources()
	test_fabrication()
	test_persistence()
	await test_deck()
	print("INTERIOR TESTS: %d passed, %d failed" % [passed, failures.size()])
	for failure in failures: print("  FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)

func test_crew() -> void:
	var state := InteriorState.new()
	check(state.crew.size() == 7 and state.member("mara").profession == "Captain" and state.member("nia").profession == "Botanist", "Seven named specialists have stable identities and requested professions")
	check(InteriorState.STATIONS.size() == 9, "All nine reference sections have domain stations")
	check(state.assign("mara", "hydroponics") and state.staffing("bridge") == 0 and state.member("mara").travel_remaining > 0, "Assignment removes the previous station contribution immediately and begins travel")
	check(not state.assign("mara", "quarters") and state.member("mara").station == "hydroponics" and state.member("mara").previous_station == "bridge", "Walking crew keep their current route until arrival instead of teleporting on retarget")
	state.advance(6)
	check(is_equal_approx(state.staffing("hydroponics"), 1.6), "Arriving at another profession supplies 60 percent cross-trained staffing")
	check(not state.assign("ivo", "hydroponics") and state.member("ivo").station == "engineering", "Full stations reject reassignment without losing the previous duty")
	state.set_tug_away(true)
	check(state.staffing("engineering") == 0 and state.member("mara").away and state.member("ivo").away, "Mara and Ivo stop aboard work while deployed on Latch")
	check(not state.assign("mara", "bridge"), "Away crew cannot be reassigned remotely")
	state.set_tug_away(false)
	check(state.member("mara").station == "hydroponics" and state.member("mara").travel_remaining > 0, "Returning tug crew resume their saved duties through the airlock")
	state.advance(6)
	check(state.staffing("engineering") > 0.99, "Returned engineer resumes reactor duty after walking back")
	state.member("ivo").health = 0
	check(not state.can_launch_tug() and state.staffing("engineering") == 0, "Incapacitated crew cannot launch a tug or staff a machine")
	check(not state.assign("ivo", "bridge") and state.assign("ivo", "quarters"), "Incapacitated crew can be sent to care but not ordinary duties")
	state.member("mara").fatigue = 80
	state.assign("mara", "quarters")
	state.advance(40)
	check(state.member("mara").fatigue < 68, "Rest reduces fatigue after arrival")
	state.member("nia").health = 40
	var medicine: float = state.resources.medicine
	state.advance(30)
	check(state.member("nia").health > 40 and state.resources.medicine < medicine, "Medical officer consumes medicine to heal an actual injured person")
	state.resources.medicine = 0.0
	check(not state.medical_treatment("nia"), "First aid cannot create healing without medicine")
	state.resources.medicine = 1.0
	var health: float = state.member("ivo").health
	check(state.medical_treatment("ivo") and state.member("ivo").health > health and state.resources.medicine == 0, "Emergency first aid consumes one supply and can revive an incapacitated crew member")

func test_resources() -> void:
	var state := InteriorState.new()
	var split := InteriorState.new()
	state.advance(120)
	for i in 480: split.advance(0.25)
	check(state.resources == split.resources and state.snapshot() == split.snapshot(), "Fixed ticks produce identical results regardless of frame subdivision")
	check(state.resources.water < 85 and state.resources.food > 72, "The staffed galley produces meals while crew and crops consume finite water")
	state.toggle_station("engineering")
	state.resources.power = 0.0
	var crops: float = state.resources.crops
	var oxygen: float = state.resources.oxygen
	state.advance(30)
	check(not state.powered.hydroponics and state.resources.crops == crops and state.resources.oxygen < oxygen, "A blackout stops grow lights, recycling and powered production")
	state.toggle_station("engineering")
	state.advance(20)
	check(state.resources.power > 0 and state.powered.hydroponics, "Staffed reactor can recover from an empty battery without circular power dependency")
	state.resources.oxygen = 0.0
	state.resources.food = 0.0
	state.resources.water = 0.0
	state.toggle_station("engineering")
	state.resources.power = 0.0
	var health: float = state.member("mara").health
	state.advance(5)
	check(state.member("mara").health < health and state.alerts.size() >= 4, "Depleted food, water and oxygen visibly harm crew and produce warnings")
	var valid := true
	for key in InteriorState.LIMITS: valid = valid and state.resources[key] >= 0 and state.resources[key] <= InteriorState.LIMITS[key]
	check(valid, "All resource quantities stay inside physical supply caps")
	var reduced := InteriorState.new()
	var balanced := InteriorState.new()
	reduced.ration = "rationed"
	balanced.toggle_station("mess")
	reduced.toggle_station("mess")
	balanced.advance(60)
	reduced.advance(60)
	check(reduced.resources.food > balanced.resources.food and reduced.member("mara").fatigue > balanced.member("mara").fatigue, "Rationing saves meals at a measurable fatigue cost")
	var before := reduced.generation
	reduced.reactor = "overdrive"
	reduced.advance(60)
	check(reduced.generation > before and reduced.condition.engineering < balanced.condition.engineering, "Reactor overdrive produces more power with a wear penalty")
	reduced.toggle_station("engineering")
	var reactor_condition: float = reduced.condition.engineering
	reduced.advance(20)
	check(reduced.condition.engineering == reactor_condition, "A disabled overdrive reactor does not accumulate operational wear")
	reduced.filter_condition = 10
	check(reduced.replace_filter() and reduced.filter_condition == 100 and reduced.resources.filters == 0, "Replacing a filter consumes one item and restores life support efficiency")
	reduced.condition.hydroponics = 20
	check(reduced.repair_station("hydroponics") and reduced.condition.hydroponics == 60 and reduced.resources.repair_kits == 0, "Repairs consume a finite kit and restore actual station condition")
	var unguarded := InteriorState.new()
	var guarded := InteriorState.new()
	unguarded.assign("oren", "quarters")
	unguarded.apply_impact(50)
	guarded.apply_impact(50)
	check(guarded.member("mara").health > unguarded.member("mara").health, "Security staffing measurably reduces crew impact injuries")
	var scarce := InteriorState.new()
	scarce.assign("mara", "hydroponics")
	scarce.advance(6)
	scarce.enabled.engineering = false
	scarce.enabled.mess = false
	scarce.resources.water = 0.091
	scarce.resources.crops = 10.0
	scarce.advance(1)
	check(scarce.resources.crops <= 10.10501, "Growth near empty water pays exactly for the limited crop output")
	scarce = InteriorState.new()
	scarce.member("mara").health = 90
	scarce.assign("mara", "medbay")
	scarce.advance(6)
	scarce.resources.medicine = 0.0021
	var before_health: float = scarce.member("mara").health
	scarce.advance(1)
	check(scarce.member("mara").health - before_health <= 0.06001, "Healing near empty medicine is limited by the exact remaining dose")

func test_fabrication() -> void:
	var state := InteriorState.new()
	var before: float = state.resources.parts
	check(state.queue_recipe("medicine") and state.resources.parts == before - 2, "Fabrication reserves its actual materials exactly once")
	state.toggle_station("fabrication")
	state.advance(30)
	check(state.fabrication_progress == 0 and state.fabrication_queue.size() == 1, "Unpowered fabrication cannot advance its queue")
	state.toggle_station("fabrication")
	state.advance(20)
	check(state.fabrication_queue.is_empty() and state.resources.medicine == 16, "Staffed fabrication completes a timed recipe with useful output")
	check(state.queue_recipe("filters") and state.cancel_fabrication() and not state.cancel_fabrication(), "Cancellation refunds one queued order exactly once")
	check(state.resources.parts == before - 2, "Cancellation leaves no duplicate material refund")
	state.queue_recipe("medicine")
	state.resources.parts = 50.0
	check(not state.cancel_fabrication() and state.fabrication_queue.size() == 1 and state.resources.parts == 50, "Cancellation rejects an overflowing refund instead of destroying allocated materials")
	state.resources.parts = 48.0
	check(state.cancel_fabrication() and state.resources.parts == 50, "Making locker space permits the exact refund once")
	state.resources.parts = 0.0
	check(not state.queue_recipe("repair_kits") and state.fabrication_queue.is_empty(), "Insufficient ingredients cannot partially enqueue or subtract")
	state.resources.parts = 50.0
	state.resources.filters = 8.0
	check(not state.queue_recipe("filters") and state.resources.parts == 50, "Output capacity rejects orders before charging inputs")
	state.resources.medicine = 4.0
	for i in 5: state.queue_recipe("medicine")
	state.resupply()
	var restored := InteriorState.new()
	check(state.resources.medicine == 10 and restored.restore(state.snapshot()), "Resupply respects medicine output reservations and keeps checkpoints valid")
	state.advance(100)
	check(state.resources.medicine == 30 and state.fabrication_queue.is_empty(), "All paid queued output arrives without overflowing after resupply")
	var model := Expedition.new()
	model.add_ore(6)
	model.bay.reserve("incoming", "ore", 4)
	var mined := model.mined
	check(model.process_ore_for_parts() and model.ore == 2 and model.bay.mass() == 2 and model.interior_state.resources.parts == 18, "Processing consumes real cargo pods and numeric ore atomically")
	check(model.mined == mined and model.bay.reservations.has("incoming"), "Processing retains contract progress and inbound allocations")
	var snapshot := model.snapshot()
	check(not model.process_ore_for_parts() and model.snapshot() == snapshot, "Insufficient ore leaves both supplies and cargo unchanged")

func test_persistence() -> void:
	var model := Expedition.new()
	model.add_salvage("fixture")
	model.interior_state.assign("nia", "quarters")
	model.interior_state.queue_recipe("repair_kits")
	model.interior_state.advance(2.5)
	var saved := model.snapshot()
	var restored := Expedition.from_snapshot(saved)
	check(restored != null and restored.snapshot() == saved, "Version-three snapshot preserves exact crew, travel, supplies, queue and cargo")
	var legacy := saved.duplicate(true)
	legacy.version = 2
	legacy.erase("interior")
	var migrated := Expedition.from_snapshot(legacy)
	check(migrated != null and migrated.scrap == 12 and migrated.interior_state.crew.size() == 7, "Version-two saves gain coherent crew and supplies without losing cargo")
	var invalid := saved.duplicate(true)
	invalid.interior.crew[1].id = "mara"
	check(Expedition.from_snapshot(invalid) == null, "Duplicate crew identities are rejected")
	invalid = saved.duplicate(true)
	invalid.interior.crew[0].station = "unknown"
	check(Expedition.from_snapshot(invalid) == null, "Unknown crew stations are rejected")
	invalid = saved.duplicate(true)
	invalid.interior.resources.water = NAN
	check(Expedition.from_snapshot(invalid) == null, "Nonfinite life-support supplies are rejected")
	invalid = saved.duplicate(true)
	invalid.interior.resources.food = 101
	check(Expedition.from_snapshot(invalid) == null, "Supplies beyond locker capacity are rejected")
	invalid = saved.duplicate(true)
	invalid.interior.queue = ["ore"]
	check(Expedition.from_snapshot(invalid) == null, "Unknown fabrication recipes are rejected")
	check(SaveStore.save_game(model, SAVE) == OK and SaveStore.load_game(SAVE) != null, "Interior state survives actual JSON checkpoint serialization")
	DirAccess.remove_absolute(SAVE)

func click_at(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func test_deck() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.save_path = SAVE
	game.capture_mode = "test"
	await process_frame
	game.set_mode("flight")
	game.select_unit(game.player)
	game.player.command_move(Vector3(18, 0, 5))
	var course: Vector3 = game.player.navigator.destination
	game.toggle_interior()
	await process_frame
	if DisplayServer.get_name() == "headless": root.notify_mouse_entered()
	var panel: InteriorUI = game.ui.interior_panel
	var deck: InteriorDeck = panel.deck
	await physics_frame
	check(panel.visible and deck.visible and game.mode == "interior", "Tab opens the real 3D interior viewport")
	for person in game.expedition.interior_state.crew:
		var screen := deck.global_position + deck.crew_screen_position(person.id)
		click_at(screen)
		check(panel.selected_crew == person.id, "Clicking the drawn crew selects " + person.display_name)
	for key in InteriorLayout.ROOMS:
		var screen := deck.global_position + deck.station_screen_position(key)
		click_at(screen)
		check(panel.selected_station == key, "Reference room click opens " + key)
	check(game.player.navigator.destination == course, "Interior clicks never replace the exterior course")
	panel.select_crew("mara")
	for button in panel.buttons:
		if button.text == "Hydroponics":
			click_at(button.get_global_rect().get_center())
			break
	check(game.expedition.interior_state.member("mara").station == "hydroponics", "A real assignment button changes an individual's job")
	var time: float = game.expedition.interior_state.sim_seconds
	game._process(2)
	check(game.expedition.interior_state.sim_seconds >= time + 2, "Life aboard visibly advances in interior mode")
	panel.toggle_pause()
	time = game.expedition.interior_state.sim_seconds
	game._process(3)
	check(game.expedition.interior_state.sim_seconds == time, "Interior pause freezes resource and job clocks")
	game.set_mode("settings")
	game._process(3)
	check(game.expedition.interior_state.sim_seconds == time, "Settings do not drain resources in the background")
	game.set_mode("interior")
	game.toggle_cargo()
	game.toggle_cargo()
	check(game.mode == "interior", "Cargo inspection returns to the interior that opened it")
	game.set_mode("flight")
	game.expedition.interior_state.condition.engineering = 0.0
	game.expedition.interior_state.resources.repair_kits = 0.0
	game.expedition.interior_state.resources.power = 0.0
	game.dock()
	check(game.expedition.interior_state.condition.engineering == 100 and game.expedition.interior_state.resources.power == 100, "Port servicing recovers a destroyed reactor even with no kits or stored power")
	var credits: int = game.expedition.credits
	var cost: int = game.expedition.interior_state.supply_cost()
	game.resupply_interior()
	check(game.expedition.credits == credits - cost and game.expedition.interior_state.resources.water == 100, "Dock resupply charges the displayed price and restores real supplies")
	game.toggle_interior()
	game.toggle_map()
	game.toggle_map()
	check(game.mode == "interior" and game.interior_return == "dock", "Chart returns to a docked interior instead of flying out of the berth")
	game.pause_return = "interior"
	game.set_mode("pause")
	game.resume()
	check(game.mode == "interior", "Pause Resume restores the interior origin")
	game.toggle_interior()
	check(game.mode == "dock", "Interior opened in port returns to the dock")
	# Allow the audio mix thread to release active playback before freeing players,
	# matching the application's orderly quit path rather than tearing it down mid-mix.
	game.audio.shutdown()
	await create_timer(0.25).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	DirAccess.remove_absolute(SAVE)

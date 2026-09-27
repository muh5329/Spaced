extends SceneTree
## Captures actual runtime frames, using an isolated deterministic expedition.
var game: Node


func _initialize() -> void:
	call_deferred("run")


func capture(label: String) -> void:
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/frontier-" + label + ".png")
	print("CAPTURE frontier-", label, " fps=", Engine.get_frames_per_second())


func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.save_path = "user://frontier-showcase.json"
	game.capture_mode = "test"
	var model := Expedition.new()
	model.network.world_seed = 457
	game.build_world(model)
	game.set_mode("flight")
	game.dock()
	game.voyage.open_jobs()
	await capture("commissions")
	var job: Dictionary = model.contracts.definition(model.network, 0, 2)
	game.voyage.accept_job(job.id)
	game.voyage.open_chart()
	game.voyage.select_system(8)
	game.ui.toast_time = 0
	await capture("network")
	game.voyage.select_system(1)
	game.voyage.begin_jump()
	await create_timer(1.0).timeout
	await capture("jump")
	while game.mode == "jump":
		await process_frame
	await capture("arrival")
	game.ui.toast_time = 0
	game.player.selected = true
	game.player.position = game.sector.wreck_position + Vector3(-7, 18, 30)
	game.camera_zoom = 98
	game.update_camera(1, true)
	await capture("cinder")
	game.set_mode("map")
	await capture("local-chart")
	model.network.current = 6
	model.network.visited[6] = true
	game.build_world(model)
	game.set_mode("flight")
	game.player.position = game.sector.mine_position + Vector3(5, 18, 15)
	game.player.selected = true
	game.camera_zoom = 90
	game.update_camera(1, true)
	for storm in game.sector.storms:
		storm.phase = 11
	game.ui.toast_time = 0
	await capture("veil")
	game.audio.shutdown()
	await create_timer(0.25).timeout
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://frontier-showcase.json")
	quit()

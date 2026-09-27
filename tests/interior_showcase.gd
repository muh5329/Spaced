extends SceneTree
## Reproducible rendered views and an actual routed crew animation demonstration.
var game: Node
var deck: InteriorDeck
var frame: int = 0
var recording: bool = false


func _initialize() -> void:
	call_deferred("run")


func capture(title: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/" + title + ".png")


func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.capture_mode = "interior-showcase"
	game.save_path = "user://interior-showcase.json"
	game.set_mode("interior")
	deck = game.ui.interior_panel.deck
	await create_timer(.3).timeout
	if "--record" in OS.get_cmdline_user_args():
		recording = true
		return
	await capture("interior-3d-default")
	deck.azimuth += PI
	deck.update_camera()
	await create_timer(.15).timeout
	await capture("interior-3d-reverse")
	deck.reset_view()
	deck.zoom = 2.1
	deck.pan = Vector2(-8.5, 3.0)
	deck.update_camera()
	await create_timer(.15).timeout
	await capture("interior-3d-engineering")
	deck.zoom = 2.8
	deck.pan = Vector2(10.9, -6.5)
	deck.update_camera()
	await create_timer(.15).timeout
	await capture("interior-3d-crew")
	await finish()


func _process(_delta: float) -> bool:
	if not recording:
		return false
	frame += 1
	if frame == 90:
		game.ui.interior_panel.select_crew("ivo")
		game.ui.interior_panel.assign_to("quarters")
	if frame > 90 and frame < 450:
		deck.zoom = 1.75
		deck.pan = Vector2(-4.0, -4.4)
		deck.update_camera()
	if frame == 300:
		capture("interior-3d-walking")
	if frame == 450:
		deck.reset_view()
	if frame > 450 and frame < 630:
		deck.azimuth += 0.012
		deck.update_camera()
	if frame >= 660:
		recording = false
		finish()
	return false


func finish() -> void:
	game.audio.shutdown()
	await create_timer(.25).timeout
	game.queue_free()
	await process_frame
	await create_timer(.2).timeout
	quit()

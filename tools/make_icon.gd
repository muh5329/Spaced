extends SceneTree

func _initialize() -> void:
	var svg := FileAccess.get_file_as_string("res://assets/icon.svg")
	var icon := Image.new()
	icon.load_svg_from_string(svg, 4)
	icon.save_png("res://builds/icon.png")
	quit()

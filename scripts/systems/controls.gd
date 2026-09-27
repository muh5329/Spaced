class_name Controls
extends RefCounted


static func install() -> void:
	var keys := {
		"starchart": [KEY_J],
		"journal": [KEY_L],
		"boost": [KEY_SHIFT],
		"plot_move": [KEY_G],
		"focus_ship": [KEY_F],
		"interact": [KEY_E],
		"scan": [KEY_SPACE],
		"interior": [KEY_TAB],
		"map": [KEY_M],
		"pause_game": [KEY_ESCAPE],
		"stop": [KEY_X],
		"cargo_view": [KEY_C],
		"recall": [KEY_R],
		"unit_0": [KEY_1],
		"unit_1": [KEY_2],
		"unit_2": [KEY_3],
		"unit_3": [KEY_4]
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

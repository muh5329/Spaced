class_name SaveStore
extends RefCounted
## Dock checkpoints are written atomically; a failed write never replaces a good save.
const PATH := "user://expedition.json"

static func save_game(model: Expedition, path: String = PATH) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(model.snapshot(), "\t"))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK:
		return result
	return DirAccess.rename_absolute(path + ".tmp", path)

static func load_game(path: String = PATH) -> Expedition:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1000000:
		return null
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return null
	return Expedition.from_snapshot(data)

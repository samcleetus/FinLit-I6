extends Node
class_name Persistence

const SETTINGS_PATH := "user://app_settings.json"


static func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		print("Persistence: settings file missing at %s" % SETTINGS_PATH)
		return {}

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		print("Persistence: failed to open settings file at %s" % SETTINGS_PATH)
		return {}

	var content := file.get_as_text()
	var parsed: Variant = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("Persistence: settings file at %s was not a dictionary" % SETTINGS_PATH)
		return {}

	print("Persistence: loaded settings from %s" % SETTINGS_PATH)
	return parsed


static func save_settings(settings: Dictionary) -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		print("Persistence: failed to open settings file for write at %s" % SETTINGS_PATH)
		return

	file.store_string(JSON.stringify(settings, "\t"))
	print("Persistence: saved settings to %s" % SETTINGS_PATH)

extends Node
class_name Persistence

const SETTINGS_PATH := "user://app_settings.json"
const PROFILE_STATS_PATH := "user://profile_stats.json"
const ProfileStatsResource = preload("res://Scripts/Data/ProfileStats.gd")


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


static func load_profile_stats():
	var default_stats = ProfileStatsResource.new()
	if not FileAccess.file_exists(PROFILE_STATS_PATH):
		print("Persistence: profile stats file missing at %s" % PROFILE_STATS_PATH)
		return default_stats

	var file := FileAccess.open(PROFILE_STATS_PATH, FileAccess.READ)
	if file == null:
		print("Persistence: failed to open profile stats file at %s" % PROFILE_STATS_PATH)
		return default_stats

	var content := file.get_as_text()
	var parsed: Variant = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("Persistence: profile stats file at %s was not a dictionary" % PROFILE_STATS_PATH)
		return default_stats

	var loaded_stats = ProfileStatsResource.from_dict(parsed)
	print("Persistence: loaded profile stats from %s" % PROFILE_STATS_PATH)
	return loaded_stats


static func save_profile_stats(stats) -> void:
	var target_stats = stats if stats != null else ProfileStatsResource.new()
	var file := FileAccess.open(PROFILE_STATS_PATH, FileAccess.WRITE)
	if file == null:
		print("Persistence: failed to open profile stats file for write at %s" % PROFILE_STATS_PATH)
		return

	file.store_string(JSON.stringify(target_stats.to_dict(), "\t"))
	print("Persistence: saved profile stats to %s" % PROFILE_STATS_PATH)

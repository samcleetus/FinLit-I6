extends Node

const AppSettingsResource = preload("res://Scripts/Data/AppSettings.gd")
const PersistenceUtil = preload("res://Scripts/Systems/Persistence.gd")

@warning_ignore("unused_signal")
signal settings_changed(settings)

enum RunState { IDLE, IN_RUN, ENDED }
enum RunMode { PRACTICE, STANDARD }
enum SceneId { BOOT, MAIN_MENU, SETTINGS, PROFILE, START_RUN, START_PRACTICE, MATCH, COLLECTION }

var _settings: AppSettings
var current_run_state: int = RunState.IDLE
var current_run_mode: int = RunMode.STANDARD
var current_run_id: String = ""
var _run_counter: int = 0

var _scene_paths := {
	SceneId.BOOT: "res://Scenes/Game/Boot.tscn",
	SceneId.MAIN_MENU: "res://Scenes/Game/MainMenu.tscn",
	SceneId.SETTINGS: "res://Scenes/Game/Settings.tscn",
	SceneId.PROFILE: "res://Scenes/Game/Profile.tscn",
	SceneId.START_RUN: "res://Scenes/Game/StartRun.tscn",
	SceneId.START_PRACTICE: "res://Scenes/Game/StartPractice.tscn",
	SceneId.MATCH: "res://Scenes/Game/Match.tscn",
	SceneId.COLLECTION: "res://Scenes/Game/Collection.tscn",
}


func _ready() -> void:
	print("GameManager: _ready called, loading AppSettings and initializing run state to IDLE")
	_load_or_init_settings()
	_reset_run_tracking()


func get_settings() -> AppSettings:
	_ensure_settings_loaded()
	print("GameManager: get_settings called")
	return _settings.clone()


func set_time_horizon(value) -> void:
	_ensure_settings_loaded()
	print("GameManager: set_time_horizon called with %s" % value)
	if _settings == null:
		print("GameManager: cannot set time_horizon, settings not initialized")
		return
	var parsed_value := _parse_int_value(value)
	_settings.time_horizon = parsed_value
	print("GameManager: time_horizon updated to %s" % _settings.time_horizon)
	_persist_settings()


func set_difficulty(value) -> void:
	_ensure_settings_loaded()
	print("GameManager: set_difficulty called with %s" % value)
	if _settings == null:
		print("GameManager: cannot set difficulty, settings not initialized")
		return
	_settings.difficulty = str(value)
	print("GameManager: difficulty updated to %s" % _settings.difficulty)
	_persist_settings()


func start_new_run() -> bool:
	_run_counter += 1
	current_run_id = "run_%s" % _run_counter
	current_run_mode = RunMode.STANDARD
	current_run_state = RunState.IN_RUN
	print("GameManager: start_new_run called -> mode=STANDARD state=IN_RUN run_id=%s" % current_run_id)
	if _settings:
		_settings.mode = "normal"
	return true


func start_practice(params: Dictionary = {}) -> bool:
	_run_counter += 1
	current_run_id = "practice_%s" % _run_counter
	current_run_mode = RunMode.PRACTICE
	current_run_state = RunState.IN_RUN
	print("GameManager: start_practice called with params %s -> mode=PRACTICE state=IN_RUN run_id=%s" % [params, current_run_id])
	if _settings:
		_settings.mode = "practice"
		if params.has("time_horizon"):
			set_time_horizon(params["time_horizon"])
		if params.has("difficulty"):
			set_difficulty(params["difficulty"])
	return true


func reset_run() -> void:
	print("GameManager: reset_run called -> clearing run and returning to IDLE")
	_reset_run_tracking()


func get_run_state() -> int:
	print("GameManager: get_run_state called -> %s" % _state_to_string(current_run_state))
	return current_run_state


func get_run_mode() -> int:
	print("GameManager: get_run_mode called -> %s" % _mode_to_string(current_run_mode))
	return current_run_mode


func is_run_active() -> bool:
	var active := current_run_state == RunState.IN_RUN
	print("GameManager: is_run_active called -> %s" % active)
	return active


func get_profile_summary() -> Dictionary:
	print("GameManager: get_profile_summary called")
	_ensure_settings_loaded()
	if not _settings:
		return {"status": "uninitialized"}
	return {
		"mode": _settings.mode,
		"difficulty": _settings.difficulty,
		"time_horizon": _settings.time_horizon,
		"run_state": _state_to_string(current_run_state),
		"run_mode": _mode_to_string(current_run_mode),
		"run_id": current_run_id,
		"runs_completed": 0,
	}


func go_to(scene_id: int) -> void:
	if not _scene_paths.has(scene_id):
		print("GameManager: go_to called with invalid scene_id %s" % scene_id)
		return
	var scene_path: String = _scene_paths[scene_id]
	if not ResourceLoader.exists(scene_path):
		print("GameManager: go_to path missing -> scene_id=%s path=%s" % [_scene_to_string(scene_id), scene_path])
		return
	print("GameManager: go_to called -> scene_id=%s path=%s" % [_scene_to_string(scene_id), scene_path])
	var tree := get_tree()
	if tree == null:
		print("GameManager: get_tree() was null, cannot change scene")
		return
	var err := tree.change_scene_to_file(scene_path)
	if err == ERR_BUSY:
		print("GameManager: change_scene_to_file busy, deferring -> scene_id=%s path=%s" % [_scene_to_string(scene_id), scene_path])
		tree.call_deferred("change_scene_to_file", scene_path)
	elif err != OK:
		print("GameManager: go_to failed -> scene_id=%s path=%s err=%s" % [_scene_to_string(scene_id), scene_path, err])


func go_to_main_menu() -> void:
	print("GameManager: go_to_main_menu called")
	go_to(SceneId.MAIN_MENU)


func go_to_settings() -> void:
	print("GameManager: go_to_settings called")
	go_to(SceneId.SETTINGS)


func go_to_profile() -> void:
	print("GameManager: go_to_profile called")
	go_to(SceneId.PROFILE)


func go_to_start_run() -> void:
	print("GameManager: go_to_start_run called")
	go_to(SceneId.START_RUN)


func go_to_start_practice() -> void:
	print("GameManager: go_to_start_practice called")
	go_to(SceneId.START_PRACTICE)


func go_to_match() -> void:
	print("GameManager: go_to_match called")
	go_to(SceneId.MATCH)


func go_to_collection() -> void:
	print("GameManager: go_to_collection called")
	go_to(SceneId.COLLECTION)


func should_show_boot() -> bool:
	_ensure_settings_loaded()
	var flag := _settings != null and _settings.should_show_boot
	print("GameManager: should_show_boot called -> %s" % flag)
	return flag


func set_should_show_boot(value: bool) -> void:
	_ensure_settings_loaded()
	print("GameManager: set_should_show_boot called with %s" % value)
	if _settings == null:
		print("GameManager: cannot set should_show_boot, settings not initialized")
		return
	_settings.should_show_boot = value
	_persist_settings()


func get_scene_path(scene_id: int) -> String:
	if _scene_paths.has(scene_id):
		return _scene_paths[scene_id]
	return ""


func _reset_run_tracking() -> void:
	current_run_state = RunState.IDLE
	current_run_mode = RunMode.STANDARD
	current_run_id = ""


func _load_or_init_settings() -> void:
	var data := PersistenceUtil.load_settings()
	if data.is_empty():
		print("GameManager: No saved settings found, creating defaults")
		_settings = AppSettingsResource.new()
		_persist_settings(false)
	else:
		_settings = AppSettingsResource.from_dict(data)
		print("GameManager: Settings loaded (version %s)" % _settings.data_version)
	if _settings == null:
		print("GameManager: settings load failed, reverting to defaults")
		_settings = AppSettingsResource.new()
		_persist_settings(false)


func _persist_settings(emit_signal_flag: bool = true) -> void:
	if _settings == null:
		print("GameManager: cannot persist settings, instance is null")
		return
	PersistenceUtil.save_settings(_settings.to_dict())
	if emit_signal_flag:
		emit_signal("settings_changed", _settings.clone())


func _ensure_settings_loaded() -> void:
	if _settings == null:
		_load_or_init_settings()


func _parse_int_value(value) -> int:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	if typeof(value) == TYPE_STRING:
		var text: String = value
		var parts := text.strip_edges().split(" ")
		if parts.size() > 0 and parts[0].is_valid_int():
			return int(parts[0])
		if text.is_valid_int():
			return int(text)
	return 0


func _state_to_string(value: int) -> String:
	match value:
		RunState.IDLE:
			return "IDLE"
		RunState.IN_RUN:
			return "IN_RUN"
		RunState.ENDED:
			return "ENDED"
		_:
			return "UNKNOWN"


func _mode_to_string(value: int) -> String:
	match value:
		RunMode.PRACTICE:
			return "PRACTICE"
		RunMode.STANDARD:
			return "STANDARD"
		_:
			return "UNKNOWN"


func _scene_to_string(value: int) -> String:
	match value:
		SceneId.BOOT:
			return "BOOT"
		SceneId.MAIN_MENU:
			return "MAIN_MENU"
		SceneId.SETTINGS:
			return "SETTINGS"
		SceneId.PROFILE:
			return "PROFILE"
		SceneId.START_RUN:
			return "START_RUN"
		SceneId.START_PRACTICE:
			return "START_PRACTICE"
		SceneId.MATCH:
			return "MATCH"
		SceneId.COLLECTION:
			return "COLLECTION"
		_:
			return "UNKNOWN_SCENE"

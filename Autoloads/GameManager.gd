extends Node

enum RunState { IDLE, IN_RUN, ENDED }
enum RunMode { PRACTICE, STANDARD }
enum SceneId { BOOT, MAIN_MENU, SETTINGS, PROFILE, START_RUN, START_PRACTICE, MATCH, COLLECTION }

var _settings: AppSettings
var current_run_state: int = RunState.IDLE
var current_run_mode: int = RunMode.STANDARD
var current_run_id: String = ""
var _run_counter: int = 0
var _should_show_boot: bool = true

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
	print("GameManager: _ready called, initializing AppSettings with defaults and run state to IDLE")
	_settings = AppSettings.new()
	_reset_run_tracking()


func get_settings() -> AppSettings:
	print("GameManager: get_settings called")
	return _settings


func set_time_horizon(value) -> void:
	print("GameManager: set_time_horizon called with %s" % value)
	if _settings:
		_settings.time_horizon = value
		print("GameManager: time_horizon updated to %s" % _settings.time_horizon)
	else:
		print("GameManager: cannot set time_horizon, settings not initialized")


func set_difficulty(value) -> void:
	print("GameManager: set_difficulty called with %s" % value)
	if _settings:
		_settings.difficulty = value
		print("GameManager: difficulty updated to %s" % _settings.difficulty)
	else:
		print("GameManager: cannot set difficulty, settings not initialized")


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
			_settings.time_horizon = params["time_horizon"]
		if params.has("difficulty"):
			_settings.difficulty = params["difficulty"]
	return true


func reset_run() -> void:
	print("GameManager: reset_run called -> clearing run and returning to IDLE")
	_reset_run_tracking()
	_settings = AppSettings.new()


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
	if err != OK:
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
	print("GameManager: should_show_boot called -> %s" % _should_show_boot)
	return _should_show_boot


func set_should_show_boot(value: bool) -> void:
	print("GameManager: set_should_show_boot called with %s" % value)
	_should_show_boot = value


func get_scene_path(scene_id: int) -> String:
	if _scene_paths.has(scene_id):
		return _scene_paths[scene_id]
	return ""


func _reset_run_tracking() -> void:
	current_run_state = RunState.IDLE
	current_run_mode = RunMode.STANDARD
	current_run_id = ""


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

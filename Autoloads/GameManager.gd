extends Node

var _settings: AppSettings


func _ready() -> void:
	print("GameManager: _ready called, initializing AppSettings with defaults")
	_settings = AppSettings.new()


func get_settings() -> AppSettings:
	print("GameManager: get_settings called")
	return _settings


func set_time_horizon(value: float) -> void:
	print("GameManager: set_time_horizon called with %s" % value)
	if _settings:
		_settings.time_horizon = value


func set_difficulty(value: String) -> void:
	print("GameManager: set_difficulty called with %s" % value)
	if _settings:
		_settings.difficulty = value


func start_new_run() -> bool:
	print("GameManager: start_new_run called")
	if _settings:
		_settings.mode = "normal"
	return true


func start_practice(params: Dictionary = {}) -> bool:
	print("GameManager: start_practice called with params %s" % params)
	if _settings:
		_settings.mode = "practice"
		if params.has("time_horizon"):
			_settings.time_horizon = params["time_horizon"]
		if params.has("difficulty"):
			_settings.difficulty = params["difficulty"]
	return true


func reset_run() -> void:
	print("GameManager: reset_run called, restoring defaults")
	_settings = AppSettings.new()


func get_profile_summary() -> Dictionary:
	print("GameManager: get_profile_summary called")
	if not _settings:
		return {"status": "uninitialized"}
	return {
		"mode": _settings.mode,
		"difficulty": _settings.difficulty,
		"time_horizon": _settings.time_horizon,
		"runs_completed": 0,
	}

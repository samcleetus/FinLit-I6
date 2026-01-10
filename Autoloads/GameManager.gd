extends Node

enum RunState { IDLE, IN_RUN, ENDED }
enum RunMode { PRACTICE, STANDARD }

var _settings: AppSettings
var current_run_state: int = RunState.IDLE
var current_run_mode: int = RunMode.STANDARD
var current_run_id: String = ""
var _run_counter: int = 0


func _ready() -> void:
	print("GameManager: _ready called, initializing AppSettings with defaults and run state to IDLE")
	_settings = AppSettings.new()
	_reset_run_tracking()


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

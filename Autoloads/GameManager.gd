extends Node

const AppSettingsResource = preload("res://Scripts/Data/AppSettings.gd")
const RunStateResource = preload("res://Scripts/Data/RunState.gd")
const PersistenceUtil = preload("res://Scripts/Systems/Persistence.gd")
const IndicatorDBPath := "res://Resources/IndicatorDB.tres"
const AssetDBPath := "res://Resources/AssetDB.tres"
const DEFAULT_TOTAL_FUNDS := 10000

@warning_ignore("unused_signal")
signal settings_changed(settings)

enum SessionMode { NONE, RUN, PRACTICE }
enum SceneId { BOOT, MAIN_MENU, SETTINGS, PROFILE, START_RUN, START_PRACTICE, MATCH, COLLECTION }

var _settings: AppSettings
var session_mode: int = SessionMode.NONE
var run_state: Object = null
var _run_counter: int = 0
var current_year_index: int = 0
var current_year_scenario: YearScenario = null
var scenario_config: ScenarioGeneratorConfig = null
var run_seed: int = 0
var tap_amount: int = 1000

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
	print("GameManager: _ready called, loading AppSettings and initializing session mode to NONE")
	_load_or_init_settings()
	_reset_run_tracking()
	_load_scenario_config()
	debug_validate_data_resources()


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


func start_new_run(chosen_asset_ids: Array[String]) -> bool:
	_run_counter += 1
	session_mode = SessionMode.RUN
	var state: Object = RunStateResource.new()
	state.run_id = _generate_run_id("run")
	state.current_year_index = 0
	state.chosen_asset_ids = chosen_asset_ids.duplicate()
	state.reset_history()
	state.total_funds = DEFAULT_TOTAL_FUNDS
	state.unallocated_funds = state.total_funds
	state.allocated_by_asset = {}
	for asset_id in state.chosen_asset_ids:
		state.allocated_by_asset[asset_id] = 0
	run_state = state
	current_year_index = 0
	run_seed = abs(hash(state.run_id))
	current_year_scenario = null
	if _settings:
		_settings.mode = "normal"
	print("GameManager: start_new_run -> mode=%s run_id=%s chosen_assets=%s" % [_session_mode_to_string(session_mode), run_state.run_id, run_state.chosen_asset_ids])
	prepare_next_year()
	return true


func start_practice(params: Dictionary = {}) -> bool:
	_run_counter += 1
	session_mode = SessionMode.PRACTICE
	run_state = null
	var practice_id := _generate_run_id("practice")
	print("GameManager: start_practice called with params %s -> mode=%s run_id=%s (practice flow not yet implemented)" % [params, _session_mode_to_string(session_mode), practice_id])
	if _settings:
		_settings.mode = "practice"
		if params.has("time_horizon"):
			set_time_horizon(params["time_horizon"])
		if params.has("difficulty"):
			set_difficulty(params["difficulty"])
	return true


func reset_run() -> void:
	print("GameManager: reset_run called -> clearing run state and session mode")
	_reset_run_tracking()


func get_session_mode() -> int:
	print("GameManager: get_session_mode called -> %s" % _session_mode_to_string(session_mode))
	return session_mode


func get_run_state() -> Object:
	var id_text: String = run_state.run_id if run_state else "null"
	print("GameManager: get_run_state called -> session_mode=%s run_id=%s" % [_session_mode_to_string(session_mode), id_text])
	return run_state


func allocate_to_asset(asset_id: String, amount: int) -> bool:
	if session_mode != SessionMode.RUN or run_state == null:
		print("GameManager: allocate_to_asset skipped (no active run)")
		return false
	if asset_id == "":
		print("GameManager: allocate_to_asset skipped (empty asset id)")
		return false
	var state := run_state as RunState
	if state == null:
		print("GameManager: allocate_to_asset skipped (run_state missing)")
		return false
	if state.allocated_by_asset == null or typeof(state.allocated_by_asset) != TYPE_DICTIONARY:
		state.allocated_by_asset = {}
	var clamped_amount := clampi(amount, 0, state.unallocated_funds)
	if clamped_amount <= 0:
		print("GameManager: allocate_to_asset skipped (requested=%d, unallocated=%d)" % [amount, state.unallocated_funds])
		return false
	var previous := int(state.allocated_by_asset.get(asset_id, 0))
	state.unallocated_funds -= clamped_amount
	state.allocated_by_asset[asset_id] = previous + clamped_amount
	print("GameManager: allocated $%d to %s (unallocated=$%d)" % [clamped_amount, asset_id, state.unallocated_funds])
	return true


func reallocate(from_asset_id: String, to_asset_id: String, amount: int) -> bool:
	if session_mode != SessionMode.RUN or run_state == null:
		print("GameManager: reallocate skipped (no active run)")
		return false
	if from_asset_id == "" or to_asset_id == "" or from_asset_id == to_asset_id:
		print("GameManager: reallocate skipped (invalid asset ids)")
		return false
	if amount <= 0:
		print("GameManager: reallocate skipped (non-positive amount %d)" % amount)
		return false
	var state := run_state as RunState
	if state == null:
		print("GameManager: reallocate skipped (run_state missing)")
		return false
	if state.allocated_by_asset == null or typeof(state.allocated_by_asset) != TYPE_DICTIONARY:
		state.allocated_by_asset = {}
	var from_current := int(state.allocated_by_asset.get(from_asset_id, 0))
	var to_current := int(state.allocated_by_asset.get(to_asset_id, 0))
	var move_amount: int = min(amount, from_current)
	if move_amount <= 0:
		print("GameManager: reallocate skipped (nothing available to move from %s)" % from_asset_id)
		return false
	state.allocated_by_asset[from_asset_id] = from_current - move_amount
	state.allocated_by_asset[to_asset_id] = to_current + move_amount
	print("GameManager: reallocated $%d from %s to %s" % [move_amount, from_asset_id, to_asset_id])
	return true


func get_match_view_model() -> MatchViewModel:
	_ensure_settings_loaded()
	var vm := MatchViewModel.new()
	var settings := _settings
	vm.year_index = current_year_index
	vm.time_horizon = settings.time_horizon if settings else 0
	vm.difficulty = settings.difficulty if settings else ""
	var state := run_state as RunState
	vm.debug_run_id = state.run_id if state else ""
	vm.debug_seed = run_seed

	if current_year_scenario == null:
		push_warning("GameManager: get_match_view_model called but current_year_scenario is null.")
	else:
		vm.indicators = _build_indicator_view_models(current_year_scenario)

	vm.asset_slots = _build_asset_slot_view_models()
	print("GameManager: built MatchViewModel -> %s" % vm.to_debug_string())
	return vm


func is_run_active() -> bool:
	var active := session_mode == SessionMode.RUN and run_state != null
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
		"session_mode": _session_mode_to_string(session_mode),
		"run_id": run_state.run_id if run_state else "",
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
	session_mode = SessionMode.NONE
	run_state = null
	current_year_scenario = null
	run_seed = 0
	current_year_index = 0


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


func _generate_run_id(prefix: String) -> String:
	var timestamp := Time.get_unix_time_from_system()
	return "%s_%s_%s" % [prefix, _run_counter, timestamp]


func _session_mode_to_string(value: int) -> String:
	match value:
		SessionMode.NONE:
			return "NONE"
		SessionMode.RUN:
			return "RUN"
		SessionMode.PRACTICE:
			return "PRACTICE"
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


func debug_validate_data_resources() -> void:
	print("DataCheck: starting")
	var asset_path := "res://Resources/AssetDB.tres"
	var indicator_path := "res://Resources/IndicatorDB.tres"
	var behavior_path := "res://Resources/BehaviorMatrix.tres"

	var asset_db := load(asset_path)
	if asset_db == null:
		print("DataCheck: FAILED to load AssetDB at %s" % asset_path)
		return

	var indicator_db := load(indicator_path)
	if indicator_db == null:
		print("DataCheck: FAILED to load IndicatorDB at %s" % indicator_path)
		return

	var behavior_matrix := load(behavior_path)
	if behavior_matrix == null:
		print("DataCheck: FAILED to load BehaviorMatrix at %s" % behavior_path)
		return

	var asset_count: int = asset_db.get_all().size() if asset_db.has_method("get_all") else 0
	var indicator_count: int = indicator_db.get_all().size() if indicator_db.has_method("get_all") else 0
	var rule_count: int = behavior_matrix.rules.size() if behavior_matrix is BehaviorMatrix else 0
	print("DataCheck: assets=%s indicators=%s rules=%s" % [asset_count, indicator_count, rule_count])

	var samples := [
		{"asset": "cash", "indicator": "inflation"},
		{"asset": "bonds", "indicator": "interest_rates"},
		{"asset": "stocks", "indicator": "unemployment"},
	]

	for sample in samples:
		var low := 0
		var high := 0
		if behavior_matrix is BehaviorMatrix:
			low = behavior_matrix.get_effect(sample.asset, sample.indicator, false)
			high = behavior_matrix.get_effect(sample.asset, sample.indicator, true)
		print("DataCheck: %s|%s low=%s high=%s" % [sample.asset, sample.indicator, low, high])


func advance_year() -> bool:
	_ensure_settings_loaded()
	if session_mode != SessionMode.RUN:
		push_warning("GameManager: advance_year called when session_mode is not RUN.")
		return false
	var time_horizon := _settings.time_horizon if _settings else 0
	if current_year_index + 1 >= time_horizon:
		print("GameManager: end of run reached (year %s)" % current_year_index)
		return false
	current_year_index += 1
	if run_state != null:
		run_state.current_year_index = current_year_index
	prepare_next_year()
	print("GameManager: advanced to year=%s" % current_year_index)
	return true


func prepare_next_year() -> void:
	_ensure_settings_loaded()
	if session_mode != SessionMode.RUN:
		return
	if run_state == null:
		push_error("GameManager: prepare_next_year called without an active run_state.")
		return
	if scenario_config == null:
		push_error("GameManager: ScenarioGeneratorConfig.tres missing; cannot generate scenarios.")
		return

	var available_indicator_ids := _get_available_indicator_ids()
	var settings := _settings
	var difficulty := settings.difficulty if settings else "medium"
	var time_horizon := settings.time_horizon if settings else 0
	var year_index: int = current_year_index
	var scenario := ScenarioGenerator.generate_year(
		year_index,
		current_year_scenario,
		run_seed,
		difficulty,
		time_horizon,
		available_indicator_ids,
		scenario_config
	)
	current_year_scenario = scenario
	current_year_index = scenario.year_index
	if run_state != null:
		run_state.current_year_index = scenario.year_index
	print("Scenario: year=%s indicators=%s levels=%s shocks=%s seed=%s" % [scenario.year_index, scenario.indicator_ids, scenario.indicator_levels, scenario.shocks_triggered, scenario.seed_used])


func _load_scenario_config() -> void:
	var path := "res://Resources/ScenarioGeneratorConfig.tres"
	scenario_config = load(path)
	if scenario_config == null:
		push_error("GameManager: failed to load ScenarioGeneratorConfig at %s" % path)


func _get_available_indicator_ids() -> Array[String]:
	var ids: Array[String] = []
	var indicator_path := "res://Resources/IndicatorDB.tres"
	var indicator_db := load(indicator_path)
	if indicator_db == null:
		push_error("GameManager: failed to load IndicatorDB at %s" % indicator_path)
		return ids
	if not indicator_db.has_method("get_all"):
		push_error("GameManager: IndicatorDB at %s is missing get_all()" % indicator_path)
		return ids
	for indicator in indicator_db.get_all():
		if indicator == null or indicator.id == "":
			continue
		ids.append(indicator.id)
	return ids


func _build_indicator_view_models(scenario: YearScenario) -> Array[IndicatorViewModel]:
	var indicator_vms: Array[IndicatorViewModel] = []
	var indicator_db := load(IndicatorDBPath)
	if indicator_db == null:
		push_warning("GameManager: failed to load IndicatorDB at %s while building match view model." % IndicatorDBPath)
		return indicator_vms
	if not indicator_db.has_method("get_by_id"):
		push_warning("GameManager: IndicatorDB at %s is missing get_by_id()" % IndicatorDBPath)
		return indicator_vms

	for indicator_id in scenario.indicator_ids:
		if indicator_id == "":
			continue
		var indicator: Object = indicator_db.get_by_id(indicator_id)
		if indicator == null:
			push_warning("GameManager: indicator '%s' not found in IndicatorDB." % indicator_id)
			continue

		var level := scenario.get_level(indicator_id, ScenarioGenerator.LEVEL_MID)
		var indicator_seed := _make_indicator_seed(indicator_id)
		var value: float = indicator.mid_value
		if level == ScenarioGenerator.LEVEL_LOW:
			value = _rand_between_values(indicator.low_value, indicator.mid_value, indicator_seed)
		elif level == ScenarioGenerator.LEVEL_HIGH:
			value = _rand_between_values(indicator.mid_value, indicator.high_value, indicator_seed)

		var value_int := int(round(value))
		var value_text := "%s: %d%%" % [indicator.display_name, value_int]
		var view_model := IndicatorViewModel.new(indicator_id, indicator.display_name, value_text)
		indicator_vms.append(view_model)

	return indicator_vms


func _build_asset_slot_view_models() -> Array[AssetSlotViewModel]:
	var slots: Array[AssetSlotViewModel] = []
	var state := run_state as RunState
	var chosen_ids: Array[String] = []
	if state != null:
		chosen_ids = state.chosen_asset_ids.duplicate()
	elif session_mode == SessionMode.RUN:
		push_warning("GameManager: get_match_view_model called without a valid run_state; asset slots will be empty.")

	var asset_db := load(AssetDBPath)
	var asset_db_valid := asset_db != null and asset_db.has_method("get_by_id")
	if not asset_db_valid and not chosen_ids.is_empty():
		push_warning("GameManager: AssetDB missing or invalid at %s; asset slots will be empty." % AssetDBPath)

	for i in 4:
		var slot_index := i + 1
		var asset_id := ""
		if i < chosen_ids.size():
			asset_id = chosen_ids[i]

		var display_name := ""
		var icon: Texture2D = null
		if asset_id != "" and asset_db_valid:
			var asset: Object = asset_db.get_by_id(asset_id)
			if asset == null:
				push_warning("GameManager: asset '%s' not found in AssetDB." % asset_id)
			else:
				display_name = asset.display_name
				icon = asset.icon
		elif asset_id != "" and not asset_db_valid:
			push_warning("GameManager: asset '%s' could not be resolved because AssetDB is unavailable." % asset_id)

		var slot_view_model := AssetSlotViewModel.new(slot_index, asset_id, display_name, icon)
		slots.append(slot_view_model)

	return slots


func _make_indicator_seed(indicator_id: String) -> int:
	var id_hash := hash(indicator_id)
	var mixed := int((run_seed * 92821) ^ (current_year_index * 68917) ^ id_hash)
	if mixed == 0:
		mixed = id_hash ^ 12345
	return abs(mixed)


func _rand_between_values(a: float, b: float, seed_value: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var min_value: float = min(a, b)
	var max_value: float = max(a, b)
	if is_equal_approx(min_value, max_value):
		return min_value
	return rng.randf_range(min_value, max_value)

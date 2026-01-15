extends Node

const AppSettingsResource = preload("res://Scripts/Data/AppSettings.gd")
const RunStateResource = preload("res://Scripts/Data/RunState.gd")
const ProfileStatsResource = preload("res://Scripts/Data/ProfileStats.gd")
const ProfileViewModelResource = preload("res://Scripts/ViewModels/ProfileViewModel.gd")
const PersistenceUtil = preload("res://Scripts/Systems/Persistence.gd")
const MonthResolverUtil = preload("res://Scripts/Game/MonthResolver.gd")
const IndicatorDBPath := "res://Resources/IndicatorDB.tres"
const AssetDBPath := "res://Resources/AssetDB.tres"
const BehaviorMatrixPath := "res://Resources/BehaviorMatrix.tres"
const CENTS_PER_DOLLAR := 100
const ALLOC_STEP_CENTS := 10000
const REALLOC_STEP_CENTS := 5000
const MONTHS_PER_YEAR := 12
const DEFAULT_TOTAL_FUNDS := 10000
const DEFAULT_TOTAL_FUNDS_CENTS := DEFAULT_TOTAL_FUNDS * CENTS_PER_DOLLAR
const YEARLY_CONTRIBUTION_EASY_DOLLARS := 10000
const YEARLY_CONTRIBUTION_NORMAL_DOLLARS := 8000
const YEARLY_CONTRIBUTION_HARD_DOLLARS := 6000

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
var _behavior_matrix: BehaviorMatrix = null
var _profile_stats: ProfileStats = null
var _run_completion_recorded: bool = false

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
	_load_profile_stats()
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
	_run_completion_recorded = false
	var state: Object = RunStateResource.new()
	state.run_id = _generate_run_id("run")
	state.current_year_index = 0
	state.current_month = 0
	state.match_started = false
	state.chosen_asset_ids = chosen_asset_ids.duplicate()
	state.reset_history()
	state.currency_in_cents = true
	state.portfolio_cents_by_asset_id = {}
	state.year_start_asset_cents = {}
	state.last_year_summary = {}
	_ensure_portfolio_initialized(state)
	_reset_unallocated_for_new_year(state)
	state.total_value = _compute_total_value(state)
	state.allocated_by_asset = {}
	_initialize_hand_for_new_run(state, chosen_asset_ids)
	state.total_value = _compute_total_value(state)
	state.year_start_total_cents = state.total_value
	run_state = state
	current_year_index = 0
	run_seed = abs(hash(state.run_id))
	current_year_scenario = null
	if _settings:
		_settings.mode = "normal"
	print("GameManager: start_new_run -> mode=%s run_id=%s chosen_assets=%s" % [_session_mode_to_string(session_mode), run_state.run_id, run_state.chosen_asset_ids])
	prepare_next_year()
	return true


func apply_hand_selection(hand_asset_ids: Array[String]) -> bool:
	if session_mode != SessionMode.RUN or run_state == null:
		print("GameManager: apply_hand_selection skipped (no active run)")
		return false
	var state := run_state as RunState
	if state == null:
		print("GameManager: apply_hand_selection skipped (run_state missing)")
		return false
	_ensure_state_currency_in_cents(state)
	_ensure_hand_initialized(state)
	_apply_hand_selection_for_run(state, hand_asset_ids)
	return true


func start_practice(params: Dictionary = {}) -> bool:
	_run_counter += 1
	session_mode = SessionMode.PRACTICE
	_run_completion_recorded = false
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
	if run_state is RunState:
		_ensure_state_currency_in_cents(run_state)
		_ensure_hand_initialized(run_state)
		_ensure_portfolio_initialized(run_state)
	return run_state


func get_unallocated_funds_cents() -> int:
	var state := run_state as RunState
	if state == null or state.unallocated_funds == null:
		return 0
	_ensure_state_currency_in_cents(state)
	return int(state.unallocated_funds)


func get_unallocated_funds() -> int:
	return _cents_to_whole_dollars(get_unallocated_funds_cents())


func get_yearly_contribution_cents(difficulty: String = "") -> int:
	var normalized := difficulty.to_lower() if difficulty != "" else _get_normalized_play_difficulty()
	match normalized:
		"easy":
			return YEARLY_CONTRIBUTION_EASY_DOLLARS * CENTS_PER_DOLLAR
		"hard":
			return YEARLY_CONTRIBUTION_HARD_DOLLARS * CENTS_PER_DOLLAR
		_:
			return YEARLY_CONTRIBUTION_NORMAL_DOLLARS * CENTS_PER_DOLLAR


func get_allocated_for_cents(asset_id: String) -> int:
	if asset_id == "":
		return 0
	var state := run_state as RunState
	if state == null:
		return 0
	_ensure_state_currency_in_cents(state)
	return _get_allocated_cents(state, asset_id)


func get_allocated_for(asset_id: String) -> int:
	return _cents_to_whole_dollars(get_allocated_for_cents(asset_id))


func get_total_value_cents() -> int:
	var state := run_state as RunState
	if state == null:
		return 0
	_ensure_state_currency_in_cents(state)
	state.total_value = _compute_total_value(state)
	return int(state.total_value)


func get_total_value() -> int:
	return _cents_to_whole_dollars(get_total_value_cents())


func get_end_year_match_summary() -> Dictionary:
	var default_summary := {
		"net_cents": 0,
		"best_asset_id": "",
		"best_asset_delta_cents": 0,
		"worst_asset_id": "",
		"worst_asset_delta_cents": 0,
	}
	if session_mode != SessionMode.RUN:
		return default_summary
	var state := run_state as RunState
	if state == null:
		return default_summary
	_ensure_state_currency_in_cents(state)
	if state.last_year_summary != null and typeof(state.last_year_summary) == TYPE_DICTIONARY and state.last_year_summary.size() > 0:
		var merged := default_summary.duplicate()
		for key in state.last_year_summary.keys():
			merged[key] = state.last_year_summary.get(key)
		return merged
	print("GameManager: end-year summary requested but missing; returning defaults.")
	return default_summary


func format_currency(amount_cents: int) -> String:
	return _format_currency(amount_cents)


func get_month() -> int:
	var state := run_state as RunState
	if state == null:
		return 0
	return int(state.current_month)


func advance_month() -> bool:
	return _apply_month_step()


func allocate_to_asset(asset_id: String, _amount: int) -> bool:
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
	_ensure_state_currency_in_cents(state)
	if not _is_asset_in_hand(state, asset_id):
		print("GameManager: allocate_to_asset skipped (asset not in hand) -> %s" % asset_id)
		return false
	if state.allocated_by_asset == null or typeof(state.allocated_by_asset) != TYPE_DICTIONARY:
		state.allocated_by_asset = {}
	var move_cents: int = min(ALLOC_STEP_CENTS, int(state.unallocated_funds))
	if move_cents <= 0:
		print("GameManager: allocate_to_asset skipped (unallocated=%s)" % _format_currency(state.unallocated_funds))
		return false
	var previous := _get_portfolio_cents(state, asset_id)
	state.unallocated_funds -= move_cents
	var updated := previous + move_cents
	state.allocated_by_asset[asset_id] = updated
	_set_portfolio_cents(state, asset_id, updated)
	state.match_started = true
	state.total_value = _compute_total_value(state)
	_record_allocation_stat(asset_id)
	print("GameManager: allocated %s to %s (unallocated=%s)" % [_format_currency(move_cents), asset_id, _format_currency(state.unallocated_funds)])
	return true


func reallocate(from_asset_id: String, to_asset_id: String, _amount: int) -> bool:
	if session_mode != SessionMode.RUN or run_state == null:
		print("GameManager: reallocate skipped (no active run)")
		return false
	if from_asset_id == "" or to_asset_id == "" or from_asset_id == to_asset_id:
		print("GameManager: reallocate skipped (invalid asset ids)")
		return false
	var state := run_state as RunState
	if state == null:
		print("GameManager: reallocate skipped (run_state missing)")
		return false
	_ensure_state_currency_in_cents(state)
	if not _is_asset_in_hand(state, from_asset_id) or not _is_asset_in_hand(state, to_asset_id):
		print("GameManager: reallocate skipped (asset not in hand) -> %s to %s" % [from_asset_id, to_asset_id])
		return false
	if state.allocated_by_asset == null or typeof(state.allocated_by_asset) != TYPE_DICTIONARY:
		state.allocated_by_asset = {}
	var from_current := _get_portfolio_cents(state, from_asset_id)
	if from_current <= 0:
		print("GameManager: reallocate skipped (empty from=%s holdings=%d move=0)" % [from_asset_id, from_current])
		return false
	var move_cents: int = min(REALLOC_STEP_CENTS, from_current)
	var to_current := _get_portfolio_cents(state, to_asset_id)
	var new_from := from_current - move_cents
	var new_to := to_current + move_cents
	state.allocated_by_asset[from_asset_id] = new_from
	state.allocated_by_asset[to_asset_id] = new_to
	_set_portfolio_cents(state, from_asset_id, new_from)
	_set_portfolio_cents(state, to_asset_id, new_to)
	state.total_value = _compute_total_value(state)
	if move_cents > 0:
		state.match_started = true
	if OS.is_debug_build():
		var holdings_sum := 0
		if state.portfolio_cents_by_asset_id != null and typeof(state.portfolio_cents_by_asset_id) == TYPE_DICTIONARY:
			for value in state.portfolio_cents_by_asset_id.values():
				holdings_sum += int(round(value))
		var check_total := int(round(state.unallocated_funds)) + holdings_sum
		assert(check_total == int(round(state.total_value)))
	print("GameManager: reallocated %s from %s to %s" % [_format_currency(move_cents), from_asset_id, to_asset_id])
	return true


func _apply_month_step() -> bool:
	if session_mode != SessionMode.RUN or run_state == null:
		return false
	var state := run_state as RunState
	if state == null:
		return false
	_ensure_state_currency_in_cents(state)
	if state.current_month >= MONTHS_PER_YEAR:
		_complete_year_if_needed()
		return false
	if not _has_match_started(state):
		return false

	var hand_allocations := _sync_hand_allocations_from_portfolio(state)

	if current_year_scenario == null:
		push_warning("GameManager: month step running without a current_year_scenario; skipping scenario effects.")

	_ensure_behavior_matrix_loaded()

	_apply_monthly_indicator_drift(state.current_month)

	_ensure_settings_loaded()

	var indicator_ids: Array = []
	if current_year_scenario != null:
		indicator_ids = current_year_scenario.indicator_ids

	var resolver_result := MonthResolverUtil.resolve_month_step(
		_behavior_matrix,
		current_year_scenario,
		hand_allocations,
		state.unallocated_funds,
		state.current_month,
		run_seed,
		state.current_indicator_levels
	)

	var new_allocated: Dictionary = resolver_result.get("new_allocated_by_asset", hand_allocations) if typeof(resolver_result.get("new_allocated_by_asset", hand_allocations)) == TYPE_DICTIONARY else hand_allocations
	if typeof(new_allocated) != TYPE_DICTIONARY:
		new_allocated = hand_allocations
	for asset_id in new_allocated.keys():
		_set_portfolio_cents(state, asset_id, int(round(new_allocated[asset_id])))
	state.allocated_by_asset = new_allocated

	state.total_value = _compute_total_value(state)

	_record_indicator_exposure(indicator_ids)

	state.current_month += 1
	_maybe_record_year_result(state)
	var time_horizon := _settings.time_horizon if _settings else 0
	var run_finished: bool = state.current_month >= MONTHS_PER_YEAR and current_year_index + 1 >= time_horizon
	if run_finished:
		_update_profile_stats_for_run_completion()
	print("GameManager: month advanced -> %d total=%s unallocated=%s" % [state.current_month, _format_currency(state.total_value), _format_currency(state.unallocated_funds)])
	return true


func build_match_view_model() -> MatchViewModel:
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
		var indicator_levels: Dictionary = {}
		var indicator_values: Dictionary = {}
		vm.indicators = _build_indicator_view_models(current_year_scenario, indicator_levels, indicator_values)
		vm.indicator_levels = indicator_levels
		vm.indicator_values = indicator_values

	vm.asset_slots = _build_asset_slot_view_models()
	print("GameManager: built MatchViewModel -> %s" % vm.to_debug_string())
	return vm


func get_match_view_model() -> MatchViewModel:
	return build_match_view_model()


func is_run_active() -> bool:
	var active := session_mode == SessionMode.RUN and run_state != null
	print("GameManager: is_run_active called -> %s" % active)
	return active


func get_profile_summary() -> Dictionary:
	print("GameManager: get_profile_summary called")
	_ensure_settings_loaded()
	_ensure_profile_stats_loaded()
	if not _settings:
		return {"status": "uninitialized"}
	return {
		"mode": _settings.mode,
		"difficulty": _settings.difficulty,
		"time_horizon": _settings.time_horizon,
		"session_mode": _session_mode_to_string(session_mode),
		"run_id": run_state.run_id if run_state else "",
		"runs_completed": _profile_stats.total_runs_completed,
		"best_run_total_cents": _profile_stats.best_run_total_cents,
		"total_allocations_made": _profile_stats.total_allocations_made,
	}


func get_profile_view_model() -> ProfileViewModel:
	_ensure_settings_loaded()
	_ensure_profile_stats_loaded()
	var show_cents := _get_normalized_play_difficulty() == "hard"
	return ProfileViewModelResource.from_stats(_profile_stats, show_cents)


func complete_year_if_needed() -> bool:
	return _complete_year_if_needed()


func ensure_run_ready_for_match() -> void:
	if session_mode != SessionMode.RUN or run_state == null:
		return
	var state := run_state as RunState
	if state == null:
		return
	if state.current_month >= MONTHS_PER_YEAR:
		_complete_year_if_needed()
	if state.current_month != 0:
		state.current_month = 0
	_sync_hand_allocations_from_portfolio(state)
	state.total_value = _compute_total_value(state)


func reset_profile_stats() -> void:
	_ensure_profile_stats_loaded()
	_profile_stats.reset()
	_persist_profile_stats()


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
	# Defer the scene change to avoid ERR_BUSY when called during node tree edits (e.g. from _ready).
	tree.call_deferred("change_scene_to_file", scene_path)


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
	_run_completion_recorded = false
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


func _load_profile_stats() -> void:
	_profile_stats = PersistenceUtil.load_profile_stats()
	_normalize_profile_stats_fields()
	print("GameManager: profile stats loaded")


func _persist_profile_stats() -> void:
	_normalize_profile_stats_fields()
	PersistenceUtil.save_profile_stats(_profile_stats)
	print("GameManager: profile stats saved")


func _ensure_profile_stats_loaded() -> void:
	if _profile_stats == null:
		_load_profile_stats()
	else:
		_normalize_profile_stats_fields()


func _normalize_profile_stats_fields() -> void:
	if _profile_stats == null:
		_profile_stats = ProfileStatsResource.new()
	if _profile_stats.indicator_exposure_counts == null or typeof(_profile_stats.indicator_exposure_counts) != TYPE_DICTIONARY:
		_profile_stats.indicator_exposure_counts = {}
	if _profile_stats.asset_allocation_counts == null or typeof(_profile_stats.asset_allocation_counts) != TYPE_DICTIONARY:
		_profile_stats.asset_allocation_counts = {}
	if _profile_stats.favorite_asset_id == null:
		_profile_stats.favorite_asset_id = ""
	if typeof(_profile_stats.favorite_asset_id) != TYPE_STRING:
		_profile_stats.favorite_asset_id = str(_profile_stats.favorite_asset_id)
	if _profile_stats.biggest_year_gain_cents == null:
		_profile_stats.biggest_year_gain_cents = 0
	if _profile_stats.biggest_year_loss_cents == null:
		_profile_stats.biggest_year_loss_cents = 0
	if _profile_stats.data_version < 2:
		_profile_stats.data_version = 2


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


func _dollars_to_cents(value) -> int:
	if typeof(value) == TYPE_FLOAT:
		return int(round(value * CENTS_PER_DOLLAR))
	if typeof(value) == TYPE_INT:
		return int(value) * CENTS_PER_DOLLAR
	if typeof(value) == TYPE_STRING:
		var parsed := _parse_int_value(value)
		return parsed * CENTS_PER_DOLLAR
	if value == null:
		return 0
	return int(value) * CENTS_PER_DOLLAR


func _cents_to_whole_dollars(cents: int) -> int:
	return int(round(float(cents) / CENTS_PER_DOLLAR))


func _format_currency(cents: int) -> String:
	var normalized := _get_normalized_play_difficulty()
	var dollars_value := float(cents) / CENTS_PER_DOLLAR
	if normalized == "hard":
		return "$%.2f" % [dollars_value]
	return "$%d" % _cents_to_whole_dollars(cents)


func _get_normalized_play_difficulty() -> String:
	_ensure_settings_loaded()
	var diff_text: String = _settings.difficulty if _settings else "normal"
	var normalized := diff_text.to_lower()
	if normalized == "medium":
		normalized = "normal"
	if normalized != "easy" and normalized != "normal" and normalized != "hard":
		normalized = "normal"
	return normalized


func _ensure_state_currency_in_cents(state: RunState) -> void:
	if state == null:
		return
	_ensure_portfolio_initialized(state)
	if state.year_start_asset_cents == null or typeof(state.year_start_asset_cents) != TYPE_DICTIONARY:
		state.year_start_asset_cents = {}
	if state.last_year_summary == null or typeof(state.last_year_summary) != TYPE_DICTIONARY:
		state.last_year_summary = {}
	if state.currency_in_cents:
		_backfill_portfolio_from_allocations(state)
		return
	if state.allocated_by_asset == null or typeof(state.allocated_by_asset) != TYPE_DICTIONARY:
		state.allocated_by_asset = {}
	var converted_allocations: Dictionary = {}
	for asset_id in state.allocated_by_asset.keys():
		converted_allocations[asset_id] = _dollars_to_cents(state.allocated_by_asset.get(asset_id, 0))
	state.allocated_by_asset = converted_allocations
	if state.portfolio_cents_by_asset_id == null or typeof(state.portfolio_cents_by_asset_id) != TYPE_DICTIONARY:
		state.portfolio_cents_by_asset_id = {}
	else:
		var converted_portfolio: Dictionary = {}
		for asset_id in state.portfolio_cents_by_asset_id.keys():
			converted_portfolio[asset_id] = _dollars_to_cents(state.portfolio_cents_by_asset_id.get(asset_id, 0))
		state.portfolio_cents_by_asset_id = converted_portfolio
	state.unallocated_funds = _dollars_to_cents(state.unallocated_funds)
	state.total_funds = _dollars_to_cents(state.total_funds)
	var raw_total_value: Variant = state.total_value
	if raw_total_value == null:
		raw_total_value = _compute_total_value(state, converted_allocations, state.unallocated_funds)
	state.total_value = _dollars_to_cents(raw_total_value)
	if "year_start_total_cents" in state:
		state.year_start_total_cents = _dollars_to_cents(state.year_start_total_cents)
	if state.year_start_asset_cents != null and typeof(state.year_start_asset_cents) == TYPE_DICTIONARY:
		var converted_start_assets: Dictionary = {}
		for asset_id in state.year_start_asset_cents.keys():
			converted_start_assets[asset_id] = _dollars_to_cents(state.year_start_asset_cents.get(asset_id, 0))
		state.year_start_asset_cents = converted_start_assets
	state.currency_in_cents = true
	_backfill_portfolio_from_allocations(state)


func _ensure_hand_initialized(state: RunState) -> void:
	if state == null:
		return
	if state.hand_asset_ids == null or not (state.hand_asset_ids is PackedStringArray) or state.hand_asset_ids.size() != 4:
		var current := PackedStringArray(["", "", "", ""])
		if state.hand_asset_ids != null and (state.hand_asset_ids is PackedStringArray):
			for i in min(state.hand_asset_ids.size(), 4):
				current[i] = str(state.hand_asset_ids[i])
		state.hand_asset_ids = current
	if state.hand_lock_years_remaining == null or not (state.hand_lock_years_remaining is PackedInt32Array) or state.hand_lock_years_remaining.size() != 4:
		var current_locks := PackedInt32Array([0, 0, 0, 0])
		if state.hand_lock_years_remaining != null and (state.hand_lock_years_remaining is PackedInt32Array):
			for i in min(state.hand_lock_years_remaining.size(), 4):
				current_locks[i] = int(state.hand_lock_years_remaining[i])
		state.hand_lock_years_remaining = current_locks


func _ensure_portfolio_initialized(state: RunState) -> void:
	if state == null:
		return
	if state.portfolio_cents_by_asset_id == null or typeof(state.portfolio_cents_by_asset_id) != TYPE_DICTIONARY:
		state.portfolio_cents_by_asset_id = {}
	var asset_db := load(AssetDBPath)
	if asset_db == null or not asset_db.has_method("get_all"):
		push_warning("GameManager: cannot initialize portfolio, AssetDB missing or invalid at %s" % AssetDBPath)
		return
	for asset in asset_db.get_all():
		if asset == null or asset.id == "":
			continue
		if "starting_unlocked" in asset and not asset.starting_unlocked:
			continue
		var asset_id := str(asset.id)
		if not state.portfolio_cents_by_asset_id.has(asset_id):
			state.portfolio_cents_by_asset_id[asset_id] = 0


func _backfill_portfolio_from_allocations(state: RunState) -> void:
	if state == null:
		return
	if state.portfolio_cents_by_asset_id == null or typeof(state.portfolio_cents_by_asset_id) != TYPE_DICTIONARY:
		state.portfolio_cents_by_asset_id = {}
	if state.allocated_by_asset == null or typeof(state.allocated_by_asset) != TYPE_DICTIONARY:
		return
	for asset_id in state.allocated_by_asset.keys():
		var normalized := str(asset_id)
		if normalized == "":
			continue
		var value := int(state.allocated_by_asset.get(asset_id, 0))
		if not state.portfolio_cents_by_asset_id.has(normalized) or int(state.portfolio_cents_by_asset_id.get(normalized, 0)) == 0:
			state.portfolio_cents_by_asset_id[normalized] = value


func _get_portfolio_cents(state: RunState, asset_id: String) -> int:
	if state == null or asset_id == "":
		return 0
	if state.portfolio_cents_by_asset_id == null or typeof(state.portfolio_cents_by_asset_id) != TYPE_DICTIONARY:
		state.portfolio_cents_by_asset_id = {}
	return int(state.portfolio_cents_by_asset_id.get(asset_id, 0))


func _set_portfolio_cents(state: RunState, asset_id: String, cents: int) -> void:
	if state == null or asset_id == "":
		return
	if state.portfolio_cents_by_asset_id == null or typeof(state.portfolio_cents_by_asset_id) != TYPE_DICTIONARY:
		state.portfolio_cents_by_asset_id = {}
	state.portfolio_cents_by_asset_id[asset_id] = int(cents)


func _get_hand_asset_ids(state: RunState) -> Array[String]:
	if state == null:
		return []
	return _packed_to_array(state.hand_asset_ids)


func _build_hand_allocations_from_portfolio(state: RunState, hand_ids: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for asset_id in hand_ids:
		var normalized_id := str(asset_id)
		if normalized_id == "":
			continue
		result[normalized_id] = _get_portfolio_cents(state, normalized_id)
	return result


func _sync_hand_allocations_from_portfolio(state: RunState) -> Dictionary:
	_ensure_hand_initialized(state)
	_ensure_portfolio_initialized(state)
	var hand_allocations := _build_hand_allocations_from_portfolio(state, state.hand_asset_ids)
	state.allocated_by_asset = hand_allocations
	return hand_allocations


func _is_asset_in_hand(state: RunState, asset_id: String) -> bool:
	if state == null or asset_id == "":
		return false
	return _get_hand_asset_ids(state).has(asset_id)


func _packed_to_array(values: PackedStringArray) -> Array[String]:
	var result: Array[String] = []
	if values == null:
		return result
	for value in values:
		result.append(str(value))
	return result


func _packed_ints_to_array(values: PackedInt32Array) -> Array[int]:
	var result: Array[int] = []
	if values == null:
		return result
	for value in values:
		result.append(int(value))
	return result


func _get_allocated_cents(state: RunState, asset_id: String) -> int:
	if state == null or asset_id == "":
		return 0
	_ensure_portfolio_initialized(state)
	return _get_portfolio_cents(state, asset_id)


func _generate_run_id(prefix: String) -> String:
	var timestamp := Time.get_unix_time_from_system()
	return "%s_%s_%s" % [prefix, _run_counter, timestamp]


func _get_asset_duration_years(asset_id: String) -> int:
	if asset_id == "":
		return 0
	var asset_db := load(AssetDBPath)
	if asset_db == null or not asset_db.has_method("get_by_id"):
		push_warning("GameManager: AssetDB missing or invalid at %s; duration unavailable." % AssetDBPath)
		return 0
	var asset: Object = asset_db.get_by_id(asset_id)
	if asset == null:
		push_warning("GameManager: asset '%s' not found in AssetDB while reading duration." % asset_id)
		return 0
	if "duration_years" in asset:
		return max(int(asset.duration_years), 0)
	return 0


func _initialize_hand_for_new_run(state: RunState, chosen_asset_ids: Array[String]) -> void:
	_ensure_hand_initialized(state)
	_ensure_portfolio_initialized(state)
	var normalized := PackedStringArray(["", "", "", ""])
	for i in 4:
		if i < chosen_asset_ids.size():
			normalized[i] = str(chosen_asset_ids[i])
	var locks := PackedInt32Array([0, 0, 0, 0])
	var hand_allocations: Dictionary = {}
	for i in normalized.size():
		var asset_id := normalized[i]
		if asset_id == "":
			continue
		var duration := _get_asset_duration_years(asset_id)
		locks[i] = max(duration, 0)
		hand_allocations[asset_id] = _get_portfolio_cents(state, asset_id)
	state.hand_asset_ids = normalized
	state.hand_lock_years_remaining = locks
	state.chosen_asset_ids = _packed_to_array(normalized)
	state.allocated_by_asset = hand_allocations
	print("Run: init hand slots ids=%s locks=%s" % [normalized, locks])


func _apply_hand_selection_for_run(state: RunState, hand_asset_ids: Array[String]) -> void:
	_ensure_hand_initialized(state)
	_ensure_portfolio_initialized(state)
	var normalized := PackedStringArray(["", "", "", ""])
	for i in 4:
		if i < hand_asset_ids.size():
			normalized[i] = str(hand_asset_ids[i])
	var previous_hand: PackedStringArray = state.hand_asset_ids.duplicate()
	var previous_locks: PackedInt32Array = state.hand_lock_years_remaining.duplicate()
	var new_locks := PackedInt32Array([0, 0, 0, 0])
	var new_allocations: Dictionary = {}
	for i in normalized.size():
		var asset_id := normalized[i]
		if asset_id == "":
			continue
		var prev_lock := 0
		for j in previous_hand.size():
			if previous_hand[j] == asset_id and j < previous_locks.size():
				prev_lock = int(previous_locks[j])
				break
		var lock_value: int = prev_lock if prev_lock > 0 else max(_get_asset_duration_years(asset_id), 0)
		new_locks[i] = max(lock_value, 0)
		var value := _get_portfolio_cents(state, asset_id)
		_set_portfolio_cents(state, asset_id, value)
		new_allocations[asset_id] = value
	state.hand_asset_ids = normalized
	state.hand_lock_years_remaining = new_locks
	state.chosen_asset_ids = _packed_to_array(normalized)
	state.allocated_by_asset = new_allocations
	state.total_value = _compute_total_value(state)
	_capture_year_start_snapshot(state)
	state.match_started = false
	print("Run: applied hand selection ids=%s locks=%s" % [normalized, new_locks])


func _decrement_hand_locks(state: RunState) -> void:
	if state == null:
		return
	_ensure_hand_initialized(state)
	var locks: PackedInt32Array = state.hand_lock_years_remaining.duplicate()
	var ids: PackedStringArray = state.hand_asset_ids.duplicate()
	for i in locks.size():
		if locks[i] > 0:
			locks[i] = max(locks[i] - 1, 0)
		if locks[i] == 0 and i < ids.size():
			ids[i] = ""
	state.hand_asset_ids = ids
	state.hand_lock_years_remaining = locks
	state.chosen_asset_ids = _packed_to_array(ids)
	var locks_array := _packed_ints_to_array(locks)
	print("Locks decremented -> %s" % [locks_array])


func _reset_unallocated_for_new_year(state: RunState) -> void:
	if state == null:
		return
	var reset_value := get_yearly_contribution_cents()
	state.unallocated_funds = reset_value
	state.total_funds = reset_value
	print("Unallocated reset by difficulty -> %s" % _format_currency(reset_value))


func _capture_year_start_snapshot(state: RunState) -> void:
	if state == null:
		return
	_ensure_state_currency_in_cents(state)
	var snapshot: Dictionary = {}
	if state.portfolio_cents_by_asset_id != null and typeof(state.portfolio_cents_by_asset_id) == TYPE_DICTIONARY:
		for asset_id in state.portfolio_cents_by_asset_id.keys():
			var normalized_id := str(asset_id)
			if normalized_id == "":
				continue
			snapshot[normalized_id] = int(round(state.portfolio_cents_by_asset_id.get(asset_id, 0)))
	state.year_start_asset_cents = snapshot
	state.year_start_total_cents = _compute_total_value(state)
	state.total_value = state.year_start_total_cents
	print("GameManager: year start snapshot -> year=%s total=%s assets=%s" % [
		state.current_year_index,
		_format_currency(state.year_start_total_cents),
		snapshot
	])


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
	var behavior_path := BehaviorMatrixPath

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
	var state := run_state as RunState
	if state == null:
		push_warning("GameManager: advance_year called without run_state.")
		return false
	var time_horizon := _settings.time_horizon if _settings else 0
	if current_year_index + 1 >= time_horizon:
		print("GameManager: end of run reached (year %s)" % current_year_index)
		_update_profile_stats_for_run_completion()
		return false
	_advance_run_year()
	_reset_unallocated_for_new_year(state)
	state.current_month = 0
	state.match_started = false
	_sync_hand_allocations_from_portfolio(state)
	state.total_value = _compute_total_value(state)
	state.year_start_total_cents = state.total_value
	prepare_next_year()
	print("GameManager: advanced to year=%s" % current_year_index)
	return true


func advance_year_and_return_to_start_run() -> void:
	var advanced := _complete_year_if_needed()
	if not advanced and run_state != null:
		# Ensure month resets even if the year was already advanced.
		run_state.current_month = 0
		run_state.match_started = false
		run_state.total_value = _compute_total_value(run_state)
	print("Routing -> StartRun")
	go_to_start_run()


func _advance_run_year() -> void:
	var next_year := current_year_index + 1
	print("Year ended -> advancing to year=%s" % next_year)
	current_year_index = next_year
	if run_state != null:
		run_state.current_year_index = current_year_index
		_decrement_hand_locks(run_state)


func _complete_year_if_needed() -> bool:
	if session_mode != SessionMode.RUN or run_state == null:
		return false
	var state := run_state as RunState
	if state == null:
		return false
	_ensure_state_currency_in_cents(state)
	if state.current_month < MONTHS_PER_YEAR:
		return false
	_ensure_settings_loaded()
	var time_horizon := _settings.time_horizon if _settings else 0
	var is_final_year := current_year_index + 1 >= time_horizon
	_advance_run_year()
	_reset_unallocated_for_new_year(state)
	state.current_month = 0
	state.match_started = false
	_sync_hand_allocations_from_portfolio(state)
	state.total_value = _compute_total_value(state)
	state.year_start_total_cents = state.total_value
	if is_final_year:
		_update_profile_stats_for_run_completion()
	else:
		prepare_next_year()
	var locks_array := _packed_ints_to_array(state.hand_lock_years_remaining)
	print("Run: end_year -> year_index now %s, locks now %s, month reset to %s" % [state.current_year_index, locks_array, state.current_month])
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

	run_state.current_month = 0
	_ensure_state_currency_in_cents(run_state)
	_capture_year_start_snapshot(run_state)

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
		_initialize_indicator_state_for_year(scenario)
	print("Year start -> year=%s total=%s unallocated=%s" % [run_state.current_year_index if run_state != null else current_year_index, _format_currency(run_state.total_value if run_state != null else 0), _format_currency(run_state.unallocated_funds if run_state != null else 0)])
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


func _build_indicator_view_models(scenario: YearScenario, out_levels: Dictionary = {}, out_values: Dictionary = {}) -> Array[IndicatorViewModel]:
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

		var level: int = _get_current_indicator_level(indicator_id, scenario)
		if typeof(out_levels) == TYPE_DICTIONARY:
			out_levels[indicator_id] = level
		var current_percent: float = _get_current_indicator_percent(indicator_id, indicator, scenario)
		var value_int: int = int(round(current_percent))
		if typeof(out_values) == TYPE_DICTIONARY:
			out_values[indicator_id] = current_percent
		var value_text := "%s: %d%%" % [indicator.display_name, value_int]
		var view_model := IndicatorViewModel.new(indicator_id, indicator.display_name, value_text)
		indicator_vms.append(view_model)

	return indicator_vms


func _build_asset_slot_view_models() -> Array[AssetSlotViewModel]:
	var slots: Array[AssetSlotViewModel] = []
	var state := run_state as RunState
	var chosen_ids: Array[String] = []
	if state != null:
		if typeof(state.hand_asset_ids) == TYPE_PACKED_STRING_ARRAY and state.hand_asset_ids != null:
			for id in state.hand_asset_ids:
				chosen_ids.append(str(id))
		elif state.chosen_asset_ids != null:
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


func _prettify_asset_id(asset_id: String) -> String:
	if asset_id == "":
		return ""
	var spaced := asset_id.replace("_", " ").replace("-", " ")
	var parts := spaced.split(" ", false)
	for i in parts.size():
		var part := parts[i]
		if part == "":
			continue
		parts[i] = part.substr(0, 1).to_upper() + part.substr(1).to_lower()
	return " ".join(parts).strip_edges()


func _resolve_asset_display_name(asset_id: String) -> String:
	if asset_id == "":
		return ""
	var asset_db := load(AssetDBPath)
	if asset_db == null or not asset_db.has_method("get_by_id"):
		return _prettify_asset_id(asset_id)
	var asset: Object = asset_db.get_by_id(asset_id)
	if asset == null:
		return _prettify_asset_id(asset_id)
	if "display_name" in asset and asset.display_name != null:
		var display_name := str(asset.display_name)
		if display_name.strip_edges() != "":
			return display_name
	return _prettify_asset_id(asset_id)


func get_asset_display_name(asset_id: String) -> String:
	return _resolve_asset_display_name(asset_id)


func _initialize_indicator_state_for_year(scenario: YearScenario) -> void:
	var state := run_state as RunState
	if state == null:
		return
	if state.current_indicator_levels == null or typeof(state.current_indicator_levels) != TYPE_DICTIONARY:
		state.current_indicator_levels = {}
	if state.current_indicator_percents == null or typeof(state.current_indicator_percents) != TYPE_DICTIONARY:
		state.current_indicator_percents = {}
	if state.indicator_momentum == null or typeof(state.indicator_momentum) != TYPE_DICTIONARY:
		state.indicator_momentum = {}
	state.current_indicator_levels.clear()
	state.current_indicator_percents.clear()
	state.indicator_momentum.clear()

	var indicator_db := load(IndicatorDBPath)
	if indicator_db == null or not indicator_db.has_method("get_by_id"):
		push_warning("ScenarioDrift: cannot initialize indicator state, IndicatorDB missing at %s" % IndicatorDBPath)
		return

	for indicator_id in scenario.indicator_ids:
		if indicator_id == "":
			continue
		var indicator: Object = indicator_db.get_by_id(indicator_id)
		if indicator == null:
			push_warning("ScenarioDrift: indicator '%s' missing in DB during init." % indicator_id)
			continue
		var base_level := scenario.get_level(indicator_id, ScenarioGenerator.LEVEL_MID)
		var start_percent := _pick_start_percent(indicator, base_level, indicator_id)
		state.current_indicator_levels[indicator_id] = base_level
		state.current_indicator_percents[indicator_id] = start_percent
		state.indicator_momentum[indicator_id] = 0.0

	print("ScenarioDrift: init year=%d current_levels=%s" % [scenario.year_index, state.current_indicator_levels])


func _pick_start_percent(indicator, level: int, indicator_id: String) -> float:
	var thresholds: Dictionary = _get_indicator_thresholds(indicator)
	var low_mid: float = float(thresholds.get("low_mid", indicator.mid_value))
	var mid_high: float = float(thresholds.get("mid_high", indicator.mid_value))
	var seed_value := _make_indicator_seed(indicator_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	match level:
		ScenarioGenerator.LEVEL_LOW:
			return rng.randf_range(indicator.low_value, low_mid)
		ScenarioGenerator.LEVEL_HIGH:
			return rng.randf_range(mid_high, indicator.high_value)
		_:
			return rng.randf_range(low_mid, mid_high)


func _apply_monthly_indicator_drift(month_index: int) -> void:
	_ensure_settings_loaded()
	if run_state == null or current_year_scenario == null:
		return
	var state := run_state as RunState
	if state == null:
		return
	if state.current_indicator_levels == null or typeof(state.current_indicator_levels) != TYPE_DICTIONARY:
		state.current_indicator_levels = {}
	if state.current_indicator_percents == null or typeof(state.current_indicator_percents) != TYPE_DICTIONARY:
		state.current_indicator_percents = {}
	if state.indicator_momentum == null or typeof(state.indicator_momentum) != TYPE_DICTIONARY:
		state.indicator_momentum = {}

	var indicator_db := load(IndicatorDBPath)
	if indicator_db == null or not indicator_db.has_method("get_by_id"):
		push_warning("ScenarioDrift: indicator DB unavailable; skipping drift.")
		return

	var indicator_ids: Array[String] = current_year_scenario.indicator_ids
	var step_range: Vector2 = _get_indicator_drift_step_range()
	var _difficulty_text: String = _normalize_drift_difficulty()
	for indicator_id in indicator_ids:
		if indicator_id == "":
			continue
		var indicator: Object = indicator_db.get_by_id(indicator_id)
		if indicator == null:
			push_warning("ScenarioDrift: indicator '%s' missing; skipping drift." % indicator_id)
			continue
		var thresholds: Dictionary = _get_indicator_thresholds(indicator)
		var prev_percent: float = _get_current_indicator_percent(indicator_id, indicator, current_year_scenario)
		var prev_momentum: float = 0.0
		if state.indicator_momentum.has(indicator_id):
			prev_momentum = float(state.indicator_momentum[indicator_id])
		var rng: RandomNumberGenerator = _make_indicator_month_rng(indicator_id, month_index)
		var step_size: float = rng.randf_range(step_range.x, step_range.y)
		var random_delta: float = rng.randf_range(-step_size, step_size)
		var delta: float = random_delta + prev_momentum

		var min_val: float = indicator.low_value
		var max_val: float = indicator.high_value
		var candidate: float = clamp(prev_percent + delta, min_val, max_val)
		if is_equal_approx(candidate, prev_percent):
			if candidate <= min_val:
				delta = abs(step_size)
			elif candidate >= max_val:
				delta = -abs(step_size)
			else:
				delta = step_size if rng.randf() < 0.5 else -step_size
			candidate = clamp(prev_percent + delta, min_val, max_val)

		var new_percent: float = candidate
		var new_momentum: float = lerp(prev_momentum, delta, 0.35)
		var new_level: int = _percent_to_level(new_percent, thresholds)

		state.current_indicator_percents[indicator_id] = new_percent
		state.current_indicator_levels[indicator_id] = new_level
		state.indicator_momentum[indicator_id] = new_momentum
		print("ScenarioDrift: year=%d month=%d %s percent=%.2f level=%d delta=%.2f" % [current_year_index, month_index, indicator_id, new_percent, new_level, delta])


func _get_current_indicator_level(indicator_id: String, scenario: YearScenario) -> int:
	var state := run_state as RunState
	if state != null and state.current_indicator_levels != null and typeof(state.current_indicator_levels) == TYPE_DICTIONARY and state.current_indicator_levels.has(indicator_id):
		return int(state.current_indicator_levels[indicator_id])
	if state != null and state.current_indicator_percents != null and typeof(state.current_indicator_percents) == TYPE_DICTIONARY and state.current_indicator_percents.has(indicator_id):
		var indicator_db := load(IndicatorDBPath)
		if indicator_db != null and indicator_db.has_method("get_by_id"):
			var indicator: Object = indicator_db.get_by_id(indicator_id)
			if indicator != null:
				var thresholds := _get_indicator_thresholds(indicator)
				return _percent_to_level(float(state.current_indicator_percents[indicator_id]), thresholds)
	if scenario != null and scenario.has_method("get_level"):
		return scenario.get_level(indicator_id, ScenarioGenerator.LEVEL_MID)
	return ScenarioGenerator.LEVEL_MID


func _get_indicator_drift_step_range() -> Vector2:
	var normalized := _normalize_drift_difficulty()
	match normalized:
		"easy":
			return Vector2(0.3, 0.7)
		"hard":
			return Vector2(1.5, 3.0)
		_:
			return Vector2(0.7, 1.5)


func _get_indicator_thresholds(indicator) -> Dictionary:
	var low_value: float = indicator.low_value
	var mid_value: float = indicator.mid_value
	var high_value: float = indicator.high_value
	var low_mid: float = (low_value + mid_value) * 0.5
	var mid_high: float = (mid_value + high_value) * 0.5
	return {
		"low_mid": low_mid,
		"mid_high": mid_high,
	}


func _percent_to_level(percent: float, thresholds: Dictionary) -> int:
	var low_mid: float = float(thresholds.get("low_mid", percent))
	var mid_high: float = float(thresholds.get("mid_high", percent))
	if percent < low_mid:
		return ScenarioGenerator.LEVEL_LOW
	elif percent > mid_high:
		return ScenarioGenerator.LEVEL_HIGH
	return ScenarioGenerator.LEVEL_MID


func _get_current_indicator_percent(indicator_id: String, indicator, scenario: YearScenario) -> float:
	if indicator == null:
		return 0.0
	var state := run_state as RunState
	if state != null and state.current_indicator_percents != null and typeof(state.current_indicator_percents) == TYPE_DICTIONARY and state.current_indicator_percents.has(indicator_id):
		return float(state.current_indicator_percents[indicator_id])
	if scenario != null:
		var level := scenario.get_level(indicator_id, ScenarioGenerator.LEVEL_MID)
		return _pick_start_percent(indicator, level, indicator_id)
	return float(indicator.mid_value)


func _make_indicator_month_rng(indicator_id: String, month_index: int) -> RandomNumberGenerator:
	var id_hash: int = hash(indicator_id)
	var mixed: int = int((run_seed * 92821) ^ (current_year_index * 68917) ^ (month_index * 131071) ^ id_hash)
	if mixed == 0:
		mixed = id_hash ^ 54321
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = abs(mixed)
	return rng


func _normalize_drift_difficulty() -> String:
	var diff_text: String = _settings.difficulty if _settings else "medium"
	var normalized := diff_text.to_lower()
	if normalized == "normal":
		normalized = "medium"
	if normalized != "easy" and normalized != "medium" and normalized != "hard":
		return "medium"
	return normalized


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


func _has_match_started(state: RunState) -> bool:
	if state == null:
		return false
	_ensure_state_currency_in_cents(state)
	var started: bool = state.match_started
	var reduced_unallocated := int(state.unallocated_funds) < int(get_yearly_contribution_cents())
	var allocated_any := false
	if state.allocated_by_asset != null and typeof(state.allocated_by_asset) == TYPE_DICTIONARY:
		for value in state.allocated_by_asset.values():
			if int(value) > 0:
				allocated_any = true
				break
	if (allocated_any or reduced_unallocated) and not started:
		started = true
		state.match_started = true
	return started


func _compute_total_value(state: RunState, allocations: Variant = null, unallocated_override: Variant = null) -> int:
	if state == null:
		return 0
	_ensure_portfolio_initialized(state)
	var portfolio: Dictionary = {}
	if state.portfolio_cents_by_asset_id != null and typeof(state.portfolio_cents_by_asset_id) == TYPE_DICTIONARY:
		portfolio = state.portfolio_cents_by_asset_id.duplicate()
	if allocations != null and typeof(allocations) == TYPE_DICTIONARY:
		for asset_id in allocations.keys():
			portfolio[asset_id] = allocations[asset_id]

	var unallocated_value := int(round(unallocated_override)) if unallocated_override != null else int(round(state.unallocated_funds))
	var total := unallocated_value
	for value in portfolio.values():
		total += int(round(value))
	return int(total)


func _record_allocation_stat(asset_id: String) -> void:
	if session_mode != SessionMode.RUN:
		return
	_ensure_profile_stats_loaded()
	_profile_stats.total_allocations_made += 1
	if _profile_stats.asset_allocation_counts == null or typeof(_profile_stats.asset_allocation_counts) != TYPE_DICTIONARY:
		_profile_stats.asset_allocation_counts = {}
	if asset_id != "":
		var previous := int(_profile_stats.asset_allocation_counts.get(asset_id, 0))
		var new_count := previous + 1
		_profile_stats.asset_allocation_counts[asset_id] = new_count
		_update_favorite_asset(asset_id, new_count)
	print("GameManager: allocation stat incremented")
	_persist_profile_stats()


func _update_favorite_asset(asset_id: String, new_count: int) -> void:
	if asset_id == "":
		return
	var current_id: String = _profile_stats.favorite_asset_id if _profile_stats != null else ""
	var counts: Dictionary = _profile_stats.asset_allocation_counts if _profile_stats != null else {}
	var current_count := -1
	if current_id != "" and typeof(counts) == TYPE_DICTIONARY:
		current_count = int(counts.get(current_id, -1))
	if current_id == "":
		_profile_stats.favorite_asset_id = asset_id
		print("GameManager: favorite asset updated to %s" % asset_id)
		return
	if new_count > current_count:
		_profile_stats.favorite_asset_id = asset_id
		print("GameManager: favorite asset updated to %s" % asset_id)


func _record_indicator_exposure(indicator_ids: Array) -> void:
	if session_mode != SessionMode.RUN:
		return
	if indicator_ids == null:
		return
	_ensure_profile_stats_loaded()
	if _profile_stats.indicator_exposure_counts == null or typeof(_profile_stats.indicator_exposure_counts) != TYPE_DICTIONARY:
		_profile_stats.indicator_exposure_counts = {}
	for indicator_id in indicator_ids:
		var normalized_id := str(indicator_id)
		if normalized_id == "":
			continue
		var prev := int(_profile_stats.indicator_exposure_counts.get(normalized_id, 0))
		_profile_stats.indicator_exposure_counts[normalized_id] = prev + 1
	_persist_profile_stats()


func _build_end_year_summary(state: RunState, start_total: int, end_total: int) -> Dictionary:
	var start_assets: Dictionary = {}
	if state.year_start_asset_cents != null and typeof(state.year_start_asset_cents) == TYPE_DICTIONARY:
		start_assets = state.year_start_asset_cents.duplicate()
	var end_assets: Dictionary = {}
	if state.portfolio_cents_by_asset_id != null and typeof(state.portfolio_cents_by_asset_id) == TYPE_DICTIONARY:
		for asset_id in state.portfolio_cents_by_asset_id.keys():
			var normalized := str(asset_id)
			if normalized == "":
				continue
			end_assets[normalized] = int(round(state.portfolio_cents_by_asset_id.get(asset_id, 0)))

	var asset_ids: Array[String] = []
	for key in start_assets.keys():
		var normalized := str(key)
		if normalized != "" and not asset_ids.has(normalized):
			asset_ids.append(normalized)
	for key in end_assets.keys():
		var normalized := str(key)
		if normalized != "" and not asset_ids.has(normalized):
			asset_ids.append(normalized)

	var best_id := ""
	var best_delta := 0
	var worst_id := ""
	var worst_delta := 0
	for asset_id in asset_ids:
		var start_value := int(start_assets.get(asset_id, 0))
		var end_value := int(end_assets.get(asset_id, 0))
		var delta := end_value - start_value
		if best_id == "" or delta > best_delta:
			best_id = asset_id
			best_delta = delta
		if worst_id == "" or delta < worst_delta:
			worst_id = asset_id
			worst_delta = delta

	return {
		"year_index": state.current_year_index,
		"net_cents": end_total - start_total,
		"best_asset_id": best_id,
		"best_asset_delta_cents": best_delta,
		"worst_asset_id": worst_id,
		"worst_asset_delta_cents": worst_delta,
	}


func _maybe_record_year_result(state: RunState) -> void:
	if session_mode != SessionMode.RUN:
		return
	if state == null:
		return
	if state.current_month < MONTHS_PER_YEAR:
		return
	_ensure_profile_stats_loaded()
	_ensure_state_currency_in_cents(state)
	var start_total := int(state.year_start_total_cents) if "year_start_total_cents" in state else _compute_total_value(state)
	var end_total := _compute_total_value(state)
	var delta := end_total - start_total
	state.last_year_summary = _build_end_year_summary(state, start_total, end_total)
	var summary: Dictionary = state.last_year_summary if state.last_year_summary != null else {}
	delta = int(summary.get("net_cents", delta))
	print("GameManager: end-year summary -> net=%s best=%s (%s) worst=%s (%s)" % [
		_format_currency(int(summary.get("net_cents", delta))),
		str(summary.get("best_asset_id", "")),
		_format_currency(int(summary.get("best_asset_delta_cents", 0))),
		str(summary.get("worst_asset_id", "")),
		_format_currency(int(summary.get("worst_asset_delta_cents", 0))),
	])
	var updated := false
	if delta > _profile_stats.biggest_year_gain_cents:
		_profile_stats.biggest_year_gain_cents = delta
		updated = true
		print("GameManager: biggest yearly gain updated to %s" % delta)
	if delta < _profile_stats.biggest_year_loss_cents:
		_profile_stats.biggest_year_loss_cents = delta
		updated = true
		print("GameManager: biggest yearly loss updated to %s" % delta)
	if updated:
		_persist_profile_stats()


func _update_profile_stats_for_run_completion() -> void:
	if session_mode != SessionMode.RUN:
		return
	if _run_completion_recorded:
		return
	_ensure_profile_stats_loaded()
	_profile_stats.total_runs_completed += 1
	var final_total_cents := 0
	var state := run_state as RunState
	if state != null:
		_ensure_state_currency_in_cents(state)
		final_total_cents = _compute_total_value(state)
	if final_total_cents > _profile_stats.best_run_total_cents:
		_profile_stats.best_run_total_cents = final_total_cents
	_run_completion_recorded = true
	print("GameManager: run completed, stats updated")
	_persist_profile_stats()


func _ensure_behavior_matrix_loaded() -> void:
	if _behavior_matrix != null:
		return
	var loaded := load(BehaviorMatrixPath)
	if loaded == null or not (loaded is BehaviorMatrix):
		push_warning("GameManager: failed to load BehaviorMatrix at %s" % BehaviorMatrixPath)
		_behavior_matrix = null
		return
	_behavior_matrix = loaded
	if _behavior_matrix.has_method("rebuild_index"):
		_behavior_matrix.rebuild_index()

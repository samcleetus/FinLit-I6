extends Control

const IndicatorDBPath := "res://Resources/IndicatorDB.tres"

var _indicator_flow: Node = null
var _indicator_template: Control = null
var _indicator_db: IndicatorDB = null


func _ready() -> void:
	var mode := GameManager.get_session_mode()
	var state: RunState = GameManager.get_run_state()
	var run_id: String = state.run_id if state else "none"
	print("Match: _ready -> session_mode=%s run_id=%s" % [_session_mode_to_string(mode), run_id])
	_cache_indicator_nodes()
	_load_indicator_db()
	_render_current_scenario()
	GameManager.get_match_view_model()


func _session_mode_to_string(mode: int) -> String:
	match mode:
		GameManager.SessionMode.RUN:
			return "RUN"
		GameManager.SessionMode.PRACTICE:
			return "PRACTICE"
		GameManager.SessionMode.NONE:
			return "NONE"
		_:
			return "UNKNOWN"


func _on_next_year_button_pressed() -> void:
	var advanced: bool = GameManager.advance_year()
	if not advanced:
		print("Match: cannot advance year (run complete)")
		return
	_render_current_scenario()


func _render_current_scenario() -> void:
	var scenario: YearScenario = GameManager.current_year_scenario
	if scenario == null:
		push_error("Match: current_year_scenario missing; ensure a run was prepared before entering Match.")
		return
	if _indicator_flow == null or _indicator_template == null:
		push_error("Match: indicator container/template missing.")
		return

	_indicator_template.visible = false
	_clear_indicator_panels()

	var rendered := 0
	for indicator_id in scenario.indicator_ids:
		var indicator := _get_indicator_by_id(indicator_id)
		if indicator == null:
			continue
		var level := scenario.get_level(indicator_id, 1)
		var value := _level_to_value(level, indicator)
		var panel := _indicator_template.duplicate()
		panel.visible = true
		panel.name = "IndicatorPanel_%s" % indicator_id
		_indicator_flow.add_child(panel)
		var label := panel.get_node_or_null("IndicatorLabel") as Label
		if label:
			label.text = "    %s: %d%%   " % [indicator.display_name, int(round(value))]
		rendered += 1

	print("Match: rendered indicators %s" % rendered)


func _clear_indicator_panels() -> void:
	for child in _indicator_flow.get_children():
		if child == _indicator_template:
			continue
		child.queue_free()


func _cache_indicator_nodes() -> void:
	_indicator_flow = get_node_or_null("LabelVBox/IndicatorContainer/IndicatorFlow")
	if _indicator_flow == null:
		push_error("Match: missing LabelVBox/IndicatorContainer/IndicatorFlow.")
		return
	_indicator_template = _indicator_flow.get_node_or_null("IndicatorPanel") as Control
	if _indicator_template == null:
		for child in _indicator_flow.get_children():
			if child is Control:
				_indicator_template = child
				break
	if _indicator_template == null:
		push_error("Match: missing IndicatorPanel template.")
		return
	_indicator_template.visible = false


func _load_indicator_db() -> void:
	if _indicator_db != null:
		return
	var indicator_db := load(IndicatorDBPath)
	if indicator_db == null:
		push_error("Match: Failed to load IndicatorDB at %s" % IndicatorDBPath)
		return
	_indicator_db = indicator_db


func _get_indicator_by_id(indicator_id: String) -> Indicator:
	if _indicator_db == null:
		return null
	if _indicator_db.has_method("get_by_id"):
		return _indicator_db.get_by_id(indicator_id)
	return null


func _level_to_value(level: int, indicator: Indicator) -> float:
	var low := indicator.low_value
	var mid := indicator.mid_value
	var high := indicator.high_value
	match level:
		0:
			return (low + mid) * 0.5
		2:
			return (mid + high) * 0.5
		_:
			return mid

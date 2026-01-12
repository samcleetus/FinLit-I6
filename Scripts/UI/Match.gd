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
	var vm := GameManager.get_match_view_model()
	_render_from_view_model(vm)
	_render_assets_from_view_model(vm)


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
	var vm := GameManager.get_match_view_model()
	_render_from_view_model(vm)
	_render_assets_from_view_model(vm)


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


func _render_from_view_model(vm: MatchViewModel) -> void:
	if vm == null:
		push_error("Match: view model is null.")
		return
	if _indicator_flow == null or _indicator_template == null:
		push_error("Match: indicator container/template missing.")
		return

	_indicator_template.visible = false
	_clear_indicator_panels()

	var rendered := 0
	for indicator_vm in vm.indicators:
		if indicator_vm == null:
			continue
		var panel := _indicator_template.duplicate()
		panel.visible = true
		panel.name = "IndicatorPanel_%s" % indicator_vm.indicator_id
		_indicator_flow.add_child(panel)
		var label := panel.get_node_or_null("IndicatorLabel") as Label
		if label:
			var text := indicator_vm.value_text
			if text == "" and indicator_vm.display_name != "":
				text = indicator_vm.display_name
			label.text = text
		rendered += 1

	print("Match: rendered indicators %s" % rendered)


func _render_assets_from_view_model(vm: MatchViewModel) -> void:
	if vm == null:
		push_error("Match: view model is null; cannot render assets.")
		return
	if vm.asset_slots.size() < 4:
		push_warning("Match: asset slots missing entries; expected 4, got %d." % vm.asset_slots.size())

	var applied := 0
	for slot_vm in vm.asset_slots:
		if slot_vm == null:
			continue
		var node_path := _asset_node_path_for_index(slot_vm.slot_index)
		if node_path == "":
			push_warning("Match: unknown asset slot index %d." % slot_vm.slot_index)
			continue
		var asset_node := get_node_or_null(node_path)
		if asset_node == null:
			push_warning("Match: missing asset node at path %s." % node_path)
			continue
		var asset_image := asset_node.get_node_or_null("AssetImage")
		if asset_image == null:
			asset_image = asset_node.get_node_or_null("AssetVBox/AssetImage")
		var asset_name_label := asset_node.get_node_or_null("AssetNameLabel")
		if asset_name_label == null:
			asset_name_label = asset_node.get_node_or_null("AssetVBox/AssetNameLabel")
		if asset_image == null:
			push_warning("Match: missing AssetImage under %s." % node_path)
			continue
		if slot_vm.icon == null:
			push_warning("Match: asset slot %d missing icon for asset '%s'." % [slot_vm.slot_index, slot_vm.asset_id])
			continue
		if asset_image.has_method("set_texture"):
			asset_image.set_texture(slot_vm.icon)
			applied += 1
		elif asset_image is TextureRect or asset_image is Sprite2D:
			asset_image.texture = slot_vm.icon
			applied += 1
		else:
			push_warning("Match: AssetImage under %s does not support texture assignment." % node_path)
		if asset_name_label is Label:
			asset_name_label.text = slot_vm.display_name

	print("Match: rendered assets %d" % applied)


func _asset_node_path_for_index(slot_index: int) -> String:
	match slot_index:
		1:
			return "Arena/AnimalAsset1"
		2:
			return "Arena/AnimalAsset2"
		3:
			return "Arena/AnimalAsset3"
		4:
			return "Arena/AnimalAsset4"
		_:
			return ""

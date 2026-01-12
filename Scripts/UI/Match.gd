extends Control

const IndicatorDBPath := "res://Resources/IndicatorDB.tres"
const DRAG_THRESHOLD_PX := 12
const REALLOC_AMOUNT := 1000
const ALLOC_AMOUNT := 1000

var _indicator_flow: Node = null
var _indicator_template: Control = null
var _indicator_db: IndicatorDB = null
var _asset_slots: Array = []
var _asset_signals_connected: bool = false
var _pointer_down_asset_id: String = ""
var _pointer_down_pos: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_consumed: bool = false


func _ready() -> void:
	var mode := GameManager.get_session_mode()
	var state: RunState = GameManager.get_run_state()
	var run_id: String = state.run_id if state else "none"
	print("Match: _ready -> session_mode=%s run_id=%s" % [_session_mode_to_string(mode), run_id])
	_cache_indicator_nodes()
	_cache_asset_slots()
	var vm := GameManager.get_match_view_model()
	_render_from_view_model(vm)
	_apply_assets_to_fixed_slots(vm)


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


func _on_asset_pressed(asset_id: String) -> void:
	if asset_id == "":
		print("Match: asset pressed with empty asset id")
		return
	print("Match: tap allocate -> %s" % asset_id)
	GameManager.allocate_to_asset(asset_id, ALLOC_AMOUNT)


func _start_pointer_cycle(asset_id: String, global_pos: Vector2) -> void:
	_pointer_down_asset_id = asset_id
	_pointer_down_pos = global_pos
	_dragging = false
	_drag_consumed = false


func _update_drag_state(global_pos: Vector2) -> void:
	if _pointer_down_asset_id == "":
		return
	if _dragging:
		return
	if _pointer_down_pos.distance_to(global_pos) > DRAG_THRESHOLD_PX:
		_dragging = true
		_drag_consumed = true
		print("Match: drag start -> %s" % _pointer_down_asset_id)


func _finish_pointer_cycle(asset_id: String, global_pos: Vector2) -> void:
	var from_asset_id := _pointer_down_asset_id
	var log_id := from_asset_id if from_asset_id != "" else asset_id
	var was_drag := _dragging
	print("Match: input up received for %s dragging=%s" % [log_id, was_drag])
	if from_asset_id == "":
		_pointer_down_asset_id = ""
		_pointer_down_pos = Vector2.ZERO
		_dragging = false
		_drag_consumed = false
		return
	_pointer_down_asset_id = ""
	_pointer_down_pos = Vector2.ZERO
	_dragging = false
	_drag_consumed = false

	if was_drag:
		var target_asset_id := _find_asset_under_position(global_pos)
		if target_asset_id != "" and target_asset_id != from_asset_id:
			print("Match: drag drop -> %s -> %s" % [from_asset_id, target_asset_id])
			GameManager.reallocate(from_asset_id, target_asset_id, REALLOC_AMOUNT)
		else:
			print("Match: drag cancel")
		return

	print("Match: tap allocate -> %s" % from_asset_id)
	GameManager.allocate_to_asset(from_asset_id, ALLOC_AMOUNT)


func _find_asset_under_position(global_pos: Vector2) -> String:
	_cache_asset_slots()
	for slot_data in _asset_slots:
		var hit_control: Control = slot_data.get("button")
		if hit_control == null:
			hit_control = slot_data.get("node")
		if hit_control == null:
			continue
		var rect := hit_control.get_global_rect()
		if rect.has_point(global_pos):
			var asset_id := _get_asset_id(slot_data.get("node"))
			if asset_id != "":
				return asset_id
	return ""


func _get_asset_id(asset_node: Node) -> String:
	if asset_node == null:
		return ""
	var raw_id = asset_node.get("asset_id")
	return "" if raw_id == null else str(raw_id)


func _event_to_global(event: InputEvent, asset_node: Control) -> Vector2:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	if event is InputEventMouse:
		return (event as InputEventMouse).global_position
	if "global_position" in event:
		return event.global_position
	if "position" in event and asset_node != null:
		return asset_node.get_global_transform_with_canvas() * event.position
	return Vector2.ZERO


func _on_next_year_button_pressed() -> void:
	var advanced: bool = GameManager.advance_year()
	if not advanced:
		print("Match: cannot advance year (run complete)")
		return
	var vm := GameManager.get_match_view_model()
	_render_from_view_model(vm)
	_apply_assets_to_fixed_slots(vm)


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


func _cache_asset_slots() -> void:
	if not _asset_slots.is_empty():
		_connect_asset_slot_signals()
		return
	var arena := get_node_or_null("Arena")
	if arena == null:
		push_error("Match: missing Arena node.")
		return
	var node_names := ["AnimalAsset1", "AnimalAsset2", "AnimalAsset3", "AnimalAsset4"]
	for i in node_names.size():
		var slot_index := i + 1
		var asset_node := arena.get_node_or_null(node_names[i])
		if asset_node == null:
			push_warning("Match: missing asset node %s under Arena." % node_names[i])
			_asset_slots.append({
				"slot_index": slot_index,
				"node": null,
				"image": null,
				"name_label": null,
				"value_label": null,
				"button": null,
			})
			continue
		var asset_image := asset_node.get_node_or_null("AssetImage")
		if asset_image == null:
			asset_image = asset_node.get_node_or_null("AssetVBox/AssetImage")
		var asset_name_label := asset_node.get_node_or_null("AssetNameLabel")
		if asset_name_label == null:
			asset_name_label = asset_node.get_node_or_null("AssetVBox/AssetNameLabel")
		var asset_value_label := asset_node.get_node_or_null("AssetValueLabel")
		if asset_value_label == null:
			asset_value_label = asset_node.get_node_or_null("AssetVBox/AssetValueLabel")
		var hit_button: Button = asset_node.get_node_or_null("HitButton")
		if hit_button == null:
			hit_button = asset_node.get_node_or_null("Button")
		_asset_slots.append({
			"slot_index": slot_index,
			"node": asset_node,
			"image": asset_image,
			"name_label": asset_name_label,
			"value_label": asset_value_label,
			"button": hit_button,
		})
	_connect_asset_slot_signals()


func _on_asset_gui_input(event: InputEvent, asset_node: Control) -> void:
	if asset_node == null:
		return
	var asset_id := _get_asset_id(asset_node)
	if asset_id == "":
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_start_pointer_cycle(asset_id, _event_to_global(mouse_event, asset_node))
		else:
			_finish_pointer_cycle(asset_id, _event_to_global(mouse_event, asset_node))
		return

	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_start_pointer_cycle(asset_id, _event_to_global(touch_event, asset_node))
		else:
			_finish_pointer_cycle(asset_id, _event_to_global(touch_event, asset_node))
		return

	if event is InputEventMouseMotion:
		if _pointer_down_asset_id == "":
			return
		var motion_event := event as InputEventMouseMotion
		if (motion_event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		_update_drag_state(_event_to_global(motion_event, asset_node))
		return

	if event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		_update_drag_state(_event_to_global(drag_event, asset_node))


func _connect_asset_slot_signals() -> void:
	if _asset_signals_connected:
		return
	for slot_data in _asset_slots:
		var asset_node: Node = slot_data.get("node")
		var hit_button: Button = slot_data.get("button")
		if asset_node == null or hit_button == null:
			continue
		var press_callable := Callable(self, "_handle_asset_button_pressed").bind(asset_node)
		if not hit_button.pressed.is_connected(press_callable):
			hit_button.pressed.connect(press_callable)
		var gui_callable := Callable(self, "_on_asset_gui_input").bind(asset_node)
		if not hit_button.gui_input.is_connected(gui_callable):
			hit_button.gui_input.connect(gui_callable)
	_asset_signals_connected = true


func _handle_asset_button_pressed(_asset_node: Node) -> void:
	# Pressed connections are retained but input handling is done via gui_input.
	return


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


func _apply_assets_to_fixed_slots(vm: MatchViewModel) -> void:
	if vm == null:
		push_error("Match: view model is null; cannot render assets.")
		return
	_cache_asset_slots()
	if _asset_slots.is_empty():
		push_error("Match: asset slot cache is empty; cannot render assets.")
		return
	if vm.asset_slots.size() < 4:
		push_warning("Match: asset slots missing entries; expected 4, got %d." % vm.asset_slots.size())

	var applied := 0
	for slot_vm in vm.asset_slots:
		if slot_vm == null:
			continue
		if slot_vm.slot_index <= 0:
			push_warning("Match: invalid asset slot index %d." % slot_vm.slot_index)
			continue
		var slot_idx := slot_vm.slot_index - 1
		if slot_idx >= _asset_slots.size():
			push_warning("Match: unknown asset slot index %d." % slot_vm.slot_index)
			continue
		var slot_data: Dictionary = _asset_slots[slot_idx]
		var asset_node: Node = slot_data.get("node")
		if asset_node == null:
			push_warning("Match: missing asset node for slot %d." % slot_vm.slot_index)
			continue
		var asset_image: Variant = slot_data.get("image")
		var asset_name_label: Variant = slot_data.get("name_label")
		asset_node.set("asset_id", slot_vm.asset_id)
		if asset_image == null:
			push_warning("Match: missing AssetImage under slot %d." % slot_vm.slot_index)
		elif slot_vm.icon == null:
			push_warning("Match: asset slot %d missing icon for asset '%s'." % [slot_vm.slot_index, slot_vm.asset_id])
		elif asset_image.has_method("set_texture"):
			asset_image.set_texture(slot_vm.icon)
			applied += 1
		elif asset_image is TextureRect or asset_image is Sprite2D:
			asset_image.texture = slot_vm.icon
			applied += 1
		else:
			push_warning("Match: AssetImage for slot %d does not support texture assignment." % slot_vm.slot_index)
		if asset_name_label is Label:
			asset_name_label.text = slot_vm.display_name
		if asset_node.has_method("set_selected"):
			asset_node.call("set_selected", false)

	print("Match: rendered assets %d" % applied)


func _render_assets_from_view_model(vm: MatchViewModel) -> void:
	_apply_assets_to_fixed_slots(vm)

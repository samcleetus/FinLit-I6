extends Control

@onready var _dimmer: ColorRect = get_node_or_null("Dimmer")
@onready var _title_label: Label = get_node_or_null("Panel/Margin/VBox/TitleLabel")
@onready var _duration_label: Label = get_node_or_null("Panel/Margin/VBox/DurationLabel")
@onready var _good_label: Label = get_node_or_null("Panel/Margin/VBox/GoodLabel")
@onready var _bad_label: Label = get_node_or_null("Panel/Margin/VBox/BadLabel")
@onready var _close_button: Button = get_node_or_null("Panel/Margin/VBox/CloseButton")

const BehaviorMatrixPath := "res://Resources/BehaviorMatrix.tres"
const IndicatorDBPath := "res://Resources/IndicatorDB.tres"


func _ready() -> void:
	visible = false
	if _dimmer:
		_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		if not _dimmer.gui_input.is_connected(Callable(self, "_on_dimmer_input")):
			_dimmer.gui_input.connect(Callable(self, "_on_dimmer_input"))
	if _close_button and not _close_button.pressed.is_connected(Callable(self, "hide_overlay")):
		_close_button.pressed.connect(Callable(self, "hide_overlay"))


func show_asset(asset_id: String, asset_data: Variant = null) -> void:
	var name_text := GameManager.get_asset_display_name(asset_id)
	if name_text == "":
		name_text = asset_id
	var duration_years := 0
	if asset_data != null and asset_data is Object and "duration_years" in asset_data:
		duration_years = int(asset_data.duration_years)
	if asset_data != null and typeof(asset_data) == TYPE_DICTIONARY and asset_data.has("duration_years"):
		duration_years = int(asset_data["duration_years"])

	var duration_text := "Duration: %d years" % max(duration_years, 0)
	var good_list: Array[String] = []
	var bad_list: Array[String] = []
	_extract_behavior_lists(asset_id, good_list, bad_list)

	if _title_label:
		_title_label.text = name_text
	if _duration_label:
		_duration_label.text = duration_text
	if _good_label:
		_good_label.text = "Performs well when: %s" % _format_list_or_placeholder(good_list)
	if _bad_label:
		_bad_label.text = "Performs badly when: %s" % _format_list_or_placeholder(bad_list)

	visible = true
	print("AssetDetailsOverlay: opened for %s (locked=%s)" % [asset_id, _is_locked_asset(asset_data)])


func hide_overlay() -> void:
	visible = false


func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		hide_overlay()
	elif event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		hide_overlay()


func _extract_behavior_lists(asset_id: String, good_list: Array[String], bad_list: Array[String]) -> void:
	var behavior := load(BehaviorMatrixPath)
	if behavior == null or not behavior.has_method("rebuild_index"):
		return
	behavior.rebuild_index()
	var indicator_db := load(IndicatorDBPath)
	for rule in behavior.rules:
		if rule == null or not ("asset_id" in rule) or not ("indicator_id" in rule):
			continue
		if str(rule.asset_id) != asset_id:
			continue
		var indicator_id := str(rule.indicator_id)
		if indicator_id == "":
			continue
		var indicator_name := _resolve_indicator_name(indicator_db, indicator_id)
		if "low_effect" in rule:
			var low_effect := int(rule.low_effect)
			if low_effect > 0:
				good_list.append("%s (low)" % indicator_name)
			elif low_effect < 0:
				bad_list.append("%s (low)" % indicator_name)
		if "high_effect" in rule:
			var high_effect := int(rule.high_effect)
			if high_effect > 0:
				good_list.append("%s (high)" % indicator_name)
			elif high_effect < 0:
				bad_list.append("%s (high)" % indicator_name)


func _resolve_indicator_name(indicator_db: Variant, indicator_id: String) -> String:
	if indicator_db == null or not indicator_db.has_method("get_by_id"):
		return indicator_id
	var indicator: Variant = indicator_db.get_by_id(indicator_id)
	if indicator == null:
		return indicator_id
	if "display_name" in indicator and indicator.display_name != null and str(indicator.display_name).strip_edges() != "":
		return str(indicator.display_name)
	return indicator_id


func _format_list_or_placeholder(values: Array[String]) -> String:
	if values.is_empty():
		return "(coming soon)"
	return ", ".join(values)


func _is_locked_asset(asset_data: Variant) -> bool:
	if asset_data == null:
		return false
	if asset_data is Object and "starting_unlocked" in asset_data:
		return not bool(asset_data.starting_unlocked)
	if typeof(asset_data) == TYPE_DICTIONARY and asset_data.has("starting_unlocked"):
		return not bool(asset_data["starting_unlocked"])
	return false

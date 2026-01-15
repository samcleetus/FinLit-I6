extends Control

const AssetDBPath := "res://Resources/AssetDB.tres"
const AssetCardScenePath := "res://Scenes/UI/AssetCard.tscn"
const AssetDetailsOverlayPath := "res://Scenes/Game/AssetDetailsOverlay.tscn"
const BehaviorMatrixPath := "res://Resources/BehaviorMatrix.tres"
const IndicatorDBPath := "res://Resources/IndicatorDB.tres"

var _asset_grid: GridContainer
var _asset_overlay: Control
var _asset_by_id: Dictionary = {}
var _asset_locked_by_id: Dictionary = {}
var _pressed_panel: Control
var _close_button: Button
var _asset_name_label: Label
var _best_value_label: Label
var _worst_value_label: Label
var _duration_value_label: Label
var _description_value_label: Label


func _ready() -> void:
	print("Collection: Collection ready")
	_cache_nodes()
	_setup_nav_button("ButtonsRow/CollectionButton", "CollectionButton", func() -> void: GameManager.go_to_collection(), true)
	_setup_nav_button("ButtonsRow/MainMenuButton", "MainMenuButton", func() -> void: GameManager.go_to_main_menu())
	_setup_nav_button("ButtonsRow/ProfileButton", "ProfileButton", func() -> void: GameManager.go_to_profile())
	_setup_nav_button("ButtonsRow/SettingsButton", "SettingsButton", func() -> void: GameManager.go_to_settings())
	_setup_pressed_panel()
	_set_title()
	_build_asset_grid()


func _cache_nodes() -> void:
	_asset_grid = get_node_or_null("AssetScroll/AssetGridCenter/AssetGrid") as GridContainer
	_pressed_panel = get_node_or_null("PressedAssetPanel") as Control
	_close_button = get_node_or_null("PressedAssetPanel/StatsVBox/CloseButton") as Button
	_asset_name_label = get_node_or_null("PressedAssetPanel/StatsVBox/ContentRow1/AssetNameLabel") as Label
	_best_value_label = get_node_or_null("PressedAssetPanel/StatsVBox/ContentRow2/ValueLabel") as Label
	_worst_value_label = get_node_or_null("PressedAssetPanel/StatsVBox/ContentRow3/ValueLabel") as Label
	_duration_value_label = get_node_or_null("PressedAssetPanel/StatsVBox/ContentRow4/ValueLabel") as Label
	_description_value_label = get_node_or_null("PressedAssetPanel/StatsVBox/ContentRow5/ValueLabel") as Label


func _setup_nav_button(path: String, label: String, callback: Callable = Callable(), disable: bool = false) -> void:
	var node := get_node_or_null(path)
	if node == null:
		print("Collection: Missing %s at path %s" % [label, path])
		return
	var button := node as Button
	if button == null:
		print("Collection: Node at %s is not a Button" % path)
		return
	button.disabled = disable
	if not callback.is_null():
		button.pressed.connect(callback)


func _setup_pressed_panel() -> void:
	if _pressed_panel:
		_pressed_panel.visible = false
		_pressed_panel.z_index = 999
	if _close_button and not _close_button.pressed.is_connected(Callable(self, "_on_close_pressed")):
		_close_button.pressed.connect(Callable(self, "_on_close_pressed"))


func _set_title() -> void:
	var title_label := get_node_or_null("TitleVBox/TitleLabel") as Label
	if title_label:
		title_label.text = "Collection"


func _build_asset_grid() -> void:
	if _asset_grid == null:
		print("Collection: Missing AssetGrid; cannot populate collection.")
		return
	for child in _asset_grid.get_children():
		child.queue_free()

	var asset_db := load(AssetDBPath)
	if asset_db == null or not asset_db.has_method("get_all"):
		push_error("Collection: Failed to load AssetDB at %s" % AssetDBPath)
		return
	var card_scene := load(AssetCardScenePath) as PackedScene
	if card_scene == null:
		push_error("Collection: Failed to load AssetCard scene at %s" % AssetCardScenePath)
		return

	_asset_by_id.clear()
	_asset_locked_by_id.clear()
	var assets: Array = asset_db.get_all()
	var added := 0
	for asset in assets:
		if asset == null or not ("id" in asset) or str(asset.id) == "":
			continue
		var asset_id := str(asset.id)
		_asset_by_id[asset_id] = asset
		var card_instance := card_scene.instantiate()
		if card_instance == null:
			continue
		_asset_grid.add_child(card_instance)
		if card_instance.has_method("apply_asset"):
			card_instance.apply_asset(asset)
		var is_locked: bool = not (asset != null and "starting_unlocked" in asset and asset.starting_unlocked)
		_asset_locked_by_id[asset_id] = is_locked
		if card_instance.has_method("set_locked"):
			card_instance.set_locked(is_locked)
		if card_instance.has_signal("pressed"):
			var callable := Callable(self, "_on_asset_pressed")
			if not card_instance.pressed.is_connected(callable):
				card_instance.pressed.connect(callable)
		added += 1

	print("Collection: rendered %s assets" % added)


func _on_asset_pressed(asset_id: String) -> void:
	var locked := bool(_asset_locked_by_id.get(asset_id, false))
	print("Collection: asset tapped -> %s locked=%s" % [asset_id, locked])
	var asset_data: Variant = _asset_by_id.get(asset_id, null)
	open_asset_details(asset_id, asset_data)


func _ensure_overlay() -> void:
	if _asset_overlay != null:
		return
	var overlay_scene := load(AssetDetailsOverlayPath) as PackedScene
	if overlay_scene == null:
		push_error("Collection: Failed to load AssetDetailsOverlay at %s" % AssetDetailsOverlayPath)
		return
	_asset_overlay = overlay_scene.instantiate()
	if _asset_overlay == null:
		push_error("Collection: Failed to instantiate AssetDetailsOverlay.")
		return
	add_child(_asset_overlay)
	_asset_overlay.visible = false


func open_asset_details(asset_id: String, asset_data: Variant = null) -> void:
	if _pressed_panel == null:
		print("Collection: PressedAssetPanel missing; cannot show details.")
		return
	if asset_data == null:
		asset_data = _lookup_asset(asset_id)
	var display_name := GameManager.get_asset_display_name(asset_id)
	if asset_data != null and "display_name" in asset_data and str(asset_data.display_name).strip_edges() != "":
		display_name = str(asset_data.display_name)
	if _asset_name_label:
		_asset_name_label.text = display_name

	var best_worst := _compute_best_worst_texts(asset_id)
	if _best_value_label:
		_best_value_label.text = best_worst.get("best", "Coming soon")
	if _worst_value_label:
		_worst_value_label.text = best_worst.get("worst", "Coming soon")

	var duration_years := 0
	if asset_data != null and "duration_years" in asset_data:
		duration_years = int(asset_data.duration_years)
	if _duration_value_label:
		_duration_value_label.text = "%d year(s)" % max(duration_years, 0)

	if _description_value_label:
		var desc_text := ""
		if asset_data != null and "description" in asset_data:
			desc_text = str(asset_data.description).strip_edges()
		_description_value_label.text = desc_text if desc_text != "" else "Coming soon"

	_pressed_panel.visible = true
	if _pressed_panel.has_method("raise"):
		_pressed_panel.call("raise")
	elif _pressed_panel.has_method("move_to_front"):
		_pressed_panel.call("move_to_front")
	else:
		_pressed_panel.z_index = 999
	print("Collection: open_asset_details -> %s" % asset_id)


func _on_close_pressed() -> void:
	if _pressed_panel:
		_pressed_panel.visible = false
	print("Collection: close_asset_details")


func _lookup_asset(asset_id: String) -> Variant:
	if _asset_by_id.has(asset_id):
		return _asset_by_id[asset_id]
	var db := load(AssetDBPath)
	if db != null and db.has_method("get_by_id"):
		return db.get_by_id(asset_id)
	return null


func _compute_best_worst_texts(asset_id: String) -> Dictionary:
	var result := {"best": "Coming soon", "worst": "Coming soon"}
	if asset_id == "":
		return result
	var behavior := load(BehaviorMatrixPath)
	if behavior == null or not behavior.has_method("rebuild_index") or not ("rules" in behavior):
		return result
	behavior.rebuild_index()
	var indicator_db := load(IndicatorDBPath)
	var best_effect_set := false
	var best_effect := 0
	var best_labels: Array[String] = []
	var worst_effect_set := false
	var worst_effect := 0
	var worst_labels: Array[String] = []

	for rule in behavior.rules:
		if rule == null or not ("asset_id" in rule) or str(rule.asset_id) != asset_id:
			continue
		var indicator_id := str(rule.indicator_id) if "indicator_id" in rule else ""
		if indicator_id == "":
			continue
		var indicator_name := _resolve_indicator_name(indicator_db, indicator_id)
		if "low_effect" in rule:
			var low_effect := int(rule.low_effect)
			if low_effect == 0:
				pass
			else:
				if not best_effect_set or low_effect > best_effect:
					best_effect_set = true
					best_effect = low_effect
					best_labels = ["%s (low)" % indicator_name]
				elif low_effect == best_effect and not best_labels.has("%s (low)" % indicator_name):
					best_labels.append("%s (low)" % indicator_name)
				if not worst_effect_set or low_effect < worst_effect:
					worst_effect_set = true
					worst_effect = low_effect
					worst_labels = ["%s (low)" % indicator_name]
				elif low_effect == worst_effect and not worst_labels.has("%s (low)" % indicator_name):
					worst_labels.append("%s (low)" % indicator_name)
		if "high_effect" in rule:
			var high_effect := int(rule.high_effect)
			if high_effect == 0:
				continue
			if not best_effect_set or high_effect > best_effect:
				best_effect_set = true
				best_effect = high_effect
				best_labels = ["%s (high)" % indicator_name]
			elif high_effect == best_effect and not best_labels.has("%s (high)" % indicator_name):
				best_labels.append("%s (high)" % indicator_name)
			if not worst_effect_set or high_effect < worst_effect:
				worst_effect_set = true
				worst_effect = high_effect
				worst_labels = ["%s (high)" % indicator_name]
			elif high_effect == worst_effect and not worst_labels.has("%s (high)" % indicator_name):
				worst_labels.append("%s (high)" % indicator_name)

	if best_labels.size() > 0:
		result["best"] = ", ".join(best_labels)
	if worst_labels.size() > 0:
		result["worst"] = ", ".join(worst_labels)
	return result


func _resolve_indicator_name(indicator_db: Variant, indicator_id: String) -> String:
	if indicator_db == null or not indicator_db.has_method("get_by_id"):
		return indicator_id
	var indicator: Variant = indicator_db.get_by_id(indicator_id)
	if indicator == null:
		return indicator_id
	if "display_name" in indicator and indicator.display_name != null and str(indicator.display_name).strip_edges() != "":
		return str(indicator.display_name)
	return indicator_id

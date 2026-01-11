extends Control

const AssetCardScenePath := "res://Scenes/UI/AssetCard.tscn"
const AssetDBPath := "res://Resources/AssetDB.tres"
const GRID_ICON_SCALE := 1.2

var selected_asset_ids: Array[String] = []
var slot_nodes: Array[Node] = []
var grid_cards_by_id: Dictionary = {}
var asset_by_id: Dictionary = {}
var _start_button: Button
var _asset_grid: GridContainer


func _ready() -> void:
	print("StartRun: _ready called")
	_connect_back_button()
	_init_start_button()
	_init_slots()
	_populate_grid()
	_update_start_button_state()


func _connect_back_button() -> void:
	var node := get_node_or_null("TitleVBox/BackButton")
	if node == null:
		print("StartRun: Missing BackButton at path TitleVBox/BackButton")
		return
	var button := node as Button
	if button == null:
		print("StartRun: Node at TitleVBox/BackButton is not a Button")
		return
	button.pressed.connect(func() -> void: GameManager.go_to_main_menu())


func _init_start_button() -> void:
	_start_button = get_node_or_null("StartButton") as Button
	if _start_button == null:
		print("StartRun: Missing StartButton at path StartButton")
		return
	_start_button.disabled = true


func _init_slots() -> void:
	slot_nodes.clear()
	var nodes := get_tree().get_nodes_in_group("SelectedAssets")
	nodes.sort_custom(func(a, b): return a.name < b.name)
	for node in nodes:
		if node == null:
			continue
		var card := node as Control
		slot_nodes.append(card)
	for slot in slot_nodes:
		_clear_slot_card(slot)
	selected_asset_ids.clear()
	asset_by_id.clear()


func _populate_grid() -> void:
	_asset_grid = get_node_or_null("AssetScroll/AssetGridCenter/AssetGrid") as GridContainer
	if _asset_grid == null:
		push_error("StartRun: Missing AssetGrid at path AssetScroll/AssetGridCenter/AssetGrid")
		return

	var asset_db := load(AssetDBPath)
	if asset_db == null or not asset_db.has_method("get_all"):
		push_error("StartRun: Failed to load AssetDB at %s" % AssetDBPath)
		return

	var card_scene := load(AssetCardScenePath) as PackedScene
	if card_scene == null:
		push_error("StartRun: Failed to load AssetCard scene at %s" % AssetCardScenePath)
		return

	grid_cards_by_id.clear()
	asset_by_id.clear()
	for asset in asset_db.get_all():
		if asset == null or asset.id == "":
			continue
		if not asset.starting_unlocked:
			continue
		asset_by_id[asset.id] = asset
		var card_instance := card_scene.instantiate()
		_asset_grid.add_child(card_instance)
		if card_instance.has_method("apply_asset"):
			card_instance.apply_asset(asset)
		if card_instance.has_method("set_value_visible"):
			card_instance.set_value_visible(false)
		if card_instance.has_method("set_icon_scale"):
			card_instance.set_icon_scale(GRID_ICON_SCALE)
		if card_instance.has_method("set_interactable"):
			card_instance.set_interactable(true)
		if card_instance.has_method("set_selected"):
			card_instance.set_selected(false)
		card_instance.pressed.connect(func(id: String) -> void: _on_grid_card_pressed(id))
		grid_cards_by_id[asset.id] = card_instance
	print("StartRun: populated grid with %s assets" % grid_cards_by_id.size())


func _on_grid_card_pressed(asset_id: String) -> void:
	if asset_id == "" or not asset_by_id.has(asset_id):
		return
	if asset_id in selected_asset_ids:
		_deselect_asset(asset_id)
	else:
		_select_asset(asset_id)
	_refresh_slots()
	_update_start_button_state()
	_log_selection()


func _select_asset(asset_id: String) -> void:
	if selected_asset_ids.size() >= 4:
		return
	selected_asset_ids.append(asset_id)
	var grid_card := grid_cards_by_id.get(asset_id, null) as Control
	if grid_card and grid_card.has_method("set_selected"):
		grid_card.set_selected(true)


func _deselect_asset(asset_id: String) -> void:
	selected_asset_ids.erase(asset_id)
	var grid_card := grid_cards_by_id.get(asset_id, null) as Control
	if grid_card and grid_card.has_method("set_selected"):
		grid_card.set_selected(false)


func _update_start_button_state() -> void:
	if _start_button == null:
		return
	var should_enable := selected_asset_ids.size() == 4
	var was_disabled := _start_button.disabled
	_start_button.disabled = not should_enable
	if should_enable and was_disabled:
		print("StartRun: start enabled")
	elif not should_enable and not was_disabled:
		print("StartRun: start disabled")


func _log_selection() -> void:
	print("StartRun: selected=%s" % selected_asset_ids)


func _refresh_slots() -> void:
	for i in slot_nodes.size():
		var slot := slot_nodes[i]
		if slot == null:
			continue
		if i < selected_asset_ids.size():
			var asset_id := selected_asset_ids[i]
			var asset = asset_by_id.get(asset_id, null)
			if asset and slot.has_method("apply_asset"):
				slot.apply_asset(asset)
			if slot.has_method("set_value_visible"):
				slot.set_value_visible(false)
			if slot.has_method("set_selected"):
				slot.set_selected(true)
			_disable_slot_interaction(slot)
		else:
			_clear_slot_card(slot)


func _clear_slot_card(slot: Node) -> void:
	if slot == null:
		return
	if slot.has_method("clear_asset"):
		slot.clear_asset()
	if slot.has_method("set_value_visible"):
		slot.set_value_visible(false)
	if slot.has_method("set_selected"):
		slot.set_selected(false)
	_disable_slot_interaction(slot)


func _disable_slot_interaction(slot: Node) -> void:
	if slot and slot.has_method("set_interactable"):
		slot.set_interactable(false)

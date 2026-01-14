extends Control

const AssetCardScenePath := "res://Scenes/UI/AssetCard.tscn"
const AssetDBPath := "res://Resources/AssetDB.tres"
const GRID_CARD_SCALE := 1.25
const GRID_CARD_DEFAULT_SIZE := Vector2(250, 350)
#Test

const HAND_SIZE := 4

var slot_asset_ids: Array[String] = ["", "", "", ""]
var slot_lock_years_remaining: Array[int] = [0, 0, 0, 0]
var slot_nodes: Array[Node] = []
var grid_cards_by_id: Dictionary = {}
var asset_by_id: Dictionary = {}
var _is_continuing_run: bool = false
var _start_button: Button
var _asset_grid: GridContainer
var _last_selected_unlocked_slot: int = -1


func _ready() -> void:
	print("StartRun: _ready called")
	_connect_back_button()
	_init_start_button()
	_init_slots()
	_load_hand_from_run_state()
	_populate_grid()
	_apply_saved_selection_to_grid()
	_refresh_slots()
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
	_start_button.pressed.connect(_on_start_pressed)


func _init_slots() -> void:
	slot_nodes.clear()
	var nodes := get_tree().get_nodes_in_group("SelectedAssets")
	nodes.sort_custom(func(a, b):
		if a == null or b == null:
			return false
		if a.global_position.x == b.global_position.x:
			return a.global_position.y < b.global_position.y
		return a.global_position.x < b.global_position.x
	)
	for node in nodes:
		if node == null:
			continue
		var card := node as Control
		slot_nodes.append(card)
	for slot in slot_nodes:
		_clear_slot_card(slot)
	slot_asset_ids = ["", "", "", ""]
	slot_lock_years_remaining = [0, 0, 0, 0]
	_last_selected_unlocked_slot = -1
	asset_by_id.clear()


func _load_hand_from_run_state() -> void:
	_is_continuing_run = false
	var state: RunState = GameManager.get_run_state()
	var mode := GameManager.get_session_mode()
	if state == null or mode != GameManager.SessionMode.RUN:
		return
	for i in HAND_SIZE:
		if i < state.hand_asset_ids.size():
			slot_asset_ids[i] = state.hand_asset_ids[i]
		if i < state.hand_lock_years_remaining.size():
			slot_lock_years_remaining[i] = state.hand_lock_years_remaining[i]
		if slot_asset_ids[i] != "" and slot_lock_years_remaining[i] <= 0:
			_last_selected_unlocked_slot = i
	_is_continuing_run = true
	print("StartRun: RUN state ids=%s locks=%s year_index=%s" % [slot_asset_ids, slot_lock_years_remaining, state.current_year_index])


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
	var unlocked_count := 0
	for asset in asset_db.get_all():
		if asset == null or asset.id == "":
			continue
		asset_by_id[asset.id] = asset
		if not asset.starting_unlocked:
			continue
		unlocked_count += 1
		var card_instance := card_scene.instantiate()
		_scale_grid_card(card_instance)
		_asset_grid.add_child(card_instance)
		if card_instance.has_method("apply_asset"):
			card_instance.apply_asset(asset)
		if card_instance.has_method("set_value_visible"):
			card_instance.set_value_visible(false)
		if card_instance.has_method("set_outline_enabled"):
			card_instance.set_outline_enabled(true)
		if card_instance.has_method("set_name_font_size"):
			card_instance.set_name_font_size(40)
		if card_instance.has_method("set_interactable"):
			card_instance.set_interactable(true)
		if card_instance.has_method("set_selected"):
			card_instance.set_selected(false)
		card_instance.pressed.connect(func(id: String) -> void: _on_grid_card_pressed(id))
		grid_cards_by_id[asset.id] = card_instance
	print("StartRun: displaying %s unlocked assets" % unlocked_count)


func _apply_saved_selection_to_grid() -> void:
	for asset_id in slot_asset_ids:
		if asset_id == "":
			continue
		_set_grid_card_selected(asset_id, true)


func _on_grid_card_pressed(asset_id: String) -> void:
	if asset_id == "" or not asset_by_id.has(asset_id):
		return
	if _is_asset_locked(asset_id):
		print("StartRun: locked asset tap ignored -> %s" % asset_id)
		return
	if _is_asset_selected(asset_id):
		_deselect_asset(asset_id)
	else:
		_select_asset(asset_id)
	_refresh_slots()
	_update_start_button_state()
	_log_selection()


func _assign_asset_to_slot(slot_index: int, asset_id: String, lock_years: int) -> void:
	if slot_index < 0 or slot_index >= slot_asset_ids.size():
		return
	var previous_id := slot_asset_ids[slot_index]
	if previous_id != "" and previous_id != asset_id:
		_set_grid_card_selected(previous_id, false)
	slot_asset_ids[slot_index] = asset_id
	slot_lock_years_remaining[slot_index] = max(lock_years, 0)
	_set_grid_card_selected(asset_id, asset_id != "")


func _select_asset(asset_id: String) -> void:
	var empty_index := _find_first_empty_slot()
	if empty_index != -1:
		_assign_asset_to_slot(empty_index, asset_id, 0)
		_last_selected_unlocked_slot = empty_index
		print("StartRun: selected %s into slot %s" % [asset_id, empty_index + 1])
		return
	if _filled_slot_count() >= HAND_SIZE:
		var replace_index := _pick_replacement_slot()
		if replace_index == -1:
			print("StartRun: selection ignored (all available slots locked)")
			return
		_assign_asset_to_slot(replace_index, asset_id, 0)
		_last_selected_unlocked_slot = replace_index
		print("StartRun: replaced slot %s with %s" % [replace_index + 1, asset_id])
		return


func _deselect_asset(asset_id: String) -> void:
	var slot_index := _find_slot_for_asset(asset_id)
	if slot_index == -1:
		return
	if _is_slot_locked(slot_index):
		print("StartRun: deselect blocked, slot %s is locked (%s)" % [slot_index + 1, asset_id])
		return
	slot_asset_ids[slot_index] = ""
	slot_lock_years_remaining[slot_index] = 0
	_set_grid_card_selected(asset_id, false)
	print("StartRun: deselected %s" % asset_id)


func _update_start_button_state() -> void:
	if _start_button == null:
		return
	var should_enable := _filled_slot_count() == HAND_SIZE
	var was_disabled := _start_button.disabled
	_start_button.disabled = not should_enable
	if should_enable and was_disabled:
		print("StartRun: start enabled")
	elif not should_enable and not was_disabled:
		print("StartRun: start disabled")


func _log_selection() -> void:
	print("StartRun: selected=%s locks=%s" % [slot_asset_ids, slot_lock_years_remaining])


func _on_start_pressed() -> void:
	var chosen_ids: Array[String] = _build_chosen_ids()
	var mode_text := "continuing" if _is_continuing_run else "new"
	print("StartRun: start pressed (%s) with assets=%s" % [mode_text, chosen_ids])
	var started := false
	if _is_continuing_run:
		started = GameManager.apply_hand_selection(chosen_ids)
	else:
		started = GameManager.start_new_run(chosen_ids)
	print("StartRun: sent assets to GameManager -> started=%s" % started)
	if started:
		GameManager.go_to_match()


func _refresh_slots() -> void:
	for i in slot_nodes.size():
		var slot := slot_nodes[i]
		if slot == null:
			continue
		var asset_id := ""
		if i < slot_asset_ids.size():
			asset_id = slot_asset_ids[i]
		if asset_id == "":
			_clear_slot_card(slot)
			continue
		var asset = asset_by_id.get(asset_id, null)
		if asset and slot.has_method("apply_asset"):
			slot.apply_asset(asset)
		if slot.has_method("set_value_visible"):
			slot.set_value_visible(false)
		if slot.has_method("set_selected"):
			slot.set_selected(true)
		_disable_slot_interaction(slot)


func _find_slot_for_asset(asset_id: String) -> int:
	for i in slot_asset_ids.size():
		if slot_asset_ids[i] == asset_id:
			return i
	return -1


func _is_asset_selected(asset_id: String) -> bool:
	return _find_slot_for_asset(asset_id) != -1


func _is_slot_locked(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < slot_lock_years_remaining.size() and slot_lock_years_remaining[slot_index] > 0


func _is_asset_locked(asset_id: String) -> bool:
	var idx := _find_slot_for_asset(asset_id)
	return idx != -1 and _is_slot_locked(idx)


func _find_first_empty_slot() -> int:
	for i in slot_asset_ids.size():
		if slot_asset_ids[i] == "":
			return i
	return -1


func _filled_slot_count() -> int:
	var count := 0
	for id in slot_asset_ids:
		if id != "":
			count += 1
	return count


func _pick_replacement_slot() -> int:
	if _last_selected_unlocked_slot >= 0 and _last_selected_unlocked_slot < slot_asset_ids.size() and not _is_slot_locked(_last_selected_unlocked_slot):
		return _last_selected_unlocked_slot
	for i in range(slot_asset_ids.size() - 1, -1, -1):
		if slot_asset_ids[i] != "" and not _is_slot_locked(i):
			return i
	return -1


func _set_grid_card_selected(asset_id: String, is_selected: bool) -> void:
	var grid_card := grid_cards_by_id.get(asset_id, null) as Control
	if grid_card and grid_card.has_method("set_selected"):
		grid_card.set_selected(is_selected)


func _build_chosen_ids() -> Array[String]:
	var chosen: Array[String] = []
	for id in slot_asset_ids:
		chosen.append(id)
	while chosen.size() < HAND_SIZE:
		chosen.append("")
	return chosen


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


func _scale_grid_card(card_instance: Control) -> void:
	if card_instance == null:
		return
	var base_size := card_instance.custom_minimum_size
	if base_size == Vector2.ZERO:
		base_size = card_instance.size
	if base_size == Vector2.ZERO:
		base_size = GRID_CARD_DEFAULT_SIZE
	card_instance.custom_minimum_size = base_size * GRID_CARD_SCALE

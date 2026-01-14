extends Control


func _ready() -> void:
	print("Profile: _ready called")
	_setup_button("ButtonsRow/CollectionButton", "CollectionButton", func() -> void: GameManager.go_to_collection())
	_setup_button("ButtonsRow/MainMenuButton", "MainMenuButton", func() -> void: GameManager.go_to_main_menu())
	_setup_button("ButtonsRow/SettingsButton", "SettingsButton", func() -> void: GameManager.go_to_settings())
	_setup_button("ButtonsRow/ProfileButton", "ProfileButton", Callable(), true)
	_render_profile_stats()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_render_profile_stats()


func _render_profile_stats() -> void:
	var vm: Object = GameManager.get_profile_view_model()
	var stat1 := get_node_or_null("ContentVBox/StatRow1/DataLabel") as Label
	var stat2 := get_node_or_null("ContentVBox/StatRow2/DataLabel") as Label
	var stat3 := get_node_or_null("ContentVBox/StatRow3/DataLabel") as Label
	var stat4 := get_node_or_null("ContentVBox/StatRow4/DataLabel") as Label
	var stat5 := get_node_or_null("ContentVBox/StatRow5/DataLabel") as Label
	var stat6 := get_node_or_null("ContentVBox/StatRow6/DataLabel") as Label
	if stat1:
		stat1.text = str(vm.total_runs_completed)
	if stat2:
		stat2.text = vm.best_run_display
	if stat3:
		stat3.text = str(vm.total_allocations_made)
	if stat4:
		var favorite_raw: String = vm.favorite_asset_id if "favorite_asset_id" in vm else ""
		var favorite_display := _format_favorite_asset(favorite_raw)
		stat4.text = favorite_display
		print("Profile: favorite asset raw=%s display=%s" % [favorite_raw, favorite_display])
	if stat5:
		stat5.text = vm.biggest_year_gain_display
	if stat6:
		stat6.text = vm.biggest_year_loss_display
	print("Profile: rendered profile stats")


func _setup_button(path: String, label: String, callback: Callable = Callable(), disable: bool = false) -> void:
	var node := get_node_or_null(path)
	if node == null:
		print("Profile: Missing %s at path %s" % [label, path])
		return
	var button := node as Button
	if button == null:
		print("Profile: Node at %s is not a Button" % path)
		return
	if disable:
		button.disabled = true
	if not callback.is_null():
		button.pressed.connect(callback)


func _format_favorite_asset(raw_id: String) -> String:
	if raw_id == null:
		return "None"
	var text := str(raw_id).strip_edges()
	if text == "":
		return "None"
	text = text.replace("_", " ")
	var parts: Array = text.split(" ")
	var formatted_parts: Array[String] = []
	for part: String in parts:
		if part == "":
			continue
		var lower := part.to_lower()
		var titled := lower.substr(0, 1).to_upper() + lower.substr(1)
		formatted_parts.append(titled)
	if formatted_parts.is_empty():
		return "None"
	return " ".join(formatted_parts)

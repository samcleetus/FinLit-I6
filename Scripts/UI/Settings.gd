extends Control


func _ready() -> void:
	print("Settings: _ready called")
	var horizon_option := _get_option_button("ContentScrollContainer/ContentVBox/HorizonRow/OptionButton")
	var difficulty_option := _get_option_button("ContentScrollContainer/ContentVBox/DifficultyRow/OptionButton")

	_setup_button("ButtonsRow/CollectionButton", "CollectionButton", func() -> void: GameManager.go_to_collection())
	_setup_button("ButtonsRow/MainMenuButton", "MainMenuButton", func() -> void: GameManager.go_to_main_menu())
	_setup_button("ButtonsRow/ProfileButton", "ProfileButton", func() -> void: GameManager.go_to_profile())
	_setup_button("ButtonsRow/SettingsButton", "SettingsButton", Callable(), true)

	_populate_option_button(horizon_option, ["12 months", "24 months", "36 months"])
	_populate_option_button(difficulty_option, ["Easy", "Normal", "Hard"])
	var settings := GameManager.get_settings()
	_select_option_by_text(horizon_option, "%s months" % settings.time_horizon)
	_select_option_by_text(difficulty_option, settings.difficulty)
	_ensure_selection(horizon_option)
	_ensure_selection(difficulty_option)

	if horizon_option:
		horizon_option.item_selected.connect(func(_index: int) -> void: _on_horizon_selected(horizon_option))
	if difficulty_option:
		difficulty_option.item_selected.connect(func(_index: int) -> void: _on_difficulty_selected(difficulty_option))


func _setup_button(path: String, label: String, callback: Callable = Callable(), disable: bool = false) -> void:
	var node := get_node_or_null(path)
	if node == null:
		print("Settings: Missing %s at path %s" % [label, path])
		return
	var button := node as Button
	if button == null:
		print("Settings: Node at %s is not a Button" % path)
		return
	if disable:
		button.disabled = true
	if not callback.is_null():
		button.pressed.connect(callback)


func _get_option_button(path: String) -> OptionButton:
	var node := get_node_or_null(path)
	if node == null:
		print("Settings: Missing OptionButton at path %s" % path)
		return null
	var button := node as OptionButton
	if button == null:
		print("Settings: Node at %s is not an OptionButton" % path)
		return null
	return button


func _populate_option_button(button: OptionButton, options: Array) -> void:
	if button == null:
		return
	button.clear()
	for option in options:
		button.add_item(str(option))


func _select_option_by_text(button: OptionButton, text: String) -> void:
	if button == null:
		return
	for i in button.item_count:
		if button.get_item_text(i) == text:
			button.select(i)
			return


func _ensure_selection(button: OptionButton) -> void:
	if button == null:
		return
	if button.item_count > 0 and button.get_selected() == -1:
		button.select(0)


func _on_horizon_selected(button: OptionButton) -> void:
	var text := _get_selected_text(button)
	if text == "":
		return
	var value := _parse_horizon_value(text)
	print("Settings: horizon selected -> %s" % value)
	GameManager.set_time_horizon(value)


func _on_difficulty_selected(button: OptionButton) -> void:
	var text := _get_selected_text(button)
	if text == "":
		return
	print("Settings: difficulty selected -> %s" % text)
	GameManager.set_difficulty(text)


func _get_selected_text(button: OptionButton) -> String:
	if button == null:
		return ""
	var index := button.get_selected()
	if index == -1:
		return ""
	return button.get_item_text(index)


func _parse_horizon_value(text: String) -> int:
	if text == "":
		return 0
	var parts := text.split(" ")
	if parts.size() > 0:
		return int(parts[0])
	return int(text)

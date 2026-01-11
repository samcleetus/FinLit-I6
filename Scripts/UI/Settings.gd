extends Control

var _horizon_option: OptionButton
var _difficulty_option: OptionButton
var _save_button: Button

var _persisted_horizon: int = 0
var _persisted_difficulty: String = ""
var _pending_horizon: int = 0
var _pending_difficulty: String = ""


func _ready() -> void:
	print("Settings: _ready called")
	_horizon_option = _get_option_button("ContentScrollContainer/ContentVBox/HorizonRow/OptionButton")
	_difficulty_option = _get_option_button("ContentScrollContainer/ContentVBox/DifficultyRow/OptionButton")
	_save_button = _get_button("SaveButton")

	_setup_nav_button("ButtonsRow/CollectionButton", "CollectionButton", func() -> void: GameManager.go_to_collection())
	_setup_nav_button("ButtonsRow/MainMenuButton", "MainMenuButton", func() -> void: GameManager.go_to_main_menu())
	_setup_nav_button("ButtonsRow/ProfileButton", "ProfileButton", func() -> void: GameManager.go_to_profile())
	_setup_nav_button("ButtonsRow/SettingsButton", "SettingsButton", Callable(), true)

	_populate_option_button(_horizon_option, ["10 years", "12 years", "15 years", "20 years"])
	_populate_option_button(_difficulty_option, ["Easy", "Normal", "Hard"])

	var settings := GameManager.get_settings()
	_persisted_horizon = int(settings.time_horizon)
	_persisted_difficulty = str(settings.difficulty)
	_pending_horizon = _persisted_horizon
	_pending_difficulty = _persisted_difficulty

	_select_option_by_value(_horizon_option, _persisted_horizon)
	_select_option_by_text(_difficulty_option, _persisted_difficulty)
	_ensure_selection(_horizon_option)
	_ensure_selection(_difficulty_option)

	_set_save_button_enabled(false)

	if _horizon_option:
		_horizon_option.item_selected.connect(func(_index: int) -> void: _on_horizon_selected())
	if _difficulty_option:
		_difficulty_option.item_selected.connect(func(_index: int) -> void: _on_difficulty_selected())
	if _save_button:
		_save_button.pressed.connect(_on_save_pressed)


func _setup_nav_button(path: String, label: String, callback: Callable = Callable(), disable: bool = false) -> void:
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


func _select_option_by_value(button: OptionButton, value: int) -> void:
	_select_option_by_text(button, "%s years" % value)


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


func _on_horizon_selected() -> void:
	var text := _get_selected_text(_horizon_option)
	if text == "":
		return
	var value := _parse_horizon_value(text)
	_pending_horizon = value
	print("Settings: pending horizon -> %s" % _pending_horizon)
	_update_save_button_state()


func _on_difficulty_selected() -> void:
	var text := _get_selected_text(_difficulty_option)
	if text == "":
		return
	_pending_difficulty = text
	print("Settings: pending difficulty -> %s" % _pending_difficulty)
	_update_save_button_state()


func _on_save_pressed() -> void:
	if _save_button == null or _save_button.disabled:
		return
	GameManager.set_time_horizon(_pending_horizon)
	GameManager.set_difficulty(_pending_difficulty)
	var settings := GameManager.get_settings()
	_persisted_horizon = int(settings.time_horizon)
	_persisted_difficulty = str(settings.difficulty)
	_pending_horizon = _persisted_horizon
	_pending_difficulty = _persisted_difficulty
	_select_option_by_value(_horizon_option, _persisted_horizon)
	_select_option_by_text(_difficulty_option, _persisted_difficulty)
	_ensure_selection(_horizon_option)
	_ensure_selection(_difficulty_option)
	_set_save_button_enabled(false)
	print("Settings: saved changes -> Horizon: %s | Difficulty: %s" % [_persisted_horizon, _persisted_difficulty])


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


func _get_button(path: String) -> Button:
	var node := get_node_or_null(path)
	if node == null:
		print("Settings: Missing Button at path %s" % path)
		return null
	var button := node as Button
	if button == null:
		print("Settings: Node at %s is not a Button" % path)
		return null
	return button


func _set_save_button_enabled(enabled: bool) -> void:
	if _save_button == null:
		return
	_save_button.disabled = not enabled


func _update_save_button_state() -> void:
	var changed := _pending_horizon != _persisted_horizon or _pending_difficulty != _persisted_difficulty
	_set_save_button_enabled(changed)

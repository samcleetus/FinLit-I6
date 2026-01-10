extends Control


func _ready() -> void:
	print("Boot: _ready called")
	if not GameManager.should_show_boot():
		print("Boot: should_show_boot is false, routing to Main Menu")
		GameManager.go_to_main_menu()
		return

	var horizon_option := _get_option_button("VariableContainer/HorizonRow/OptionButton")
	var difficulty_option := _get_option_button("VariableContainer/DifficultyRow/OptionButton")
	var start_button := _get_button("StartButton")

	_populate_option_button(horizon_option, ["12 months", "24 months", "36 months"])
	_populate_option_button(difficulty_option, ["Easy", "Normal", "Hard"])
	_ensure_selection(horizon_option)
	_ensure_selection(difficulty_option)

	if start_button:
		start_button.pressed.connect(func() -> void: _on_start_pressed(horizon_option, difficulty_option))


func _on_start_pressed(horizon_option: OptionButton, difficulty_option: OptionButton) -> void:
	var horizon_text := _get_selected_text(horizon_option)
	var difficulty_text := _get_selected_text(difficulty_option)
	print("Boot: Start pressed -> horizon=%s difficulty=%s" % [horizon_text, difficulty_text])
	var horizon_months := float(horizon_text.split(" ")[0])
	GameManager.set_time_horizon(horizon_months)
	GameManager.set_difficulty(difficulty_text)
	GameManager.set_should_show_boot(false)
	GameManager.go_to_main_menu()


func _populate_option_button(button: OptionButton, options: Array) -> void:
	if button == null:
		return
	if button.item_count == 0:
		for option in options:
			button.add_item(str(option))


func _ensure_selection(button: OptionButton) -> void:
	if button == null:
		return
	if button.item_count > 0 and button.get_selected() == -1:
		button.select(0)


func _get_selected_text(button: OptionButton) -> String:
	if button == null:
		return ""
	var index := button.get_selected()
	if index == -1:
		if button.item_count > 0:
			index = 0
			button.select(index)
		else:
			print("Boot: OptionButton has no items, cannot read selection")
			return ""
	return button.get_item_text(index)


func _get_option_button(path: String) -> OptionButton:
	var node := get_node_or_null(path)
	if node == null:
		print("Boot: Missing OptionButton at path %s" % path)
		return null
	var button := node as OptionButton
	if button == null:
		print("Boot: Node at %s is not an OptionButton" % path)
		return null
	return button


func _get_button(path: String) -> Button:
	var node := get_node_or_null(path)
	if node == null:
		print("Boot: Missing Button at path %s" % path)
		return null
	var button := node as Button
	if button == null:
		print("Boot: Node at %s is not a Button" % path)
		return null
	return button

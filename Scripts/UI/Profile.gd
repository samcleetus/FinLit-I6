extends Control


func _ready() -> void:
	print("Profile: _ready called")
	_setup_button("ButtonsRow/PracticeButton", "PracticeButton", func() -> void: GameManager.go_to_start_practice())
	_setup_button("ButtonsRow/MainMenuButton", "MainMenuButton", func() -> void: GameManager.go_to_main_menu())
	_setup_button("ButtonsRow/SettingsButton", "SettingsButton", func() -> void: GameManager.go_to_settings())
	_setup_button("ButtonsRow/ProfileButton", "ProfileButton", Callable(), true)


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

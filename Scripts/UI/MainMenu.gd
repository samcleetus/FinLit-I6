extends Control


func _ready() -> void:
	print("MainMenu: _ready called")
	_connect_button("PlayButton", "PlayButton", func() -> void: GameManager.go_to_start_run())
	_connect_button("ButtonsRow/PracticeButton", "PracticeButton", func() -> void: GameManager.go_to_start_practice())
	_connect_button("ButtonsRow/ProfileButton", "ProfileButton", func() -> void: GameManager.go_to_profile())
	_connect_button("ButtonsRow/SettingsButton", "SettingsButton", func() -> void: GameManager.go_to_settings())


func _connect_button(path: String, label: String, callback: Callable) -> void:
	var node := get_node_or_null(path)
	if node == null:
		print("MainMenu: Missing %s at path %s" % [label, path])
		return
	var button := node as Button
	if button == null:
		print("MainMenu: Node at %s is not a Button" % path)
		return
	button.pressed.connect(callback)

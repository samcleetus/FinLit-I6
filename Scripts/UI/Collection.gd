extends Control


func _ready() -> void:
	print("Collection: Collection ready")
	_setup_nav_button("ButtonsRow/CollectionButton", "CollectionButton", Callable(), true)
	_setup_nav_button("ButtonsRow/MainMenuButton", "MainMenuButton", func() -> void: GameManager.go_to_main_menu())
	_setup_nav_button("ButtonsRow/ProfileButton", "ProfileButton", func() -> void: GameManager.go_to_profile())
	_setup_nav_button("ButtonsRow/SettingsButton", "SettingsButton", func() -> void: GameManager.go_to_settings())


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

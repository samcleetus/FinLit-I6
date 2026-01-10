extends Control


func _ready() -> void:
	print("StartRun: _ready called")
	_connect_bottom_nav()
	_connect_back_button()


func _connect_back_button() -> void:
	var node := get_node_or_null("BackButton")
	if node == null:
		print("StartRun: Missing BackButton at path BackButton")
		return
	var button := node as Button
	if button == null:
		print("StartRun: Node at BackButton is not a Button")
		return
	button.pressed.connect(func() -> void: GameManager.go_to_main_menu())


func _connect_bottom_nav() -> void:
	_setup_nav_button("ButtonsRow/CollectionButton", "CollectionButton", func() -> void: GameManager.go_to_collection())
	_setup_nav_button("ButtonsRow/MainMenuButton", "MainMenuButton", func() -> void: GameManager.go_to_main_menu())
	_setup_nav_button("ButtonsRow/ProfileButton", "ProfileButton", func() -> void: GameManager.go_to_profile())
	_setup_nav_button("ButtonsRow/SettingsButton", "SettingsButton", func() -> void: GameManager.go_to_settings())


func _setup_nav_button(path: String, label: String, callback: Callable) -> void:
	var node := get_node_or_null(path)
	if node == null:
		print("StartRun: Missing %s at path %s" % [label, path])
		return
	var button := node as Button
	if button == null:
		print("StartRun: Node at %s is not a Button" % path)
		return
	button.pressed.connect(callback)

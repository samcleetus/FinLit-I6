extends Control


func _ready() -> void:
	print("Profile: _ready called")
	_setup_button("ButtonsRow/CollectionButton", "CollectionButton", func() -> void: GameManager.go_to_collection())
	_setup_button("ButtonsRow/MainMenuButton", "MainMenuButton", func() -> void: GameManager.go_to_main_menu())
	_setup_button("ButtonsRow/SettingsButton", "SettingsButton", func() -> void: GameManager.go_to_settings())
	_setup_button("ButtonsRow/ProfileButton", "ProfileButton", Callable(), true)
	var vm: Object = GameManager.get_profile_view_model()
	var stat1 := get_node_or_null("ContentVBox/StatRow1/DataLabel") as Label
	var stat2 := get_node_or_null("ContentVBox/StatRow2/DataLabel") as Label
	var stat3 := get_node_or_null("ContentVBox/StatRow3/DataLabel") as Label
	if stat1:
		stat1.text = str(vm.total_runs_completed)
	if stat2:
		stat2.text = vm.best_run_display
	if stat3:
		stat3.text = str(vm.total_allocations_made)
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

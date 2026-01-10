extends Control


func _ready() -> void:
	print("MainMenu: _ready called")
	var play_button := find_descendant_by_name(self, "PlayButton") as Button
	var collection_button := find_descendant_by_name(self, "CollectionButton") as Button
	var profile_button := find_descendant_by_name(self, "ProfileButton") as Button
	var settings_button := find_descendant_by_name(self, "SettingsButton") as Button
	var title_label := find_descendant_by_name(self, "TitleLabel") as Label
	var subtitle_label := find_descendant_by_name(self, "SubtitleLabel") as Label

	_setup_button(play_button, "PlayButton", func() -> void: GameManager.go_to_start_run())
	_setup_button(collection_button, "CollectionButton", func() -> void: GameManager.go_to_collection())
	_setup_button(profile_button, "ProfileButton", func() -> void: GameManager.go_to_profile())
	_setup_button(settings_button, "SettingsButton", func() -> void: GameManager.go_to_settings())

	var settings := GameManager.get_settings()
	var summary := "Horizon: %s years | Difficulty: %s" % [settings.time_horizon, settings.difficulty]
	print("MainMenu: Settings summary -> %s" % summary)
	if subtitle_label:
		subtitle_label.text = summary
	elif title_label:
		if title_label.text.strip_edges() != "":
			title_label.text = "%s\n%s" % [title_label.text, summary]
		else:
			title_label.text = summary


func find_descendant_by_name(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	for child in root.get_children():
		if child.name == target_name:
			return child
		var match := find_descendant_by_name(child, target_name)
		if match != null:
			return match
	return null


func _setup_button(button: Button, label: String, callback: Callable) -> void:
	if button == null:
		print("MainMenu: Missing %s" % label)
		return
	button.pressed.connect(callback)

extends Control

const YearNodeScene := preload("res://Scenes/UI/YearNode.tscn")

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
	render_year_track(settings)


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


func render_year_track(settings: AppSettings = null) -> void:
	var year_grid := get_node_or_null("CenterContainer/Container/YearTrack/YearGrid") as GridContainer
	if year_grid == null:
		year_grid = get_node_or_null("CenterContainer/Container/YearTrack/YearCenterContainer/YearGrid") as GridContainer
	if year_grid == null:
		print("MainMenu: Missing YearGrid")
		return
	for child in year_grid.get_children():
		year_grid.remove_child(child)
		child.queue_free()

	if YearNodeScene == null:
		print("MainMenu: YearNode scene missing")
		return

	var resolved_settings := settings if settings != null else GameManager.get_settings()
	var horizon_years := int(resolved_settings.time_horizon) if resolved_settings != null else 0
	if horizon_years <= 0:
		return

	var state: RunState = GameManager.get_run_state()
	var current_year_idx := int(max(0, int(state.current_year_index) if state != null else int(GameManager.current_year_index)))
	var year_nets: Array[int] = GameManager.get_year_net_gains_cents()
	print("MainMenu: render_year_track -> horizon=%s current_year_index=%s nets=%s" % [horizon_years, current_year_idx, year_nets])

	for i in horizon_years:
		var year_node := YearNodeScene.instantiate()
		var year_state: int = YearNode.STATUS_UPCOMING
		var net_cents := 0
		if i < current_year_idx:
			if i < year_nets.size():
				net_cents = int(year_nets[i])
			year_state = YearNode.STATUS_LOSS if net_cents < 0 else YearNode.STATUS_GAIN
		print("MainMenu: year_node i=%s status=%s net=%s" % [i, year_state, net_cents])
		if year_node == null:
			print("MainMenu: failed to instance YearNode for i=%s" % i)
			continue
		if not year_node.has_method("set_year"):
			print("MainMenu: YearNode missing set_year for i=%s" % i)
			continue
		year_node.set_year(i + 1, year_state)
		year_grid.add_child(year_node)

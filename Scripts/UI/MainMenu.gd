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
	var year_track := get_node_or_null("CenterContainer/Container/YearTrack") as ScrollContainer
	var track_canvas := get_node_or_null("CenterContainer/Container/YearTrack/YearTrackCanvas") as Control
	var year_path := get_node_or_null("CenterContainer/Container/YearTrack/YearTrackCanvas/YearPath") as Path2D
	var path_line := get_node_or_null("CenterContainer/Container/YearTrack/YearTrackCanvas/PathLine") as Line2D
	if track_canvas == null or year_path == null or path_line == null:
		print("MainMenu: Missing YearTrack path nodes")
		return
	if year_track != null:
		year_track.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		year_track.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_clear_year_nodes(track_canvas, year_path, path_line)

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

	var curve := _prepare_year_curve(year_path)
	if curve == null:
		print("MainMenu: YearPath curve missing")
		return
	var baked_points: PackedVector2Array = curve.get_baked_points()
	var baked_length := curve.get_baked_length()
	if baked_points.is_empty() or baked_length <= 0.0:
		print("MainMenu: YearPath curve has no baked data")
		return
	path_line.points = baked_points
	path_line.visible = true

	var max_x := 0.0
	var max_y := 0.0
	for point in baked_points:
		max_x = max(max_x, point.x)
		max_y = max(max_y, point.y)
	track_canvas.custom_minimum_size = Vector2(max_x + 200.0, max_y + 200.0)

	var total_nodes := horizon_years
	var start_offset := 0.08
	var end_offset := 0.92
	for i in horizon_years:
		var t: float = lerp(start_offset, end_offset, float(i) / max(1, total_nodes - 1))
		var distance := t * baked_length
		var pos := curve.sample_baked(distance)
		var year_node := YearNodeScene.instantiate() as Control
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
		year_node.set_anchors_preset(Control.PRESET_TOP_LEFT)
		year_node.set_year(i + 1, year_state)
		track_canvas.add_child(year_node)
		var node_size := year_node.get_combined_minimum_size()
		if node_size == Vector2.ZERO:
			node_size = Vector2(64, 64)
		year_node.custom_minimum_size = node_size
		year_node.size = node_size
		year_node.position = pos - node_size * 0.5


func _clear_year_nodes(track_canvas: Control, year_path: Path2D, path_line: Line2D) -> void:
	for child in track_canvas.get_children():
		if child == year_path or child == path_line:
			continue
		track_canvas.remove_child(child)
		child.queue_free()


func _prepare_year_curve(year_path: Path2D) -> Curve2D:
	if year_path == null:
		return null
	var curve := year_path.curve
	if curve == null:
		curve = Curve2D.new()
		year_path.curve = curve
	if curve.get_point_count() < 2:
		curve.clear_points()
		var points := [
			{
				"pos": Vector2(80, 80),
				"in_handle": Vector2.ZERO,
				"out_handle": Vector2(80, 40),
			},
			{
				"pos": Vector2(280, 120),
				"in_handle": Vector2(-120, -20),
				"out_handle": Vector2(60, 80),
			},
			{
				"pos": Vector2(140, 240),
				"in_handle": Vector2(-60, -40),
				"out_handle": Vector2(60, 80),
			},
			{
				"pos": Vector2(320, 360),
				"in_handle": Vector2(-120, -80),
				"out_handle": Vector2(80, 120),
			},
			{
				"pos": Vector2(180, 480),
				"in_handle": Vector2(-80, -80),
				"out_handle": Vector2(80, 100),
			},
			{
				"pos": Vector2(300, 620),
				"in_handle": Vector2(-60, -80),
				"out_handle": Vector2.ZERO,
			},
		]
		for point_data in points:
			curve.add_point(
				point_data["pos"],
				point_data.get("in_handle", Vector2.ZERO),
				point_data.get("out_handle", Vector2.ZERO)
			)
	return curve

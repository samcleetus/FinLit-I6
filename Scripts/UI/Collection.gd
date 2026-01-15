extends Control

const AssetDBPath := "res://Resources/AssetDB.tres"
const AssetCardScenePath := "res://Scenes/UI/AssetCard.tscn"
const AssetDetailsOverlayPath := "res://Scenes/Game/AssetDetailsOverlay.tscn"

var _asset_grid: GridContainer
var _asset_overlay: Control
var _asset_by_id: Dictionary = {}
var _asset_locked_by_id: Dictionary = {}


func _ready() -> void:
	print("Collection: Collection ready")
	_cache_nodes()
	_setup_nav_button("ButtonsRow/CollectionButton", "CollectionButton", func() -> void: GameManager.go_to_collection(), true)
	_setup_nav_button("ButtonsRow/MainMenuButton", "MainMenuButton", func() -> void: GameManager.go_to_main_menu())
	_setup_nav_button("ButtonsRow/ProfileButton", "ProfileButton", func() -> void: GameManager.go_to_profile())
	_setup_nav_button("ButtonsRow/SettingsButton", "SettingsButton", func() -> void: GameManager.go_to_settings())
	_set_title()
	_build_asset_grid()


func _cache_nodes() -> void:
	_asset_grid = get_node_or_null("AssetScroll/AssetGridCenter/AssetGrid") as GridContainer


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


func _set_title() -> void:
	var title_label := get_node_or_null("TitleVBox/TitleLabel") as Label
	if title_label:
		title_label.text = "Collection"


func _build_asset_grid() -> void:
	if _asset_grid == null:
		print("Collection: Missing AssetGrid; cannot populate collection.")
		return
	for child in _asset_grid.get_children():
		child.queue_free()

	var asset_db := load(AssetDBPath)
	if asset_db == null or not asset_db.has_method("get_all"):
		push_error("Collection: Failed to load AssetDB at %s" % AssetDBPath)
		return
	var card_scene := load(AssetCardScenePath) as PackedScene
	if card_scene == null:
		push_error("Collection: Failed to load AssetCard scene at %s" % AssetCardScenePath)
		return

	_asset_by_id.clear()
	_asset_locked_by_id.clear()
	var assets: Array = asset_db.get_all()
	var added := 0
	for asset in assets:
		if asset == null or not ("id" in asset) or str(asset.id) == "":
			continue
		var asset_id := str(asset.id)
		_asset_by_id[asset_id] = asset
		var card_instance := card_scene.instantiate()
		if card_instance == null:
			continue
		_asset_grid.add_child(card_instance)
		if card_instance.has_method("apply_asset"):
			card_instance.apply_asset(asset)
		var is_locked: bool = not (asset != null and "starting_unlocked" in asset and asset.starting_unlocked)
		_asset_locked_by_id[asset_id] = is_locked
		if card_instance.has_method("set_locked"):
			card_instance.set_locked(is_locked)
		if card_instance.has_signal("pressed"):
			var callable := Callable(self, "_on_asset_pressed").bind(asset_id)
			if not card_instance.pressed.is_connected(callable):
				card_instance.pressed.connect(callable)
		added += 1

	print("Collection: rendered %s assets" % added)


func _on_asset_pressed(asset_id: String) -> void:
	var locked := bool(_asset_locked_by_id.get(asset_id, false))
	print("Collection: asset tapped -> %s locked=%s" % [asset_id, locked])
	var asset_data: Variant = _asset_by_id.get(asset_id, null)
	_ensure_overlay()
	if _asset_overlay and _asset_overlay.has_method("show_asset"):
		_asset_overlay.call("show_asset", asset_id, asset_data)


func _ensure_overlay() -> void:
	if _asset_overlay != null:
		return
	var overlay_scene := load(AssetDetailsOverlayPath) as PackedScene
	if overlay_scene == null:
		push_error("Collection: Failed to load AssetDetailsOverlay at %s" % AssetDetailsOverlayPath)
		return
	_asset_overlay = overlay_scene.instantiate()
	if _asset_overlay == null:
		push_error("Collection: Failed to instantiate AssetDetailsOverlay.")
		return
	add_child(_asset_overlay)
	_asset_overlay.visible = false

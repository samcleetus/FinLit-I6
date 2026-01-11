extends Control

@warning_ignore("unused_signal")
signal pressed(asset_id: String)

var asset_id: String = ""
var selected: bool = false
var _hit_button: Button
var _name_label: Label
var _image: TextureRect
var _value_label: Label
var _base_image_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_hit_button = get_node_or_null("HitButton")
	_name_label = get_node_or_null("AssetVBox/AssetNameLabel")
	_image = get_node_or_null("AssetVBox/AssetImage")
	_value_label = get_node_or_null("AssetVBox/AssetValueLabel")
	if _image:
		_base_image_scale = _image.scale
	if _hit_button:
		_hit_button.disabled = false
		_hit_button.mouse_filter = Control.MOUSE_FILTER_STOP
		_hit_button.pressed.connect(_on_pressed)


func apply_asset(asset: Asset) -> void:
	if asset == null:
		clear_asset()
		return
	asset_id = asset.id
	if _name_label:
		_name_label.text = asset.display_name
	if _image:
		_image.texture = asset.icon
	if _value_label:
		_value_label.text = "$0"
	set_selected(false)
	set_interactable(true)
	print("AssetCard apply_asset -> %s" % asset_id)


func clear_asset() -> void:
	asset_id = ""
	if _name_label:
		_name_label.text = ""
	if _image:
		_image.texture = null
	if _value_label:
		_value_label.text = "$0"
	set_selected(false)


func set_selected(is_selected: bool) -> void:
	selected = is_selected
	self.modulate = Color(1, 1, 1, 1) if is_selected else Color(1, 1, 1, 0.9)


func set_interactable(is_enabled: bool) -> void:
	if _hit_button:
		_hit_button.disabled = not is_enabled
		_hit_button.mouse_filter = Control.MOUSE_FILTER_STOP if is_enabled else Control.MOUSE_FILTER_IGNORE


func set_value_visible(visible_enabled: bool) -> void:
	if _value_label:
		_value_label.visible = visible_enabled


func set_icon_scale(scale_factor: float) -> void:
	if _image:
		_image.scale = _base_image_scale * scale_factor


func _on_pressed() -> void:
	if asset_id == "":
		return
	print("AssetCard pressed -> %s" % asset_id)
	emit_signal("pressed", asset_id)

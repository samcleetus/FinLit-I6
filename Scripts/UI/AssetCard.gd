extends Control

@warning_ignore("unused_signal")
signal pressed(asset_id: String)

var asset_id: String = ""
var selected: bool = false
var _hit_button: Button
var _name_label: Label
var _image: TextureRect
var _value_label: Label
var _vbox: Control
var _base_image_scale: Vector2 = Vector2.ONE
var _base_image_scale_set: bool = false
var _outline_enabled: bool = false
var _outline_color: Color = Color.WHITE
var _outline_thickness: float = 2.0
var _outline_margin: float = 4.0
var _name_font_size_default: int = 25


func _ready() -> void:
	_ensure_nodes()
	if _hit_button:
		_hit_button.disabled = false
		_hit_button.mouse_filter = Control.MOUSE_FILTER_STOP
		_hit_button.pressed.connect(_on_pressed)


func apply_asset(asset: Asset) -> void:
	_ensure_nodes()
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
	_ensure_nodes()
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
	if _outline_enabled:
		queue_redraw()


func set_interactable(is_enabled: bool) -> void:
	_ensure_nodes()
	if _hit_button:
		_hit_button.disabled = not is_enabled
		_hit_button.mouse_filter = Control.MOUSE_FILTER_STOP if is_enabled else Control.MOUSE_FILTER_IGNORE


func set_value_visible(visible_enabled: bool) -> void:
	_ensure_nodes()
	if _value_label:
		_value_label.visible = visible_enabled


func set_icon_scale(scale_factor: float) -> void:
	_ensure_nodes()
	if _image:
		_image.scale = _base_image_scale * scale_factor


func _on_pressed() -> void:
	if asset_id == "":
		return
	print("AssetCard pressed -> %s" % asset_id)
	emit_signal("pressed", asset_id)


func set_outline_enabled(enabled: bool) -> void:
	_outline_enabled = enabled
	queue_redraw()


func set_name_font_size(font_size: int) -> void:
	_ensure_nodes()
	if _name_label:
		_name_font_size_default = _name_label.get_theme_font_size("font_size") if _name_label.has_theme_font_size_override("font_size") else _name_label.get_theme_font_size("font_size")
		_name_label.add_theme_font_size_override("font_size", font_size)


func _draw() -> void:
	if _outline_enabled and selected:
		var rect := _get_outline_rect()
		draw_rect(rect, _outline_color, false, _outline_thickness)


func _ensure_nodes() -> void:
	if _hit_button == null:
		_hit_button = get_node_or_null("HitButton")
	if _name_label == null:
		_name_label = get_node_or_null("AssetVBox/AssetNameLabel")
	if _image == null:
		_image = get_node_or_null("AssetVBox/AssetImage")
	if _value_label == null:
		_value_label = get_node_or_null("AssetVBox/AssetValueLabel")
	if _vbox == null:
		_vbox = get_node_or_null("AssetVBox") as Control
	if _image and not _base_image_scale_set:
		_base_image_scale = _image.scale
		_base_image_scale_set = true


func _get_outline_rect() -> Rect2:
	_ensure_nodes()
	if _vbox:
		var rect := Rect2(_vbox.position, _vbox.size)
		rect.position -= Vector2.ONE * _outline_margin
		rect.size += Vector2.ONE * (_outline_margin * 2.0)
		return rect
	var fallback := Rect2(Vector2.ZERO, size)
	fallback.position += Vector2.ONE * (_outline_thickness * 0.5)
	fallback.size -= Vector2.ONE * _outline_thickness
	return fallback

extends Control
class_name YearNode

const STATUS_UPCOMING := 0
const STATUS_GAIN := 1
const STATUS_LOSS := 2

const TEXTURE_UPCOMING := preload("res://Assets/Images/UI/YearNodeGray.png")
const TEXTURE_GAIN := preload("res://Assets/Images/UI/YearNodeGreen.png")
const TEXTURE_LOSS := preload("res://Assets/Images/UI/YearNodeRed.png")

var _year_label: Label = null
var _icon: TextureRect = null


func set_year(year_number: int, status: int) -> void:
	_ensure_nodes()
	assert(_year_label != null, "YearNode: missing YearLabel")
	assert(_icon != null, "YearNode: missing Icon")
	_year_label.text = str(year_number)
	_icon.texture = _resolve_texture(status)
	var texture_path := _icon.texture.resource_path if _icon.texture != null else "null"
	print("YearNode: set_year number=%s status=%s texture=%s" % [year_number, status, texture_path])


func _resolve_texture(status: int) -> Texture2D:
	match status:
		STATUS_GAIN:
			return TEXTURE_GAIN
		STATUS_LOSS:
			return TEXTURE_LOSS
		_:
			return TEXTURE_UPCOMING


func _ensure_nodes() -> void:
	if _year_label == null:
		_year_label = get_node_or_null("ContentVBox/YearLabel")
	if _icon == null:
		_icon = get_node_or_null("ContentVBox/Icon") as TextureRect

extends RefCounted
class_name IndicatorViewModel

var indicator_id: String = ""
var display_name: String = ""
var value_text: String = ""


func _init(_id: String = "", _name: String = "", _value_text: String = "") -> void:
	indicator_id = _id
	display_name = _name
	value_text = _value_text


func to_debug_string() -> String:
	return "Indicator(id=%s, name=%s, value=%s)" % [indicator_id, display_name, value_text]

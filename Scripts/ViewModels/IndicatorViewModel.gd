extends RefCounted
class_name IndicatorViewModel

var indicator_id: String = ""
var display_name: String = ""
var value_text: String = ""
var percent: float = 0.0
var level: int = 0


func _init(_id: String = "", _name: String = "", _value_text: String = "", _percent: float = 0.0, _level: int = 0) -> void:
	indicator_id = _id
	display_name = _name
	value_text = _value_text
	percent = _percent
	level = _level


func to_debug_string() -> String:
	return "Indicator(id=%s, name=%s, value=%s, percent=%.2f, level=%d)" % [indicator_id, display_name, value_text, percent, level]

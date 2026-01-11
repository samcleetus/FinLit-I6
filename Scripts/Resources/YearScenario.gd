extends Resource
class_name YearScenario

@export var year_index: int = 0
@export var indicator_ids: Array[String] = []
@export var indicator_levels: Dictionary = {} # indicator_id -> int (0/1/2)
@export var seed_used: int = 0
@export var shocks_triggered: Array[String] = []


func set_level(indicator_id: String, level: int) -> void:
	if indicator_id == "":
		return
	indicator_levels[indicator_id] = level


func get_level(indicator_id: String, default_level: int = 1) -> int:
	if indicator_levels.has(indicator_id):
		return int(indicator_levels.get(indicator_id, default_level))
	return default_level


func to_debug_string() -> String:
	return "year=%d indicators=%s levels=%s shocks=%s seed=%d" % [year_index, indicator_ids, indicator_levels, shocks_triggered, seed_used]

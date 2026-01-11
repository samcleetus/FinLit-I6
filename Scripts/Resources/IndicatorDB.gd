extends Resource
class_name IndicatorDB

@export var indicators: Array[Indicator] = []

var _index: Dictionary = {}


func get_all() -> Array[Indicator]:
	return indicators


func get_by_id(indicator_id: String) -> Indicator:
	if _index.is_empty():
		rebuild_index()
	if _index.is_empty():
		return null
	if _index.has(indicator_id):
		return _index[indicator_id]
	return null


func rebuild_index() -> void:
	_index.clear()
	for indicator in indicators:
		if indicator == null:
			print("IndicatorDB: null indicator entry skipped")
			continue
		if indicator.id == "":
			print("IndicatorDB: indicator with empty id skipped (display_name=%s)" % indicator.display_name)
			continue
		if _index.has(indicator.id):
			print("IndicatorDB: duplicate id '%s' found, keeping first and skipping %s" % [indicator.id, indicator.display_name])
			continue
		_index[indicator.id] = indicator

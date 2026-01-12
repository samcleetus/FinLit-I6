extends Resource
class_name BehaviorMatrix

@export var rules: Array[BehaviorRule] = []

var _index: Dictionary = {}


func rebuild_index() -> void:
	_index.clear()
	for rule in rules:
		if rule == null:
			print("BehaviorMatrix: null rule skipped")
			continue
		if rule.asset_id == "" or rule.indicator_id == "":
			print("BehaviorMatrix: rule skipped due to missing id (asset_id='%s' indicator_id='%s')" % [rule.asset_id, rule.indicator_id])
			continue
		var key := _make_key(rule.asset_id, rule.indicator_id)
		if _index.has(key):
			print("BehaviorMatrix: duplicate rule for '%s|%s' found, keeping first" % [rule.asset_id, rule.indicator_id])
			continue
		_index[key] = rule


func get_rule(asset_id: String, indicator_id: String) -> BehaviorRule:
	if _index.is_empty():
		rebuild_index()
	if _index.is_empty():
		return null
	var key := _make_key(asset_id, indicator_id)
	if _index.has(key):
		return _index[key]
	return null


func get_effect(asset_id: String, indicator_id: String, is_high: bool) -> int:
	var rule := get_rule_for(asset_id, indicator_id)
	if rule == null:
		return 0
	return rule.high_effect if is_high else rule.low_effect


func get_rule_for(asset_id: String, indicator_id: String) -> BehaviorRule:
	if asset_id == "" or indicator_id == "":
		return null
	return get_rule(asset_id, indicator_id)


func get_effect_points(asset_id: String, indicator_id: String, level: int) -> int:
	var rule := get_rule_for(asset_id, indicator_id)
	if rule == null:
		return 0
	match level:
		0:
			return rule.low_effect
		2:
			return rule.high_effect
		_:
			return int(round((rule.low_effect + rule.high_effect) / 2.0))


func _make_key(asset_id: String, indicator_id: String) -> String:
	return "%s|%s" % [asset_id, indicator_id]

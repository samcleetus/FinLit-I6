extends RefCounted
class_name MatchViewModel

var year_index: int = 0
var time_horizon: int = 0
var difficulty: String = ""
var indicators: Array[IndicatorViewModel] = []
var asset_slots: Array[AssetSlotViewModel] = []
var debug_run_id: String = ""
var debug_seed: int = 0
var indicator_levels: Dictionary = {}
var indicator_values: Dictionary = {}


func to_debug_string() -> String:
	var indicator_count := indicators.size()
	var asset_count := asset_slots.size()
	return "Match(year=%d, horizon=%d, difficulty=%s, indicators=%d, assets=%d, run=%s, seed=%d)" % [year_index, time_horizon, difficulty, indicator_count, asset_count, debug_run_id, debug_seed]

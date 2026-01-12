extends RefCounted
class_name MonthResolver

const EFFECT_POINT_RATE := 0.005
const DEFAULT_LEVEL := 1


static func get_deterministic_rng(run_seed: int, year: int, month: int, asset_id: String) -> RandomNumberGenerator:
	var combined_text := "%s_%s_%s_%s" % [run_seed, year, month, asset_id]
	var seed_value: int = abs(hash(combined_text))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func resolve_month_step(
	behavior_matrix: BehaviorMatrix,
	scenario,
	allocated_by_asset: Dictionary,
	unallocated_funds: int,
	month_step: int = -1,
	run_seed: int = 0
	) -> Dictionary:
	
	if allocated_by_asset == null or typeof(allocated_by_asset) != TYPE_DICTIONARY:
		allocated_by_asset = {}

	var indicator_ids: Array = []
	var level_map: Dictionary = {}
	if scenario != null:
		if "indicator_ids" in scenario:
			indicator_ids = scenario.indicator_ids
		if "indicator_levels" in scenario:
			level_map = scenario.indicator_levels

	if indicator_ids.is_empty() and not level_map.is_empty():
		indicator_ids = level_map.keys()

	var resolved_levels: Dictionary = {}
	for indicator_id in indicator_ids:
		var level := DEFAULT_LEVEL
		if scenario != null and scenario.has_method("get_level"):
			level = scenario.get_level(indicator_id, DEFAULT_LEVEL)
		elif level_map.has(indicator_id):
			level = int(level_map[indicator_id])
		resolved_levels[indicator_id] = level

	var debug_month := month_step if month_step >= 0 else -1
	print("Resolver: month_step=%d indicators=%s levels=%s" % [debug_month, indicator_ids, resolved_levels])

	var new_allocated: Dictionary = {}
	var breakdown: Dictionary = {}
	var behavior_available := behavior_matrix != null
	var year_index: int = 0
	if scenario != null and "year_index" in scenario:
		year_index = int(scenario.year_index)

	for asset_id in allocated_by_asset.keys():
		var invested := int(allocated_by_asset.get(asset_id, 0))
		var points_sum := 0
		for indicator_id in indicator_ids:
			var level := int(resolved_levels.get(indicator_id, DEFAULT_LEVEL))
			if behavior_available:
				points_sum += behavior_matrix.get_effect_points(asset_id, indicator_id, level)
		var monthly_return := float(points_sum) * EFFECT_POINT_RATE
		if points_sum == 0:
			var rng := get_deterministic_rng(run_seed, year_index, month_step, asset_id)
			monthly_return = rng.randf_range(-0.005, 0.005)
			var noise_pct := monthly_return * 100.0
			print("Resolver: noise applied asset=%s points=0 noise_return=%+.3f%%" % [asset_id, noise_pct])
		var new_invested := int(round(invested * (1.0 + monthly_return)))
		if new_invested < 0:
			new_invested = 0
		new_allocated[asset_id] = new_invested
		var return_pct := monthly_return * 100.0
		breakdown[asset_id] = {
			"invested": invested,
			"new_invested": new_invested,
			"points": points_sum,
			"return_pct": return_pct,
		}
		print("Resolver: %s invested %d -> %d points=%d return=%.3f%%" % [asset_id, invested, new_invested, points_sum, return_pct])

	var total_value := int(unallocated_funds)
	for value in new_allocated.values():
		total_value += int(value)

	return {
		"new_allocated_by_asset": new_allocated,
		"total_value": total_value,
		"debug_breakdown": breakdown,
	}

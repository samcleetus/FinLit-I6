extends RefCounted
class_name MonthResolver

const STEP_SIZE_EASY := 0.015
const STEP_SIZE_NORMAL := 0.01
const STEP_SIZE_HARD := 0.0075
const RETURN_CLAMP_MIN := -0.05
const RETURN_CLAMP_MAX := 0.05
const CENTS_PER_DOLLAR := 100.0
const MULTIPLIER_EASY := 3.0
const MULTIPLIER_NORMAL := 2.0
const MULTIPLIER_HARD := 1.25
const RETURN_CLAMP_EASY := Vector2(-0.08, 0.08)
const RETURN_CLAMP_NORMAL := Vector2(-0.06, 0.06)
const RETURN_CLAMP_HARD := Vector2(-0.04, 0.04)
const DEFAULT_LEVEL := 1


static func calculate_percent_return(points: int, difficulty: String) -> float:
	var normalized := _normalize_difficulty(difficulty)
	var step_size := _get_step_size(normalized)
	var percent_return := float(points) * step_size
	return clamp(percent_return, RETURN_CLAMP_MIN, RETURN_CLAMP_MAX)


static func _normalize_difficulty(difficulty: String) -> String:
	var normalized := difficulty.to_lower()
	if normalized == "easy" or normalized == "normal" or normalized == "medium" or normalized == "hard":
		return normalized
	push_warning("MonthResolver: unknown difficulty '%s'; defaulting to normal." % difficulty)
	return "normal"


static func _get_step_size(normalized_difficulty: String) -> float:
	match normalized_difficulty:
		"easy":
			return STEP_SIZE_EASY
		"hard":
			return STEP_SIZE_HARD
		_:
			return STEP_SIZE_NORMAL


static func _get_difficulty_multiplier(normalized_difficulty: String) -> float:
	match normalized_difficulty:
		"easy":
			return MULTIPLIER_EASY
		"hard":
			return MULTIPLIER_HARD
		_:
			return MULTIPLIER_NORMAL


static func _get_return_clamp(normalized_difficulty: String) -> Vector2:
	match normalized_difficulty:
		"easy":
			return RETURN_CLAMP_EASY
		"hard":
			return RETURN_CLAMP_HARD
		_:
			return RETURN_CLAMP_NORMAL


static func _format_cents_for_display(amount_cents: int, normalized_difficulty: String) -> String:
	var dollars := float(amount_cents) / CENTS_PER_DOLLAR
	if normalized_difficulty == "hard":
		return "$%.2f" % dollars
	return "$%d" % int(round(dollars))


static func debug_regression_check_returns() -> void:
	# Quick manual regression checks:
	# - points=+1 yields larger percent on Easy than Hard
	# - points=-1 yields a negative percent with larger magnitude on Easy than Hard
	# - points=0 uses noise only in resolve_month_step; helper returns 0 (no step applied)
	var easy_pos := calculate_percent_return(1, "Easy")
	var hard_pos := calculate_percent_return(1, "Hard")
	assert(easy_pos > hard_pos)
	var easy_neg := calculate_percent_return(-1, "Easy")
	var hard_neg := calculate_percent_return(-1, "Hard")
	assert(easy_neg < 0.0 and hard_neg < 0.0)
	assert(abs(easy_neg) > abs(hard_neg))
	assert(calculate_percent_return(0, "Easy") == 0.0)


static func get_deterministic_rng(run_seed: int, year: int, month: int, asset_id: String) -> RandomNumberGenerator:
	var combined_text: String = "%s_%s_%s_%s" % [run_seed, year, month, asset_id]
	var seed_value: int = abs(hash(combined_text))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func resolve_month_step(
	behavior_matrix: BehaviorMatrix,
	scenario,
	allocated_by_asset: Dictionary,
	unallocated_funds: int,
	month_step: int = -1,
	run_seed: int = 0,
	current_indicator_levels: Dictionary = {},
	difficulty: String = "Normal"
	) -> Dictionary:
	
	if allocated_by_asset == null or typeof(allocated_by_asset) != TYPE_DICTIONARY:
		allocated_by_asset = {}

	var indicator_ids: Array[String] = []
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
		var level: int = DEFAULT_LEVEL
		if typeof(current_indicator_levels) == TYPE_DICTIONARY and current_indicator_levels.has(indicator_id):
			level = int(current_indicator_levels[indicator_id])
		elif scenario != null and scenario.has_method("get_level"):
			level = scenario.get_level(indicator_id, DEFAULT_LEVEL)
		elif level_map.has(indicator_id):
			level = int(level_map[indicator_id])
		resolved_levels[indicator_id] = level

	var debug_month: int = month_step if month_step >= 0 else -1
	print("Resolver: month_step=%d indicators=%s levels=%s" % [debug_month, indicator_ids, resolved_levels])

	var new_allocated: Dictionary = {}
	var breakdown: Dictionary = {}
	var behavior_available: bool = behavior_matrix != null
	var year_index: int = 0
	if scenario != null and "year_index" in scenario:
		year_index = int(scenario.year_index)
	var normalized_difficulty := _normalize_difficulty(difficulty)
	var step_size := _get_step_size(normalized_difficulty)
	var multiplier := _get_difficulty_multiplier(normalized_difficulty)
	var return_clamp := _get_return_clamp(normalized_difficulty)

	for asset_id in allocated_by_asset.keys():
		var invested: int = int(allocated_by_asset.get(asset_id, 0))
		var points_sum: int = 0
		for indicator_id in indicator_ids:
			var level_value: int = int(resolved_levels.get(indicator_id, DEFAULT_LEVEL))
			if behavior_available:
				points_sum += behavior_matrix.get_effect_points(asset_id, indicator_id, level_value)
		var base_percent_return: float = 0.0
		var noise_applied := false
		if points_sum == 0:
			var rng: RandomNumberGenerator = get_deterministic_rng(run_seed, year_index, month_step, asset_id)
			base_percent_return = rng.randf_range(-0.005, 0.005)
			noise_applied = true
			base_percent_return = clamp(base_percent_return, RETURN_CLAMP_MIN, RETURN_CLAMP_MAX)
		else:
			base_percent_return = calculate_percent_return(points_sum, normalized_difficulty)
		var scaled_return := base_percent_return * multiplier
		var monthly_return: float = clamp(scaled_return, return_clamp.x, return_clamp.y)
		var new_invested: int = int(round(invested * (1.0 + monthly_return)))
		if new_invested < 0:
			new_invested = 0
		new_allocated[asset_id] = new_invested
		var base_pct: float = base_percent_return * 100.0
		var scaled_pct: float = scaled_return * 100.0
		var return_pct: float = monthly_return * 100.0
		breakdown[asset_id] = {
			"invested": invested,
			"new_invested": new_invested,
			"points": points_sum,
			"return_pct": return_pct,
		}
		var noise_text := "true" if noise_applied else "false"
		var display_value := _format_cents_for_display(new_invested, normalized_difficulty)
		print("Resolver: return asset=%s points=%d step=%.2f%% base=%+.2f%% mult=%.2f scaled=%+.2f%% clamped=%+.2f%% cents=%d->%d display=%s (noise=%s)" % [asset_id, points_sum, step_size * 100.0, base_pct, multiplier, scaled_pct, return_pct, invested, new_invested, display_value, noise_text])

	var total_value: int = int(round(unallocated_funds))
	for value in new_allocated.values():
		total_value += int(round(value))

	return {
		"new_allocated_by_asset": new_allocated,
		"total_value": total_value,
		"debug_breakdown": breakdown,
	}

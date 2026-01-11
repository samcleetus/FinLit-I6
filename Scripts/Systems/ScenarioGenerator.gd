extends RefCounted
class_name ScenarioGenerator

const LEVEL_LOW := 0
const LEVEL_MID := 1
const LEVEL_HIGH := 2


static func generate_year(
	year_index: int,
	prev: YearScenario,
	run_seed: int,
	difficulty: String,
	_time_horizon: int,
	available_indicator_ids: Array[String],
	config: ScenarioGeneratorConfig
	) -> YearScenario:
	
	# time_horizon reserved for future use
	#_ = time_horizon

	var scenario := YearScenario.new()
	scenario.year_index = year_index

	var scenario_seed := _make_seed(run_seed, year_index)
	var rng := RandomNumberGenerator.new()
	rng.seed = scenario_seed
	scenario.seed_used = scenario_seed

	if available_indicator_ids.is_empty():
		push_warning("ScenarioGenerator: no available indicators provided for year %d." % year_index)
		return scenario

	if config == null:
		push_warning("ScenarioGenerator: config was null; returning empty scenario.")
		return scenario

	var normalized_diff := _normalize_difficulty(difficulty)
	var desired_count := _pick_desired_count(normalized_diff, config, rng)
	desired_count = clamp(desired_count, 0, available_indicator_ids.size())

	var prev_ids: Array[String] = []
	if year_index > 0 and prev != null and not prev.indicator_ids.is_empty():
		prev_ids = prev.indicator_ids

	var indicator_ids := _pick_indicator_ids(prev_ids, available_indicator_ids, desired_count, config, rng)
	scenario.indicator_ids = indicator_ids

	for indicator_id in indicator_ids:
		var result := {"level": LEVEL_MID, "shocked": false}
		if prev != null and prev.indicator_levels.has(indicator_id):
			var prev_level := prev.get_level(indicator_id, LEVEL_MID)
			result = _transition_level(prev_level, normalized_diff, config, rng)
		scenario.set_level(indicator_id, int(result.get("level", LEVEL_MID)))
		if result.get("shocked", false):
			scenario.shocks_triggered.append(indicator_id)

	return scenario


static func _make_seed(run_seed: int, year_index: int) -> int:
	var mixed := int((run_seed * 73856093) ^ (year_index * 19349663))
	return abs(mixed)


static func _pick_desired_count(difficulty: String, config: ScenarioGeneratorConfig, rng: RandomNumberGenerator) -> int:
	var count_range := config.get_indicator_count_range(difficulty)
	var min_count := int(max(0, count_range.x))
	var max_count := int(max(min_count, count_range.y))
	return rng.randi_range(min_count, max_count)


static func _pick_indicator_ids(prev_ids: Array[String], available_ids: Array[String], desired_count: int, config: ScenarioGeneratorConfig, rng: RandomNumberGenerator) -> Array[String]:
	var chosen: Array[String] = []
	if desired_count <= 0:
		return chosen

	if not prev_ids.is_empty():
		var valid_prev: Array[String] = []
		for id in prev_ids:
			if available_ids.has(id):
				valid_prev.append(id)

		var prev_count := valid_prev.size()
		if prev_count > 0:
			var min_carry := int(floor(prev_count * config.carryover_min_ratio))
			var max_carry := int(ceil(prev_count * config.carryover_max_ratio))
			min_carry = clamp(min_carry, 0, prev_count)
			max_carry = clamp(max_carry, min_carry, prev_count)
			max_carry = min(max_carry, desired_count)
			min_carry = min(min_carry, max_carry)

			var carry_count := min_carry
			if max_carry > min_carry:
				carry_count = rng.randi_range(min_carry, max_carry)
			chosen.append_array(_sample_ids(valid_prev, carry_count, rng))

	var remaining := desired_count - chosen.size()
	if remaining > 0:
		var candidates: Array[String] = []
		for id in available_ids:
			if chosen.has(id):
				continue
			candidates.append(id)
		chosen.append_array(_sample_ids(candidates, remaining, rng))

	return chosen


static func _transition_level(prev_level: int, difficulty: String, config: ScenarioGeneratorConfig, rng: RandomNumberGenerator) -> Dictionary:
	var probs := config.get_transition_probs(difficulty)
	var shock_prob := float(probs.get("shock", 0.0))
	var stay_prob := float(probs.get("stay", 0.0))
	var step_prob := float(probs.get("step", 0.0))
	var roll := rng.randf()

	if roll < shock_prob:
		return {"level": _apply_shock(prev_level, config, rng), "shocked": true}
	elif roll < shock_prob + stay_prob:
		return {"level": prev_level, "shocked": false}
	elif roll < shock_prob + stay_prob + step_prob:
		return {"level": _apply_step(prev_level, rng), "shocked": false}

	return {"level": prev_level, "shocked": false}


static func _apply_shock(prev_level: int, config: ScenarioGeneratorConfig, rng: RandomNumberGenerator) -> int:
	var extreme_prob: float = max(0.0, config.shock_extreme_prob)
	var step_prob: float = max(0.0, config.shock_step_prob)
	var total := extreme_prob + step_prob
	var use_extreme := true if total <= 0.0 else rng.randf() < (extreme_prob / total)
	if use_extreme:
		match prev_level:
			LEVEL_LOW:
				return LEVEL_HIGH
			LEVEL_HIGH:
				return LEVEL_LOW
			_:
				return LEVEL_LOW if rng.randf() < 0.5 else LEVEL_HIGH
	else:
		return _apply_step(prev_level, rng)


static func _apply_step(prev_level: int, rng: RandomNumberGenerator) -> int:
	match prev_level:
		LEVEL_LOW:
			return LEVEL_MID
		LEVEL_HIGH:
			return LEVEL_MID
		_:
			return LEVEL_LOW if rng.randf() < 0.5 else LEVEL_HIGH


static func _sample_ids(pool: Array[String], count: int, rng: RandomNumberGenerator) -> Array[String]:
	var result: Array[String] = []
	if count <= 0 or pool.is_empty():
		return result

	var mutable := pool.duplicate()
	while result.size() < count and not mutable.is_empty():
		var idx := rng.randi_range(0, mutable.size() - 1)
		result.append(mutable[idx])
		mutable.remove_at(idx)
	return result


static func _normalize_difficulty(difficulty: String) -> String:
	var normalized := difficulty.to_lower()
	if normalized == "easy" or normalized == "medium" or normalized == "hard":
		return normalized
	push_warning("ScenarioGenerator: unknown difficulty '%s'; defaulting to medium." % difficulty)
	return "medium"

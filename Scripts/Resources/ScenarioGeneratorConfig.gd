extends Resource
class_name ScenarioGeneratorConfig

@export var easy_min_indicators: int = 0
@export var easy_max_indicators: int = 0
@export var medium_min_indicators: int = 0
@export var medium_max_indicators: int = 0
@export var hard_min_indicators: int = 0
@export var hard_max_indicators: int = 0

@export var easy_stay_prob: float = 0.0
@export var easy_step_prob: float = 0.0
@export var easy_shock_prob: float = 0.0
@export var medium_stay_prob: float = 0.0
@export var medium_step_prob: float = 0.0
@export var medium_shock_prob: float = 0.0
@export var hard_stay_prob: float = 0.0
@export var hard_step_prob: float = 0.0
@export var hard_shock_prob: float = 0.0

@export var carryover_min_ratio: float = 0.0
@export var carryover_max_ratio: float = 1.0
@export var shock_extreme_prob: float = 0.5
@export var shock_step_prob: float = 0.5


func get_indicator_count_range(difficulty: String) -> Vector2i:
	var normalized := difficulty.to_lower()
	match normalized:
		"easy":
			return Vector2i(easy_min_indicators, easy_max_indicators)
		"medium":
			return Vector2i(medium_min_indicators, medium_max_indicators)
		"hard":
			return Vector2i(hard_min_indicators, hard_max_indicators)
	push_warning("Unknown difficulty '%s' for indicator count range." % difficulty)
	return Vector2i.ZERO


func get_transition_probs(difficulty: String) -> Dictionary:
	var normalized := difficulty.to_lower()
	match normalized:
		"easy":
			return {"stay": easy_stay_prob, "step": easy_step_prob, "shock": easy_shock_prob}
		"medium":
			return {"stay": medium_stay_prob, "step": medium_step_prob, "shock": medium_shock_prob}
		"hard":
			return {"stay": hard_stay_prob, "step": hard_step_prob, "shock": hard_shock_prob}
	push_warning("Unknown difficulty '%s' for transition probabilities." % difficulty)
	return {"stay": 0.0, "step": 0.0, "shock": 0.0}


func clamp_and_validate() -> void:
	carryover_min_ratio = _clamp01(carryover_min_ratio, "carryover_min_ratio")
	carryover_max_ratio = _clamp01(carryover_max_ratio, "carryover_max_ratio")
	if carryover_min_ratio > carryover_max_ratio:
		push_warning("carryover_min_ratio (%.3f) exceeded carryover_max_ratio (%.3f); values swapped." % [carryover_min_ratio, carryover_max_ratio])
		var temp := carryover_min_ratio
		carryover_min_ratio = carryover_max_ratio
		carryover_max_ratio = temp

	easy_stay_prob = _clamp01(easy_stay_prob, "easy_stay_prob")
	easy_step_prob = _clamp01(easy_step_prob, "easy_step_prob")
	easy_shock_prob = _clamp01(easy_shock_prob, "easy_shock_prob")

	medium_stay_prob = _clamp01(medium_stay_prob, "medium_stay_prob")
	medium_step_prob = _clamp01(medium_step_prob, "medium_step_prob")
	medium_shock_prob = _clamp01(medium_shock_prob, "medium_shock_prob")

	hard_stay_prob = _clamp01(hard_stay_prob, "hard_stay_prob")
	hard_step_prob = _clamp01(hard_step_prob, "hard_step_prob")
	hard_shock_prob = _clamp01(hard_shock_prob, "hard_shock_prob")

	shock_extreme_prob = _clamp01(shock_extreme_prob, "shock_extreme_prob")
	shock_step_prob = _clamp01(shock_step_prob, "shock_step_prob")

	var shock_total := shock_extreme_prob + shock_step_prob
	if absf(shock_total - 1.0) > 0.05:
		push_warning("Shock probabilities sum to %.3f (expected ~1.0)." % shock_total)


func _clamp01(value: float, label: String) -> float:
	var clamped: float = clamp(value, 0.0, 1.0)
	if clamped != value:
		push_warning("%s clamped from %.3f to %.3f" % [label, value, clamped])
	return clamped

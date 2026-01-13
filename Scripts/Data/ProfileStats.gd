extends Resource
class_name ProfileStats

@export var data_version: int = 1
@export var total_runs_completed: int = 0
@export var best_run_total_cents: int = 0
@export var total_allocations_made: int = 0
@export var indicator_exposure_counts: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"data_version": data_version,
		"total_runs_completed": total_runs_completed,
		"best_run_total_cents": best_run_total_cents,
		"total_allocations_made": total_allocations_made,
		"indicator_exposure_counts": indicator_exposure_counts,
	}


static func from_dict(d: Dictionary) -> ProfileStats:
	var stats := ProfileStats.new()
	stats.data_version = int(d.get("data_version", stats.data_version))
	stats.total_runs_completed = int(d.get("total_runs_completed", stats.total_runs_completed))
	stats.best_run_total_cents = int(d.get("best_run_total_cents", stats.best_run_total_cents))
	stats.total_allocations_made = int(d.get("total_allocations_made", stats.total_allocations_made))
	var exposure: Variant = d.get("indicator_exposure_counts", stats.indicator_exposure_counts)
	if typeof(exposure) == TYPE_DICTIONARY:
		stats.indicator_exposure_counts = exposure.duplicate()
	else:
		stats.indicator_exposure_counts = {}
	return stats


func reset() -> void:
	data_version = 1
	total_runs_completed = 0
	best_run_total_cents = 0
	total_allocations_made = 0
	indicator_exposure_counts.clear()

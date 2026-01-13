extends RefCounted
class_name ProfileViewModel

var total_runs_completed: int = 0
var best_run_display: String = ""
var total_allocations_made: int = 0


static func from_stats(stats: ProfileStats, show_cents: bool) -> ProfileViewModel:
	var vm := ProfileViewModel.new()
	if stats == null:
		vm.best_run_display = _format_best_run_display(0, show_cents)
		return vm

	vm.total_runs_completed = stats.total_runs_completed
	vm.total_allocations_made = stats.total_allocations_made
	vm.best_run_display = _format_best_run_display(stats.best_run_total_cents, show_cents)
	return vm


static func _format_best_run_display(amount_cents: int, show_cents: bool) -> String:
	var dollars_value := float(amount_cents) / 100.0
	if show_cents:
		return "$%.2f" % dollars_value
	return "$%d" % int(round(dollars_value))

extends RefCounted
class_name ProfileViewModel

var total_runs_completed: int = 0
var best_run_display: String = ""
var total_allocations_made: int = 0
var favorite_asset_name: String = ""
var biggest_year_gain_display: String = ""
var biggest_year_loss_display: String = ""


static func from_stats(stats: ProfileStats, show_cents: bool, p_favorite_asset_name: String = "") -> ProfileViewModel:
	var vm := ProfileViewModel.new()
	if stats == null:
		vm.best_run_display = _format_currency_display(0, show_cents)
		vm.biggest_year_gain_display = _format_currency_display(0, show_cents)
		vm.biggest_year_loss_display = _format_signed_currency_display(0, show_cents)
		vm.favorite_asset_name = "None"
		return vm

	vm.total_runs_completed = stats.total_runs_completed
	vm.total_allocations_made = stats.total_allocations_made
	vm.best_run_display = _format_currency_display(stats.best_run_total_cents, show_cents)
	vm.biggest_year_gain_display = _format_signed_currency_display(stats.biggest_year_gain_cents, show_cents)
	vm.biggest_year_loss_display = _format_signed_currency_display(stats.biggest_year_loss_cents, show_cents)
	vm.favorite_asset_name = p_favorite_asset_name if p_favorite_asset_name != "" else "None"
	return vm


static func _format_currency_display(amount_cents: int, show_cents: bool) -> String:
	var dollars_value := float(amount_cents) / 100.0
	if show_cents:
		return "$%.2f" % dollars_value
	return "$%d" % int(round(dollars_value))


static func _format_signed_currency_display(amount_cents: int, show_cents: bool) -> String:
	var abs_cents: int = abs(amount_cents)
	var formatted := _format_currency_display(abs_cents, show_cents)
	if amount_cents < 0:
		return "-%s" % formatted
	return formatted

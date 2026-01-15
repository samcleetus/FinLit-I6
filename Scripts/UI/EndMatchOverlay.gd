extends Control

@onready var _net_name_label: Label = get_node_or_null("Card/StatsVBox/StatRow1/NameLabel")
@onready var _net_value_label: Label = get_node_or_null("Card/StatsVBox/StatRow1/ValueLabel")
@onready var _best_name_label: Label = get_node_or_null("Card/StatsVBox/StatRow2/NameLabel")
@onready var _best_value_label: Label = get_node_or_null("Card/StatsVBox/StatRow2/ValueLabel")
@onready var _worst_name_label: Label = get_node_or_null("Card/StatsVBox/StatRow3/NameLabel")
@onready var _worst_value_label: Label = get_node_or_null("Card/StatsVBox/StatRow3/ValueLabel")


func _ready() -> void:
	_set_stat_row(_net_name_label, _net_value_label, "Net Gain/Loss", "")
	_set_stat_row(_best_name_label, _best_value_label, "Best Asset", "")
	_set_stat_row(_worst_name_label, _worst_value_label, "Worst Asset", "")


func render_summary() -> void:
	var summary := GameManager.get_end_year_match_summary()
	var net_cents := int(summary.get("net_cents", 0))
	var best_id := str(summary.get("best_asset_id", ""))
	var best_delta := int(summary.get("best_asset_delta_cents", 0))
	var worst_id := str(summary.get("worst_asset_id", ""))
	var worst_delta := int(summary.get("worst_asset_delta_cents", 0))

	var net_text := format_cents(net_cents, net_cents > 0)
	_set_stat_row(_net_name_label, _net_value_label, "Net Gain/Loss", net_text)

	var best_name := _resolve_asset_display(best_id)
	if best_name == "":
		best_name = "None"
	var best_text := "%s (%s)" % [best_name, format_cents(best_delta, true)]
	_set_stat_row(_best_name_label, _best_value_label, "Best Asset", best_text)

	var worst_name := _resolve_asset_display(worst_id)
	if worst_name == "":
		worst_name = "None"
	var worst_text := "%s (%s)" % [worst_name, format_cents(worst_delta, true)]
	_set_stat_row(_worst_name_label, _worst_value_label, "Worst Asset", worst_text)

	print("EndMatchOverlay: render_summary -> net=%s best=%s worst=%s" % [net_text, best_text, worst_text])


func format_cents(cents: int, force_sign: bool = false) -> String:
	var abs_value: int = abs(cents)
	var base := "$%.2f" % (float(abs_value) / 100.0)
	if abs_value % 100 == 0:
		base = "$%d" % int(float(abs_value) / 100.0)
	if cents < 0:
		return "-%s" % base
	if force_sign and cents > 0:
		return "+%s" % base
	return base


func _resolve_asset_display(asset_id: String) -> String:
	if asset_id == "":
		return ""
	var asset_name := GameManager.get_asset_display_name(asset_id)
	if asset_name == null:
		return ""
	var trimmed := str(asset_name).strip_edges()
	return trimmed


func _set_stat_row(name_label: Label, value_label: Label, name_text: String, value_text: String) -> void:
	if name_label:
		name_label.text = name_text
	if value_label:
		value_label.text = value_text

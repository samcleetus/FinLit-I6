extends Resource
class_name RunState

@export var run_id: String = ""
@export var current_year_index: int = 0
@export var chosen_asset_ids: Array[String] = []
@export var hand_asset_ids: PackedStringArray = PackedStringArray(["", "", "", ""])
@export var hand_lock_years_remaining: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
@export var run_history: Array = []
@export var total_funds: int = 10000
@export var total_value: int = 10000
@export var unallocated_funds: int = 10000
@export var allocated_by_asset: Dictionary = {}
@export var portfolio_cents_by_asset_id: Dictionary = {}
@export var current_month: int = 0
@export var match_started: bool = false
@export var current_indicator_levels: Dictionary = {}
@export var current_indicator_percents: Dictionary = {}
@export var indicator_momentum: Dictionary = {}
@export var currency_in_cents: bool = false
@export var year_start_total_cents: int = 0


func reset_history() -> void:
	run_history.clear()

extends Resource
class_name RunState

@export var run_id: String = ""
@export var current_year_index: int = 0
@export var chosen_asset_ids: Array[String] = []
@export var run_history: Array = []
@export var total_funds: int = 10000
@export var unallocated_funds: int = 10000
@export var allocated_by_asset: Dictionary = {}


func reset_history() -> void:
	run_history.clear()

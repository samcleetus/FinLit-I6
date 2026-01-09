extends Resource
class_name AppSettings

@export var time_horizon: float = 30.0
@export_enum("easy", "normal", "hard") var difficulty: String = "normal"
@export_enum("practice", "normal") var mode: String = "normal"

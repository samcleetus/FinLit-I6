extends Resource
class_name AppSettings

@export var time_horizon = "12 months"
@export var difficulty = "Normal"
@export_enum("practice", "normal") var mode: String = "normal"

extends Resource
class_name AppSettings

@export var time_horizon: int = 12
@export var difficulty: String = "Normal"
@export var should_show_boot: bool = true
@export var data_version: int = 1
# Maintained for compatibility with existing run flow contracts.
@export var mode: String = "normal"


static func from_dict(data: Dictionary) -> AppSettings:
	var settings := AppSettings.new()
	settings.time_horizon = int(data.get("time_horizon", settings.time_horizon))
	settings.difficulty = str(data.get("difficulty", settings.difficulty))
	settings.should_show_boot = bool(data.get("should_show_boot", settings.should_show_boot))
	settings.data_version = int(data.get("data_version", settings.data_version))
	settings.mode = str(data.get("mode", settings.mode))
	return settings


func to_dict() -> Dictionary:
	return {
		"time_horizon": time_horizon,
		"difficulty": difficulty,
		"should_show_boot": should_show_boot,
		"data_version": data_version,
		"mode": mode,
	}


func clone() -> AppSettings:
	var copy := AppSettings.new()
	copy.time_horizon = time_horizon
	copy.difficulty = difficulty
	copy.should_show_boot = should_show_boot
	copy.data_version = data_version
	copy.mode = mode
	return copy

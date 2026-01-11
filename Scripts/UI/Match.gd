extends Control


func _ready() -> void:
	var mode := GameManager.get_session_mode()
	var state: RunState = GameManager.get_run_state()
	var run_id: String = state.run_id if state else "none"
	print("Match: _ready -> session_mode=%s run_id=%s" % [_session_mode_to_string(mode), run_id])


func _session_mode_to_string(mode: int) -> String:
	match mode:
		GameManager.SessionMode.RUN:
			return "RUN"
		GameManager.SessionMode.PRACTICE:
			return "PRACTICE"
		GameManager.SessionMode.NONE:
			return "NONE"
		_:
			return "UNKNOWN"

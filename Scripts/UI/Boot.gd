extends Control


func _ready() -> void:
	print("Boot: _ready called")
	if not GameManager.should_show_boot():
		print("Boot: should_show_boot is false, routing to Main Menu")
		GameManager.go_to_main_menu()

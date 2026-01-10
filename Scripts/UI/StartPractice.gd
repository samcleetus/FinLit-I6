extends Control


func _ready() -> void:
	print("StartPractice: _ready called")
	_connect_back_button()


func _connect_back_button() -> void:
	var node := get_node_or_null("BackButton")
	if node == null:
		print("StartPractice: Missing BackButton at path BackButton")
		return
	var button := node as Button
	if button == null:
		print("StartPractice: Node at BackButton is not a Button")
		return
	button.pressed.connect(func() -> void: GameManager.go_to_main_menu())

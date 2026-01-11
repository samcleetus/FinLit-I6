extends Resource
class_name Asset

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export var description: String = "" # How many years the asset stays locked after being used; 1 means only the next match.
@export var duration_years: int = 1
@export var starting_unlocked: bool = false

extends RefCounted
class_name AssetSlotViewModel

var slot_index: int = 0
var asset_id: String = ""
var display_name: String = ""
var icon: Texture2D = null


func _init(_slot_index: int = 0, _asset_id: String = "", _display_name: String = "", _icon: Texture2D = null) -> void:
	slot_index = _slot_index
	asset_id = _asset_id
	display_name = _display_name
	icon = _icon


func is_empty() -> bool:
	return asset_id == "" and display_name == "" and icon == null


func to_debug_string() -> String:
	return "AssetSlot(index=%d, id=%s, name=%s, icon=%s)" % [slot_index, asset_id, display_name, icon]

extends Resource
class_name AssetDB

@export var assets: Array[Asset] = []

var _index: Dictionary = {}


func get_all() -> Array[Asset]:
	return assets


func get_by_id(asset_id: String) -> Asset:
	if _index.is_empty():
		rebuild_index()
	if _index.is_empty():
		return null
	if _index.has(asset_id):
		return _index[asset_id]
	return null


func rebuild_index() -> void:
	_index.clear()
	for asset in assets:
		if asset == null:
			print("AssetDB: null asset entry skipped")
			continue
		if asset.id == "":
			print("AssetDB: asset with empty id skipped (display_name=%s)" % asset.display_name)
			continue
		if _index.has(asset.id):
			print("AssetDB: duplicate id '%s' found, keeping first and skipping %s" % [asset.id, asset.display_name])
			continue
		_index[asset.id] = asset

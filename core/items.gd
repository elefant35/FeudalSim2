extends Node
## Item and crop database, loaded from .tres files. Autoloaded as `Items`.

const DATA_DIRS: Array[String] = ["res://farming/data/items", "res://farming/data/crops", "res://milling/data/items"]
const QUALITY_NAMES: Array[String] = ["Poor", "Fair", "Good", "Fine"]
const QUALITY_PRICE: Array[float] = [0.6, 1.0, 1.35, 1.75]

var _items: Dictionary = {}   # StringName -> ItemData
var _crops: Dictionary = {}   # StringName -> CropData


func _ready() -> void:
	for dir in DATA_DIRS:
		for res in _load_dir(dir):
			if res is ItemData:
				_items[res.id] = res
			elif res is CropData:
				_crops[res.id] = res


func _load_dir(path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	for file in DirAccess.get_files_at(path):
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres"):
			out.append(load(path.path_join(file)))
	return out


func item(id: StringName) -> ItemData:
	return _items.get(id)


func crop(id: StringName) -> CropData:
	return _crops.get(id)


func all_items() -> Array:
	return _items.values()


func name_of(id: StringName, quality: int = -1) -> String:
	var it := item(id)
	var n: String = it.display_name if it else String(id)
	if quality >= 0:
		n = "%s %s" % [QUALITY_NAMES[quality], n.to_lower()]
	return n


## The model that stands for one unit when carried, piled or carted (a sack, or the item itself).
func carry_model(id: StringName) -> StringName:
	var it := item(id)
	return it.sack_model if it and it.sack_model != &"" else id


func is_sacked(id: StringName) -> bool:
	return carry_model(id) != id


## What the produce buyer pays for one unit.
func sell_value(id: StringName, quality: int) -> int:
	var it := item(id)
	if it == null or it.sell_price <= 0:
		return 0
	var mult := QUALITY_PRICE[quality] if quality >= 0 else 1.0
	return maxi(1, roundi(it.sell_price * mult))

class_name ItemTile
extends PanelContainer
## One square showing an item: its icon, a count, a quality mark and (on the hotbar) its key.
## Used by the HUD hotbar and the pack. Can be dragged, and can accept drops.

signal pressed(tile: ItemTile, button: int, double: bool)
signal dropped(tile: ItemTile, data: Dictionary)

const QUALITY_COLORS: Array[Color] = [Color(0.7, 0.45, 0.35), Color(0.85, 0.82, 0.7), Color(0.55, 0.8, 0.45), Color(0.95, 0.8, 0.3)]

var id: StringName = &""
var quality: int = -1
var count: int = 0
var slot: int = -1            ## Hotbar slot index, or -1 for a pack tile.
var key_text: String = ""
var selected: bool = false
var dimmed: bool = false
var draggable: bool = false
var accepts_drops: bool = false
var tile_size: float = 72.0
var interactive: bool = false   ## Pack/hotbar editing tiles take clicks; HUD tiles don't.

var _icon := TextureRect.new()
var _key := Label.new()
var _count := Label.new()
var _qual := ColorRect.new()


func _ready() -> void:
	custom_minimum_size = Vector2(tile_size, tile_size)
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_icon)
	for l: Label in [_key, _count]:
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_constant_override("outline_size", 5)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(l)
	_key.position = Vector2(-2, -6)
	_count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_count.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_count.position += Vector2(2, 4)
	_qual.size = Vector2(9, 9)
	_qual.position = Vector2(tile_size - 22, -2)
	_qual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_qual)
	Icons.icon_ready.connect(_on_icon_ready)
	refresh()


func set_item(new_id: StringName, new_quality: int = -1, new_count: int = 0) -> void:
	id = new_id
	quality = new_quality
	count = new_count
	if is_inside_tree():
		refresh()


func refresh() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.1, 0.07, 0.9)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(5)
	style.border_color = Color(0.9, 0.72, 0.36) if selected else Color(0.36, 0.28, 0.18)
	style.set_border_width_all(3 if selected else 1)
	add_theme_stylebox_override("panel", style)
	_icon.texture = Icons.get_icon(id) if id != &"" else null
	_icon.modulate = Color(1, 1, 1, 0.35) if dimmed else Color.WHITE
	_key.text = key_text
	_key.add_theme_color_override("font_color", Color(0.9, 0.72, 0.36) if selected else Color(0.85, 0.8, 0.68))
	_count.text = str(count) if count > 1 or (count == 0 and id != &"" and dimmed) else ""
	_qual.visible = quality >= 0
	if quality >= 0:
		_qual.color = QUALITY_COLORS[quality]
	tooltip_text = _tooltip()


func _tooltip() -> String:
	if id == &"":
		return "Empty slot" if slot >= 0 else ""
	if id == Player.HANDS:
		return "Bare hands: pull weeds and crops, pick pests, bind sheaves."
	var it := Items.item(id)
	if it == null:
		return String(id)
	var t := Items.name_of(id, quality)
	if count > 1:
		t += "  ×%d" % count
	if it.description != "":
		t += "\n" + it.description
	return t


func _on_icon_ready(icon_id: StringName) -> void:
	if icon_id == id:
		_icon.texture = Icons.get_icon(id)


var _press_at := Vector2.INF
var _press_double := false


## A click fires on release, and only if the mouse didn't move (moving starts a drag instead).
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed:
		_press_at = mb.position
		_press_double = mb.double_click
	elif _press_at != Vector2.INF and mb.position.distance_to(_press_at) < 6.0:
		pressed.emit(self, mb.button_index, _press_double)
		_press_at = Vector2.INF
	accept_event()


func _get_drag_data(_at: Vector2) -> Variant:
	if not draggable or id == &"" or id == Player.HANDS:
		return null
	var preview := TextureRect.new()
	preview.texture = _icon.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(56, 56)
	preview.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(preview)
	return {"id": id, "from_slot": slot}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return accepts_drops and data is Dictionary and data.has("id")


func _drop_data(_at: Vector2, data: Variant) -> void:
	dropped.emit(self, data)

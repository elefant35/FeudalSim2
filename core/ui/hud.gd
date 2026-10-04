class_name Hud
extends CanvasLayer
## On-screen UI: clock and speed control, needs, gold, hotbar, crosshair prompt, messages,
## minigame overlay, and the panels (inventory, trading, pause menu).

signal new_game_requested
signal save_requested

const INK := Color(0.98, 0.94, 0.82)
const PARCHMENT := Color(0.16, 0.12, 0.08, 0.88)
const ACCENT := Color(0.86, 0.68, 0.32)

var player: Player
var _clock_label := Label.new()
var _speed_button := Button.new()
var _gold_label := Label.new()
var _hunger_bar := ProgressBar.new()
var _energy_bar := ProgressBar.new()
var _hotbar := HBoxContainer.new()
var _prompt := Label.new()
var _hint := Label.new()
var _toasts := VBoxContainer.new()
var _overlay := Control.new()
var _fade := ColorRect.new()
var _panel: PanelContainer = null
var _panel_kind: String = ""
var _trade_rows: Callable


func setup(p: Player) -> void:
	player = p
	player.message.connect(toast)
	player.hotbar_changed.connect(_refresh_hotbar)
	player.inventory.changed.connect(_refresh_hotbar)
	player.wallet.changed.connect(func(_g: int) -> void: _refresh_gold())
	Clock.speed_changed.connect(func(_s: int) -> void: _refresh_speed())
	_refresh_hotbar()
	_refresh_gold()
	_refresh_speed()


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	# Top-left: date, time, weather, speed.
	var tl := _box(VBoxContainer.new(), root, Control.PRESET_TOP_LEFT, Vector2(16, 12))
	_clock_label.add_theme_font_size_override("font_size", 20)
	tl.add_child(_clock_label)
	_speed_button.focus_mode = Control.FOCUS_NONE
	_speed_button.tooltip_text = "Speed up time (T)"
	_speed_button.custom_minimum_size = Vector2(150, 0)
	_speed_button.pressed.connect(Clock.cycle_speed)
	tl.add_child(_speed_button)

	# Top-right: gold.
	var tr := _box(HBoxContainer.new(), root, Control.PRESET_TOP_RIGHT, Vector2(-16, 12))
	_gold_label.add_theme_font_size_override("font_size", 22)
	_gold_label.add_theme_color_override("font_color", ACCENT)
	tr.add_child(_gold_label)

	# Bottom-left: needs.
	var bl := _box(VBoxContainer.new(), root, Control.PRESET_BOTTOM_LEFT, Vector2(16, -16))
	bl.add_child(_bar_row("Hunger", _hunger_bar, Color(0.8, 0.5, 0.25)))
	bl.add_child(_bar_row("Energy", _energy_bar, Color(0.4, 0.6, 0.85)))

	# Bottom-centre: hotbar.
	_hotbar.add_theme_constant_override("separation", 6)
	_hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hotbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hotbar.position.y -= 16
	root.add_child(_hotbar)

	# Centre: crosshair overlay, prompt, minigame hint.
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	root.add_child(_overlay)
	for l: Label in [_prompt, _hint]:
		l.set_anchors_preset(Control.PRESET_CENTER)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.grow_horizontal = Control.GROW_DIRECTION_BOTH
		l.custom_minimum_size = Vector2(700, 0)
		l.position = Vector2(-350, 24)
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		root.add_child(l)
	_hint.position = Vector2(-350, 110)
	_hint.add_theme_color_override("font_color", Color(0.9, 0.86, 0.7))
	_hint.add_theme_font_size_override("font_size", 15)

	# Top-centre: messages.
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.offset_left = -320
	_toasts.offset_right = 320
	_toasts.offset_top = 70
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)

	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func _box(c: Control, parent: Control, preset: int, offset: Vector2) -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(preset)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN if offset.x < 0 else Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN if offset.y < 0 else Control.GROW_DIRECTION_END
	panel.position += offset
	panel.add_child(c)
	parent.add_child(panel)
	return c


func _bar_row(label: String, bar: ProgressBar, color: Color) -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(70, 0)
	row.add_child(l)
	bar.custom_minimum_size = Vector2(200, 16)
	bar.show_percentage = false
	bar.max_value = 100
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.06, 0.04)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	return row


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	t.set_color("font_color", "Label", INK)
	var panel := StyleBoxFlat.new()
	panel.bg_color = PARCHMENT
	panel.set_corner_radius_all(6)
	panel.set_content_margin_all(10)
	panel.border_color = Color(0.45, 0.34, 0.2)
	panel.set_border_width_all(1)
	t.set_stylebox("panel", "PanelContainer", panel)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var b := StyleBoxFlat.new()
		b.bg_color = {"normal": Color(0.32, 0.23, 0.13), "hover": Color(0.45, 0.33, 0.18),
			"pressed": Color(0.55, 0.4, 0.2), "disabled": Color(0.2, 0.17, 0.13)}[state]
		b.set_corner_radius_all(4)
		b.set_content_margin_all(6)
		t.set_stylebox(state, "Button", b)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.5, 0.42))
	return t


# --- Per-frame ------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if player == null:
		return
	var weather := "Rain" if Clock.raining else ("Night" if Clock.is_night() else "Fair")
	_clock_label.text = "%s\n%s   %s" % [Clock.date_string(), Clock.time_string(), weather]
	_hunger_bar.value = player.needs.hunger
	_energy_bar.value = player.needs.energy
	var game := player.minigame
	_prompt.text = "" if game != null else player.prompt()
	_hint.text = (game.hint + "\n[Right-click] stop") if game != null else ""
	_overlay.queue_redraw()


func _draw_overlay() -> void:
	var center := _overlay.size / 2.0
	if player and player.minigame != null:
		player.minigame.draw(_overlay, center)
	elif _panel == null:
		_overlay.draw_circle(center, 3.0, Color(1, 1, 1, 0.85))
		_overlay.draw_arc(center, 5.0, 0, TAU, 16, Color(0, 0, 0, 0.5), 1.0)


func _refresh_speed() -> void:
	_speed_button.text = "Speed: %d×  [T]" % Clock.speed()


func _refresh_gold() -> void:
	_gold_label.text = "%d gold" % player.wallet.gold


func _refresh_hotbar() -> void:
	for c in _hotbar.get_children():
		c.queue_free()
	for i in player.hotbar.size():
		var id := player.hotbar[i]
		var slot := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.12, 0.08, 0.85)
		style.set_corner_radius_all(5)
		style.set_content_margin_all(6)
		style.border_color = ACCENT if i == player.held_index else Color(0.35, 0.27, 0.17)
		style.set_border_width_all(3 if i == player.held_index else 1)
		slot.add_theme_stylebox_override("panel", style)
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 14)
		var name := "Hands" if id == Player.HANDS else Items.name_of(id)
		var count := "" if id == Player.HANDS or Items.item(id).kind == ItemData.Kind.TOOL else " ×%d" % player.inventory.count(id)
		l.text = "%d\n%s%s" % [i + 1, name, count]
		l.custom_minimum_size = Vector2(92, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.add_child(l)
		_hotbar.add_child(slot)


func toast(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_toasts.add_child(l)
	while _toasts.get_child_count() > 4:
		_toasts.get_child(0).free()
	var t := l.create_tween()
	t.tween_interval(3.5)
	t.tween_property(l, "modulate:a", 0.0, 0.8)
	t.tween_callback(l.queue_free)


func fade_to(alpha: float, seconds: float) -> Tween:
	var t := create_tween()
	t.tween_property(_fade, "color:a", alpha, seconds)
	return t


# --- Panels ---------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	if event.is_action_pressed("speed"):
		Clock.cycle_speed()
	elif event.is_action_pressed("pause"):
		if _panel != null:
			close_panel()
		elif player.minigame == null:
			open_pause_menu()
	elif event.is_action_pressed("inventory"):
		if _panel_kind == "inventory":
			close_panel()
		elif _panel == null and player.minigame == null and player.can_act():
			open_inventory()


func is_panel_open() -> bool:
	return _panel != null


func _open_panel(kind: String, title: String) -> VBoxContainer:
	close_panel()
	_panel_kind = kind
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(560, 0)
	_overlay.get_parent().add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	var h := Label.new()
	h.text = title
	h.add_theme_font_size_override("font_size", 24)
	h.add_theme_color_override("font_color", ACCENT)
	v.add_child(h)
	player.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("ui_open", -6.0, 0.0)
	return v


func close_panel() -> void:
	if _panel == null:
		return
	_panel.queue_free()
	_panel = null
	_panel_kind = ""
	get_tree().paused = false
	player.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.play("ui_close", -6.0, 0.0)


func _close_button(v: VBoxContainer, text: String = "Close  [Esc]") -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(close_panel)
	v.add_child(b)


func open_pause_menu() -> void:
	var v := _open_panel("pause", "Paused")
	get_tree().paused = true
	var speeds := HBoxContainer.new()
	var l := Label.new()
	l.text = "Time speed:"
	speeds.add_child(l)
	for i in Clock.SPEEDS.size():
		var b := Button.new()
		b.text = "%d×" % Clock.SPEEDS[i]
		b.toggle_mode = true
		b.button_pressed = Clock.speed_index == i
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			Clock.speed_index = i
			Clock.speed_changed.emit(Clock.speed())
			open_pause_menu())
		speeds.add_child(b)
	v.add_child(speeds)
	var controls := Label.new()
	controls.text = CONTROLS_TEXT
	controls.add_theme_font_size_override("font_size", 14)
	v.add_child(controls)
	for pair: Array in [["Save", func() -> void: save_requested.emit()],
			["New game (erase save)", func() -> void: new_game_requested.emit()],
			["Quit", func() -> void: save_requested.emit(); get_tree().quit()]]:
		var b := Button.new()
		b.text = pair[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(pair[1])
		v.add_child(b)
	_close_button(v, "Resume  [Esc]")


const CONTROLS_TEXT := """WASD move · Shift run · Space jump · Mouse look
Left-click: use what's in your hand · Right-click: stop
E: interact · F: eat · Tab: pack · 1-9 / wheel: choose tool · T: time speed
Sleep in your bed to end the day (the game saves when you sleep)."""


func open_inventory() -> void:
	var v := _open_panel("inventory", "Your pack")
	var stacks := player.inventory.stacks()
	if stacks.is_empty():
		var l := Label.new()
		l.text = "Empty."
		v.add_child(l)
	for s in stacks:
		var it := Items.item(s.id)
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s  ×%d" % [Items.name_of(s.id, s.quality), s.count]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.tooltip_text = it.description if it else ""
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(l)
		if it and it.food_value > 0.0:
			var b := Button.new()
			b.text = "Eat (+%d)" % roundi(it.food_value)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(func() -> void:
				player.eat(s.id, s.quality)
				open_inventory())
			row.add_child(b)
		v.add_child(row)
	_close_button(v, "Close  [Tab]")


## A buy/sell list. `rows` returns an Array of {label, button, enabled, action: Callable};
## it's called again after every action so prices and counts stay current.
func open_trade(title: String, rows: Callable) -> void:
	_trade_rows = rows
	var v := _open_panel("trade", title)
	var gold := Label.new()
	gold.text = "You have %d gold." % player.wallet.gold
	gold.add_theme_color_override("font_color", ACCENT)
	v.add_child(gold)
	var list: Array = rows.call()
	if list.is_empty():
		var l := Label.new()
		l.text = "Nothing to trade."
		v.add_child(l)
	for r: Dictionary in list:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = r.label
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.tooltip_text = r.get("tooltip", "")
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(l)
		for btn: Dictionary in r.buttons:
			var b := Button.new()
			b.text = btn.text
			b.disabled = not btn.enabled
			b.focus_mode = Control.FOCUS_NONE
			var action: Callable = btn.action
			b.pressed.connect(func() -> void:
				action.call()
				open_trade(title, _trade_rows))
			row.add_child(b)
		v.add_child(row)
	_close_button(v)

class_name Hud
extends CanvasLayer
## On-screen UI: clock, speed control and "next step" line (top left), gold (top right), needs
## (bottom left), hotbar (bottom centre), crosshair prompt, messages, minigame overlay, and the
## panels (pack, trading, guide, pause menu).
##
## Laid out for a 1600x900 canvas; the project stretches it to any window size, so text keeps
## its proportions on big and retina screens.

signal new_game_requested
signal save_requested

const INK := Color(0.98, 0.94, 0.82)
const DIM := Color(0.85, 0.8, 0.68)
const PARCHMENT := Color(0.14, 0.1, 0.07, 0.9)
const ACCENT := Color(0.9, 0.72, 0.36)
const FONT := 19

var player: Player
## Returns the "Next:" hint text (set by the world; the farming chunk supplies it).
var objective: Callable
## Returns the field guide as [[heading, body], ...] (also supplied by the world).
var guide_sections: Callable

var _root := Control.new()
var _clock_label := Label.new()
var _speed_button := Button.new()
var _objective_label := Label.new()
var _objective_box: PanelContainer
var _gold_label := Label.new()
var _gold_box: PanelContainer
var _needs_box: PanelContainer
var _hunger_bar := ProgressBar.new()
var _energy_bar := ProgressBar.new()
var _hotbar := HBoxContainer.new()
var _prompt_box := PanelContainer.new()
var _prompt := Label.new()
var _hint_box := PanelContainer.new()
var _hint := Label.new()
var _toasts := VBoxContainer.new()
var _overlay := Control.new()
var _fade := ColorRect.new()
var _panel: PanelContainer = null
var _panel_kind: String = ""
var _trade_rows: Callable
var _objective_timer := 0.0


func setup(p: Player) -> void:
	player = p
	player.message.connect(toast)
	player.hotbar_changed.connect(_refresh_hotbar)
	player.inventory.changed.connect(_refresh_hotbar)
	player.wallet.changed.connect(_on_gold_changed)
	Clock.speed_changed.connect(_on_speed_changed)
	_refresh_hotbar()
	_refresh_gold()
	_refresh_speed()


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)

	# Crosshair and minigame overlay (drawn underneath the panels).
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_root.add_child(_overlay)

	# Top left: date/time/weather, speed, and the next-step hint.
	var tl := VBoxContainer.new()
	tl.position = Vector2(16, 14)
	tl.add_theme_constant_override("separation", 8)
	_root.add_child(tl)
	var clock_box := _panel_with(VBoxContainer.new())
	tl.add_child(clock_box)
	var cv: VBoxContainer = clock_box.get_child(0)
	_clock_label.add_theme_font_size_override("font_size", 21)
	cv.add_child(_clock_label)
	_speed_button.focus_mode = Control.FOCUS_NONE
	_speed_button.tooltip_text = "Speed up the world: clock, crops, hunger (T)"
	_speed_button.pressed.connect(Clock.cycle_speed)
	cv.add_child(_speed_button)
	_objective_box = _panel_with(_objective_label)
	_objective_label.custom_minimum_size = Vector2(330, 0)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.add_theme_color_override("font_color", ACCENT)
	tl.add_child(_objective_box)

	# Top right: gold.
	_gold_box = _panel_with(_gold_label)
	_gold_label.add_theme_font_size_override("font_size", 24)
	_gold_label.add_theme_color_override("font_color", ACCENT)
	_root.add_child(_gold_box)

	# Bottom left: needs.
	var needs := VBoxContainer.new()
	needs.add_child(_bar_row("Hunger", _hunger_bar, Color(0.82, 0.52, 0.25)))
	needs.add_child(_bar_row("Energy", _energy_bar, Color(0.42, 0.62, 0.88)))
	_needs_box = _panel_with(needs)
	_root.add_child(_needs_box)

	# Bottom centre: hotbar.
	_hotbar.add_theme_constant_override("separation", 6)
	_root.add_child(_hotbar)

	# Under the crosshair: what you're looking at / how to play the current minigame.
	for pair: Array in [[_prompt_box, _prompt], [_hint_box, _hint]]:
		var box: PanelContainer = pair[0]
		var l: Label = pair[1]
		box.add_theme_stylebox_override("panel", _style(Color(0.08, 0.06, 0.04, 0.72), 8, 6))
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
		_root.add_child(box)
	_hint.add_theme_color_override("font_color", DIM)
	_hint.add_theme_font_size_override("font_size", 17)

	# Top centre: messages.
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 4)
	_root.add_child(_toasts)

	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func _style(bg: Color, radius: int = 6, margin: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin + 2
	s.content_margin_right = margin + 2
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	return s


func _panel_with(c: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(c)
	return p


func _bar_row(label: String, bar: ProgressBar, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(76, 0)
	row.add_child(l)
	bar.custom_minimum_size = Vector2(200, 16)
	bar.show_percentage = false
	bar.max_value = 100
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.05, 0.03)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	return row


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT
	t.set_color("font_color", "Label", INK)
	var panel := _style(PARCHMENT, 6, 10)
	panel.border_color = Color(0.45, 0.34, 0.2)
	panel.set_border_width_all(1)
	t.set_stylebox("panel", "PanelContainer", panel)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var b := _style({"normal": Color(0.32, 0.23, 0.13), "hover": Color(0.45, 0.33, 0.18),
			"pressed": Color(0.55, 0.4, 0.2), "disabled": Color(0.2, 0.17, 0.13)}[state], 4, 6)
		t.set_stylebox(state, "Button", b)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.5, 0.42))
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	return t


# --- Per-frame ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	var weather := "Rain" if Clock.raining else ("Night" if Clock.is_night() else "Fair")
	_clock_label.text = "%s\n%s   ·   %s" % [Clock.date_string(), Clock.time_string(), weather]
	_hunger_bar.value = player.needs.hunger
	_energy_bar.value = player.needs.energy
	_objective_timer -= delta
	if _objective_timer <= 0.0:
		_objective_timer = 0.5
		var next: String = objective.call() if objective.is_valid() else ""
		_objective_label.text = "Next: " + next
		_objective_box.visible = next != ""
	var game := player.minigame
	var prompt := "" if game != null or _panel != null else player.prompt()
	_prompt.text = prompt
	_hint.text = (game.hint + "\n[Right-click] stop") if game != null else ""
	var vs := _root.size
	_place_centered(_prompt_box, prompt != "", vs, vs.y / 2.0 + 30.0, 640.0)
	_place_centered(_hint_box, game != null, vs, vs.y / 2.0 + 118.0, 640.0)
	_toasts.size = Vector2(700, 0)
	_toasts.position = Vector2((vs.x - 700) / 2.0, 14)
	# Corners are placed by hand each frame (sizes change with their contents).
	_gold_box.reset_size()
	_gold_box.position = Vector2(vs.x - _gold_box.size.x - 16, 14)
	_needs_box.reset_size()
	_needs_box.position = Vector2(16, vs.y - _needs_box.size.y - 16)
	_hotbar.visible = _panel == null
	_hotbar.reset_size()
	_hotbar.position = Vector2(maxf((vs.x - _hotbar.size.x) / 2.0, _needs_box.size.x + 32.0), vs.y - _hotbar.size.y - 16)
	_overlay.queue_redraw()


func _place_centered(box: Control, show: bool, vs: Vector2, y: float, max_w: float) -> void:
	box.visible = show
	if not show:
		return
	var l: Label = box.get_child(0)
	# Measure the unwrapped text, then wrap only if it's wider than max_w.
	var font := l.get_theme_font("font")
	var fsize := l.get_theme_font_size("font_size")
	var natural := font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize).x
	var w := minf(max_w, maxf(natural, 120.0) + 30.0)
	l.custom_minimum_size.x = w - 30.0
	box.reset_size()
	box.size.x = w
	box.position = Vector2((vs.x - w) / 2.0, y)


func _draw_overlay() -> void:
	var center := _overlay.size / 2.0
	if player and player.minigame != null:
		player.minigame.draw(_overlay, center)
	elif _panel == null:
		_overlay.draw_circle(center, 3.0, Color(1, 1, 1, 0.85))
		_overlay.draw_arc(center, 5.0, 0, TAU, 16, Color(0, 0, 0, 0.5), 1.0)


func _on_speed_changed(_speed: int) -> void:
	_refresh_speed()


func _on_gold_changed(_gold: int) -> void:
	_refresh_gold()


func _refresh_speed() -> void:
	_speed_button.text = "Time speed: %d×   [T]" % Clock.speed()


func _refresh_gold() -> void:
	_gold_label.text = "%d gold" % player.wallet.gold


func _refresh_hotbar() -> void:
	for c in _hotbar.get_children():
		c.queue_free()
	for i in player.hotbar.size():
		var id := player.hotbar[i]
		var selected := i == player.held_index
		var slot := PanelContainer.new()
		var style := _style(Color(0.14, 0.1, 0.07, 0.9), 6, 6)
		style.border_color = ACCENT if selected else Color(0.35, 0.27, 0.17)
		style.set_border_width_all(3 if selected else 1)
		slot.add_theme_stylebox_override("panel", style)
		slot.custom_minimum_size = Vector2(104, 62)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		slot.add_child(v)
		var key := Label.new()
		key.text = str(i + 1)
		key.add_theme_font_size_override("font_size", 14)
		key.add_theme_color_override("font_color", ACCENT if selected else DIM)
		v.add_child(key)
		var name := Label.new()
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.add_theme_font_size_override("font_size", 16)
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var it := Items.item(id)
		if id == Player.HANDS:
			name.text = "Hands"
		elif it.kind == ItemData.Kind.SEED:
			var kinds := player.seed_kinds()
			name.text = "%s seed ×%d" % [Items.crop(it.crop).display_name, player.inventory.count(id)]
			if kinds.size() > 1:
				name.text += "\n(%d of %d)" % [kinds.find(id) + 1, kinds.size()]
			if kinds.size() > 1:
				slot.tooltip_text = "Press %d again to change seed" % (i + 1)
		elif it.kind == ItemData.Kind.TOOL:
			name.text = it.display_name
		else:
			name.text = "%s ×%d" % [it.display_name, player.inventory.count(id)]
		v.add_child(name)
		_hotbar.add_child(slot)


func toast(text: String) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _style(Color(0.08, 0.06, 0.04, 0.78), 6, 6))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	_toasts.add_child(box)
	while _toasts.get_child_count() > 4:
		_toasts.get_child(0).free()
	var t := box.create_tween()
	t.tween_interval(4.5)
	t.tween_property(box, "modulate:a", 0.0, 0.8)
	t.tween_callback(box.queue_free)


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
		_toggle("inventory", open_inventory)
	elif event.is_action_pressed("guide"):
		_toggle("guide", open_guide)


func _toggle(kind: String, opener: Callable) -> void:
	if _panel_kind == kind:
		close_panel()
	elif _panel == null and player.minigame == null and player.can_act():
		opener.call()


func is_panel_open() -> bool:
	return _panel != null


func _open_panel(kind: String, title: String, width: float = 620.0) -> VBoxContainer:
	close_panel()
	_panel_kind = kind
	_panel = PanelContainer.new()
	_root.add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_panel.add_child(outer)
	var h := Label.new()
	h.text = title
	h.add_theme_font_size_override("font_size", 26)
	h.add_theme_color_override("font_color", ACCENT)
	outer.add_child(h)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(width, 0)
	outer.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	player.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("ui_open", -6.0, 0.0)
	_fit_panel.call_deferred(scroll, v)
	return v


## Sizes the panel to its contents (scrolling past 540 px) and centres it.
func _fit_panel(scroll: ScrollContainer, content: Control) -> void:
	await get_tree().process_frame   # let wrapped labels settle their heights first
	if _panel == null or not is_instance_valid(scroll):
		return
	scroll.custom_minimum_size.y = minf(content.get_combined_minimum_size().y, 540.0)
	_panel.reset_size()
	_panel.position = (_root.size - _panel.size) / 2.0


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


func _footer_button(text: String) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(close_panel)
	_panel.get_child(0).add_child(b)


func _label(text: String, size: int = FONT, color: Color = INK, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:   # never wrap a label inside a row: it collapses to one letter per line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func open_pause_menu() -> void:
	var v := _open_panel("pause", "Paused", 560.0)
	get_tree().paused = true
	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 8)
	speeds.add_child(_label("Time speed:", FONT, INK, false))
	for i in Clock.SPEEDS.size():
		var b := Button.new()
		b.text = "  %d×  " % Clock.SPEEDS[i]
		b.toggle_mode = true
		b.button_pressed = Clock.speed_index == i
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void:
			Clock.speed_index = i
			Clock.speed_changed.emit(Clock.speed())
			open_pause_menu())
		speeds.add_child(b)
	v.add_child(speeds)
	v.add_child(_label(CONTROLS_TEXT, 17, DIM))
	for pair: Array in [["Field guide  [G]", func() -> void: open_guide()],
			["Save", func() -> void: save_requested.emit()],
			["New game (erase save)", func() -> void: new_game_requested.emit()],
			["Quit", func() -> void: save_requested.emit(); get_tree().quit()]]:
		var b := Button.new()
		b.text = pair[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(pair[1])
		v.add_child(b)
	_footer_button("Resume  [Esc]")


const CONTROLS_TEXT := """WASD move · Shift run · Space jump · Mouse look
Left click: use what's in your hand · Right click: stop
E interact · F eat · Tab pack · G field guide · T time speed
1-9 or wheel: choose a tool (press the seed slot again to change seed)
Sleep in your bed to end the day; the game saves when you sleep."""


func open_inventory() -> void:
	var v := _open_panel("inventory", "Your pack")
	var stacks := player.inventory.stacks()
	if stacks.is_empty():
		v.add_child(_label("Empty."))
	for s in stacks:
		var it := Items.item(s.id)
		var row := HBoxContainer.new()
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(_label("%s  ×%d" % [Items.name_of(s.id, s.quality), s.count]))
		if it and it.description != "":
			text.add_child(_label(it.description, 15, DIM))
		row.add_child(text)
		if it and it.food_value > 0.0:
			var b := Button.new()
			b.text = "Eat (+%d)" % roundi(it.food_value)
			b.focus_mode = Control.FOCUS_NONE
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.pressed.connect(func() -> void:
				player.eat(s.id, s.quality)
				open_inventory())
			row.add_child(b)
		v.add_child(row)
	_footer_button("Close  [Tab]")


func open_guide() -> void:
	var v := _open_panel("guide", "Field guide", 680.0)
	var sections: Array = guide_sections.call() if guide_sections.is_valid() else []
	for sec: Array in sections:
		v.add_child(_label(sec[0], 21, ACCENT))
		v.add_child(_label(sec[1], 17))
	_footer_button("Close  [G]")


## A buy/sell list. `rows` returns an Array of {label, tooltip?, buttons: [{text, enabled, action}]};
## it's called again after every action so prices and counts stay current.
func open_trade(title: String, rows: Callable) -> void:
	_trade_rows = rows
	var v := _open_panel("trade", title)
	v.add_child(_label("You have %d gold." % player.wallet.gold, FONT, ACCENT))
	var list: Array = rows.call()
	if list.is_empty():
		v.add_child(_label("Nothing to trade."))
	for r: Dictionary in list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(_label(r.label))
		if r.get("tooltip", "") != "":
			text.add_child(_label(r.tooltip, 15, DIM))
		row.add_child(text)
		for btn: Dictionary in r.buttons:
			var b := Button.new()
			b.text = btn.text
			b.disabled = not btn.enabled
			b.focus_mode = Control.FOCUS_NONE
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var action: Callable = btn.action
			b.pressed.connect(func() -> void:
				action.call()
				open_trade(title, _trade_rows))
			row.add_child(b)
		v.add_child(row)
	_footer_button("Close  [Esc]")

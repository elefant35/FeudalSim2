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
var _held_label := Label.new()
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
	player.carry_changed.connect(_refresh_hotbar)
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
	_held_label.add_theme_constant_override("outline_size", 6)
	_held_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_held_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_held_label)

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
	_place_centered(_hint_box, game != null, vs, vs.y / 2.0 + 150.0, 640.0)
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
	_held_label.visible = _hotbar.visible
	_held_label.size = Vector2(_hotbar.size.x, 0)
	_held_label.position = _hotbar.position - Vector2(0, 30)
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
		var tile := ItemTile.new()
		tile.tile_size = 64.0
		tile.slot = i
		tile.key_text = str(i + 1)
		tile.selected = i == player.held_index
		var it := Items.item(id)
		var n := player.inventory.count(id) if it else 0
		tile.dimmed = it != null and n == 0
		tile.set_item(id, -1, n if it and it.kind != ItemData.Kind.TOOL else 0)
		_hotbar.add_child(tile)
	var held := player.held()
	if held == Player.CARRYING:
		_held_label.text = "Carrying %s  ·  E to set down" % player.carry_text()
	elif held == Player.PULLING:
		_held_label.text = "Pulling the handcart  ·  E to let go"
	elif held == Player.HANDS:
		_held_label.text = "Hands"
	else:
		var hi := Items.item(held)
		_held_label.text = Items.name_of(held) + ("" if hi.kind == ItemData.Kind.TOOL else "  ×%d" % player.inventory.count(held))


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


## Opens a panel, or rebuilds the open one in place (same kind) without touching the mouse,
## so clicking inside a panel never makes the cursor jump.
func _open_panel(kind: String, title: String, width: float = 620.0) -> VBoxContainer:
	var reuse := _panel != null and _panel_kind == kind
	if reuse:
		for c in _panel.get_children():
			_panel.remove_child(c)
			c.queue_free()
	else:
		close_panel()
		_panel = PanelContainer.new()
		_root.add_child(_panel)
		player.ui_open = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Sfx.play("ui_open", -6.0, 0.0)
	_panel_kind = kind
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
	_fit_panel.call_deferred(scroll, v, reuse)
	return v


## Sizes the panel to its contents (scrolling past 540 px) and centres it.
func _fit_panel(scroll: ScrollContainer, content: Control, keep_top: bool = false) -> void:
	await get_tree().process_frame   # let wrapped labels settle their heights first
	if _panel == null or not is_instance_valid(scroll):
		return
	var top := _panel.position.y
	scroll.custom_minimum_size.y = minf(content.get_combined_minimum_size().y, 540.0)
	_panel.reset_size()
	_panel.position = (_root.size - _panel.size) / 2.0
	if keep_top:   # a refresh: don't let the panel hop up and down under the cursor
		_panel.position.y = top


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
1-9 or wheel: choose a hotbar slot · Tab: arrange your hotbar
Sleep in your bed to end the day; the game saves when you sleep."""


var _pack_selected: StringName = &""


## The pack: every item as an icon tile, plus your hotbar to arrange. Drag a tool or seed onto
## a hotbar slot (or click it, then click a slot). Right-click a slot to empty it; right-click
## or double-click food to eat it.
func open_inventory() -> void:
	var v := _open_panel("inventory", "Your pack", 640.0)
	v.add_child(_label("Drag tools and seed onto your hotbar slots, or drag a slot back into the pack to empty it. Click anything to see what it is. Shift-click moves it to or from the hotbar.", 15, DIM))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	if player.is_carrying():
		var arms := HBoxContainer.new()
		arms.add_theme_constant_override("separation", 8)
		var t := ItemTile.new()
		t.set_item(player.carry_id, -1, player.carry_count())
		arms.add_child(t)
		arms.add_child(_label("In your arms: %s" % player.carry_text(), FONT, INK, false))
		var food := Items.item(player.carry_id).food_value > 0.0
		if food:
			for pair: Array in [["Eat one", func() -> void: player.eat_something(); _refresh_pack()],
					["Pocket one (%d/%d)" % [player.pocket_count(), Player.POCKET_MAX], func() -> void:
						if not player.pocket_one():
							player.say("Your pack can't hold more produce.")
						_refresh_pack()]]:
				var b := Button.new()
				b.text = pair[0]
				b.focus_mode = Control.FOCUS_NONE
				b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				b.pressed.connect(pair[1])
				arms.add_child(b)
		v.add_child(arms)
	var stacks := player.inventory.stacks()
	for st in stacks:
		var tile := ItemTile.new()
		tile.interactive = true
		tile.draggable = Items.item(st.id) != null and Items.item(st.id).hotbar
		tile.accepts_drops = true    # dropping a hotbar item back on the pack empties its slot
		tile.selected = st.id == _pack_selected
		tile.set_item(st.id, st.quality, st.count)
		tile.pressed.connect(_on_pack_tile)
		tile.dropped.connect(_on_drop_on_pack)
		grid.add_child(tile)
	if stacks.is_empty():
		v.add_child(_label("Empty."))
	v.add_child(_label("Hotbar  (keys 1–9; slot 1 is always your hands). Drag to arrange.", 17, ACCENT))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	v.add_child(bar)
	for i in player.hotbar.size():
		var id := player.hotbar[i]
		var tile := ItemTile.new()
		tile.interactive = true
		tile.slot = i
		tile.key_text = str(i + 1)
		tile.tile_size = 64.0
		tile.draggable = i > 0
		tile.accepts_drops = i > 0
		var it := Items.item(id)
		tile.dimmed = it != null and not player.inventory.has(id)
		tile.set_item(id, -1, player.inventory.count(id) if it and it.kind != ItemData.Kind.TOOL else 0)
		tile.pressed.connect(_on_hotbar_tile)
		tile.dropped.connect(_on_drop_on_slot)
		bar.add_child(tile)
	# Details of the selected item, with what you can do with it.
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(0, 74)   # fixed height: the panel doesn't jump as you click
	v.add_child(info)
	var it := Items.item(_pack_selected) if _pack_selected != &"" else null
	if it and player.inventory.has(_pack_selected):
		var q_text := Items.name_of(_pack_selected, player.inventory.qualities_of(_pack_selected).back()) if it.has_quality else it.display_name
		info.add_child(_label("%s  ×%d" % [q_text, player.inventory.count(_pack_selected)], 18, ACCENT))
		if it.description != "":
			info.add_child(_label(it.description, 15, DIM))
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		info.add_child(actions)
		var id := _pack_selected
		if it.food_value > 0.0:
			_action_button(actions, "Eat (+%d hunger)" % roundi(it.food_value), func() -> void:
				player.eat(id, player.inventory.qualities_of(id).front())
				_refresh_pack())
		if it.hotbar:
			if id in player.hotbar:
				_action_button(actions, "Take off the hotbar", func() -> void:
					player.clear_slot(player.hotbar.find(id))
					_refresh_pack())
			elif player.hotbar.find(&"") > 0:
				_action_button(actions, "Put on the hotbar", func() -> void:
					player.assign_slot(player.hotbar.find(&""), id)
					_refresh_pack())
	else:
		_pack_selected = &""
		info.add_child(_label("Click an item to see what it is.", 15, DIM))
	_footer_button("Close  [Tab]")


func _refresh_pack() -> void:
	if _panel_kind == "inventory":
		open_inventory.call_deferred()


func _action_button(parent: Control, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	parent.add_child(b)


func _on_pack_tile(tile: ItemTile, button: int, double: bool) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return
	var it := Items.item(tile.id)
	if Input.is_key_pressed(KEY_SHIFT) and it and it.hotbar:
		# Shift-click: quick-move onto (or off) the hotbar.
		if tile.id in player.hotbar:
			player.clear_slot(player.hotbar.find(tile.id))
		elif player.hotbar.find(&"") > 0:
			player.assign_slot(player.hotbar.find(&""), tile.id)
	elif double and it and it.food_value > 0.0:
		player.eat(tile.id, tile.quality)
	else:
		_pack_selected = tile.id
	Sfx.play("ui_click", -8.0, 0.0)
	_refresh_pack()


func _on_hotbar_tile(tile: ItemTile, button: int, _double: bool) -> void:
	if tile.slot <= 0 or button != MOUSE_BUTTON_LEFT or tile.id == &"":
		return
	if Input.is_key_pressed(KEY_SHIFT):
		player.clear_slot(tile.slot)
	else:
		_pack_selected = tile.id
	Sfx.play("ui_click", -8.0, 0.0)
	_refresh_pack()


func _on_drop_on_slot(tile: ItemTile, data: Dictionary) -> void:
	player.assign_slot(tile.slot, StringName(data.id))
	Sfx.play("ui_click", -8.0, 0.0)
	_refresh_pack()


func _on_drop_on_pack(_tile: ItemTile, data: Dictionary) -> void:
	if int(data.get("from_slot", -1)) > 0:
		player.clear_slot(int(data.from_slot))
		_refresh_pack()


func open_guide() -> void:
	var v := _open_panel("guide", "Field guide", 680.0)
	var sections: Array = guide_sections.call() if guide_sections.is_valid() else []
	for sec: Array in sections:
		v.add_child(_label(sec[0], 21, ACCENT))
		v.add_child(_label(sec[1], 17))
	_footer_button("Close  [G]")


## A storage window (barrel, handcart): the same list, without the gold line.
func open_container(title: String, rows: Callable) -> void:
	open_trade(title, rows, false)


## A buy/sell list. `rows` returns an Array of {label, tooltip?, buttons: [{text, enabled, action}]};
## it's called again after every action so prices and counts stay current.
func open_trade(title: String, rows: Callable, show_gold: bool = true) -> void:
	_trade_rows = rows
	var v := _open_panel("trade", title)
	if show_gold:
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
				if _panel_kind == "trade":
					open_trade(title, _trade_rows, show_gold))
			row.add_child(b)
		v.add_child(row)
	_footer_button("Close  [Esc]")

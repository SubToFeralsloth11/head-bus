class_name GameUI
extends CanvasLayer
## Menu, garage, HUD, pause and game-over screens, all built in code.

signal play_pressed
signal buy_pressed(id: String)
signal mode_selected(mode: int)
signal sens_changed(value: float)
signal flip_changed(value: bool)
signal pause_pressed
signal resume_pressed
signal garage_pressed
signal retry_pressed
signal recalibrate_pressed

const ACCENT := Color("ffc93c")
const GOOD := Color("4ade80")
const BAD := Color("ff6b6b")
const MUTED := Color("aeb8c4")
## Steering bar spans these control values (see SteerInput).
const BAR_MIN := -2.2
const BAR_MAX := 1.6

var root: Control
var menu: Control
var menu_box: BoxContainer
var hud: Control
var pause_panel: Control
var over_panel: Control

var mode_btns: Array[Button] = []
var sens_slider: HSlider
var flip_check: CheckButton
var sensor_lbl: Label
var bank_lbl: Label
var best_lbl: Label
var up_rows := {}

var money_lbl: Label
var dist_lbl: Label
var hearts: HBoxContainer
var speed_lbl: Label
var status_lbl: Label
var hint_lbl: Label
var popup_lbl: Label
var count_lbl: Label
var recal_btn: Button
var bar: Control
var over_title: Label
var over_lbl: Label

var _bar_ctrl := NAN
var _bar_bus := 0.0
var _bar_station := false
var _popup_tween: Tween


func _ready() -> void:
	root = Control.new()
	root.theme = _make_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_menu()
	_build_hud()
	pause_panel = _modal("PAUSED", [["Resume", resume_pressed], ["Garage", garage_pressed]])
	over_panel = _modal("CRASHED!", [["Drive again", retry_pressed], ["Garage", garage_pressed]])
	over_title = over_panel.find_child("Title", true, false)
	over_lbl = _label("", 24)
	over_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var vb: VBoxContainer = over_panel.find_child("Body", true, false)
	vb.add_child(over_lbl)
	vb.move_child(over_lbl, 1)
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()


# --- Public API -------------------------------------------------------------

func show_screen(name: String) -> void:
	menu.visible = name == "menu"
	hud.visible = name in ["hud", "pause", "over"]
	pause_panel.visible = name == "pause"
	over_panel.visible = name == "over"


func refresh_menu(save: Dictionary, upgrades: Dictionary, costs: Array) -> void:
	bank_lbl.text = "Bank  $%d" % int(save.money)
	best_lbl.text = "Best  %d m" % int(save.best)
	for i in mode_btns.size():
		mode_btns[i].set_pressed_no_signal(i == int(save.mode))
	sens_slider.set_value_no_signal(float(save.sens))
	flip_check.set_pressed_no_signal(bool(save.flip))
	for id in upgrades:
		var lvl: int = save.up[id]
		var mx: int = upgrades[id].max
		var row: Dictionary = up_rows[id]
		(row.lvl as Label).text = "Level %d / %d" % [lvl, mx]
		var btn: Button = row.btn
		if lvl >= mx:
			btn.text = "MAX"
			btn.disabled = true
		else:
			btn.text = "$%d" % costs[lvl]
			btn.disabled = int(save.money) < costs[lvl]


func set_sensor_message(text: String, ok: bool) -> void:
	sensor_lbl.text = text
	sensor_lbl.modulate = GOOD if ok else MUTED


func set_hud(money: float, dist: float, level: int, kmh: float, hp: int, hp_max: int) -> void:
	money_lbl.text = "$%d" % int(money)
	dist_lbl.text = "%d m   ·   Level %d" % [int(dist), level]
	speed_lbl.text = "%d km/h" % int(kmh)
	if hearts.get_child_count() != hp_max:
		for c in hearts.get_children():
			c.free()
		for i in hp_max:
			var p := Panel.new()
			p.custom_minimum_size = Vector2(26, 26)
			hearts.add_child(p)
	for i in hp_max:
		var p: Panel = hearts.get_child(i)
		p.add_theme_stylebox_override("panel", _box(BAD if i < hp else Color(0.2, 0.2, 0.25, 0.7), 13))


func set_bar(ctrl: float, bus_c: float, station_open: bool) -> void:
	_bar_ctrl = ctrl
	_bar_bus = bus_c
	_bar_station = station_open
	bar.queue_redraw()


func set_status(text: String) -> void:
	status_lbl.text = text
	status_lbl.visible = text != ""


func set_hint(text: String) -> void:
	hint_lbl.text = text
	hint_lbl.visible = text != ""


func set_countdown(text: String) -> void:
	count_lbl.text = text
	count_lbl.visible = text != ""


func show_recalibrate(on: bool) -> void:
	recal_btn.visible = on


func popup(text: String, col := Color.WHITE) -> void:
	popup_lbl.text = text
	popup_lbl.modulate = col
	popup_lbl.scale = Vector2(1.35, 1.35)
	if _popup_tween:
		_popup_tween.kill()
	_popup_tween = create_tween()
	_popup_tween.tween_property(popup_lbl, "scale", Vector2.ONE, 0.15)
	_popup_tween.tween_interval(0.6)
	_popup_tween.tween_property(popup_lbl, "modulate:a", 0.0, 0.4)


func show_over(title: String, text: String) -> void:
	over_title.text = title
	over_lbl.text = text
	show_screen("over")


# --- Construction -----------------------------------------------------------

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 22
	th.set_stylebox("normal", "Button", _box(Color("2b6cb0"), 12))
	th.set_stylebox("hover", "Button", _box(Color("3b82d0"), 12))
	th.set_stylebox("pressed", "Button", _box(Color("1e4f86"), 12))
	th.set_stylebox("hover_pressed", "Button", _box(Color("1e4f86"), 12))
	th.set_stylebox("disabled", "Button", _box(Color(0.3, 0.33, 0.38, 0.8), 12))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		th.set_stylebox(st, "CheckButton", StyleBoxEmpty.new())
	th.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.45))
	th.set_color("font_color", "Label", Color.WHITE)
	th.set_constant("outline_size", "Label", 6)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.55))
	return th


static func _box(col: Color, radius: int, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 4
	s.content_margin_right = pad + 4
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


func _label(text: String, size := 22, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.modulate = col
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size.y = 48
	return b


func _card(min_w: float) -> VBoxContainer:
	var pc := PanelContainer.new()
	var sb := _box(Color(0.06, 0.08, 0.12, 0.86), 20, 22)
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size.x = min_w
	var vb := VBoxContainer.new()
	vb.name = "Body"
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)
	return vb


func _build_menu() -> void:
	menu = Control.new()
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.25)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)
	menu_box = BoxContainer.new()
	menu_box.add_theme_constant_override("separation", 20)
	centre.add_child(menu_box)

	# Title + controls card.
	var vb := _card(470)
	menu_box.add_child(vb.get_parent())
	var title := _label("HEAD BUS", 66, ACCENT)
	title.add_theme_constant_override("outline_size", 12)
	vb.add_child(title)
	var sub := _label("Steer the double-decker with your head. Weave through traffic, grab coins, dodge roadworks.", 18, MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(sub)
	vb.add_child(_label("STEERING", 16, MUTED))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	vb.add_child(modes)
	var group := ButtonGroup.new()
	for i in SteerInput.MODE_NAMES.size():
		var b := _button(SteerInput.MODE_NAMES[i], 18)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): mode_selected.emit(i))
		modes.add_child(b)
		mode_btns.append(b)
	sensor_lbl = _label("", 17, MUTED)
	sensor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(sensor_lbl)
	var how := _label("Move your head left or right and the bus follows - move slowly to drift, quickly to swerve. Lean further left to pull into petrol stations.", 16, MUTED)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(how)
	var srow := HBoxContainer.new()
	vb.add_child(srow)
	srow.add_child(_label("Sensitivity", 18))
	sens_slider = HSlider.new()
	sens_slider.min_value = 0.5
	sens_slider.max_value = 2.0
	sens_slider.step = 0.05
	sens_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sens_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sens_slider.value_changed.connect(func(v): sens_changed.emit(v))
	srow.add_child(sens_slider)
	flip_check = CheckButton.new()
	flip_check.text = "Flip left / right"
	flip_check.toggled.connect(func(v): flip_changed.emit(v))
	vb.add_child(flip_check)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 30)
	vb.add_child(stats)
	bank_lbl = _label("", 24, ACCENT)
	best_lbl = _label("", 24)
	stats.add_child(bank_lbl)
	stats.add_child(best_lbl)
	var play := _button("DRIVE!", 34)
	play.custom_minimum_size.y = 72
	play.add_theme_stylebox_override("normal", _box(Color("1f9d55"), 14))
	play.add_theme_stylebox_override("hover", _box(Color("27b765"), 14))
	play.add_theme_stylebox_override("pressed", _box(Color("17773f"), 14))
	play.pressed.connect(func(): play_pressed.emit())
	vb.add_child(play)

	# Garage card.
	var gb := _card(430)
	menu_box.add_child(gb.get_parent())
	gb.add_child(_label("GARAGE", 36, ACCENT))
	gb.add_child(_label("Spend your fares on upgrades.", 17, MUTED))


## Adds one upgrade row to the garage card; called by the game with its table.
func add_upgrade_row(id: String, title: String, desc: String) -> void:
	var gb: VBoxContainer = menu_box.get_child(1).get_child(0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	gb.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	info.add_child(_label(title, 22))
	var d := _label(desc, 16, MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(d)
	var lvl := _label("", 16, GOOD)
	info.add_child(lvl)
	var btn := _button("", 22)
	btn.custom_minimum_size.x = 120
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func(): buy_pressed.emit(id))
	row.add_child(btn)
	up_rows[id] = {"lvl": lvl, "btn": btn}


func _build_hud() -> void:
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var tl := VBoxContainer.new()
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(tl)
	tl.position = Vector2(20, 14)
	money_lbl = _label("$0", 40, ACCENT)
	dist_lbl = _label("", 22)
	hearts = HBoxContainer.new()
	hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_child(money_lbl)
	tl.add_child(dist_lbl)
	tl.add_child(hearts)

	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 10)
	hud.add_child(tr)
	tr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	recal_btn = _button("Re-centre", 20)
	recal_btn.pressed.connect(func(): recalibrate_pressed.emit())
	tr.add_child(recal_btn)
	var pause := _button("Pause", 20)
	pause.pressed.connect(func(): pause_pressed.emit())
	tr.add_child(pause)

	status_lbl = _centre_label(26, BAD, 0.2)
	hint_lbl = _centre_label(26, GOOD, 0.27)
	popup_lbl = _centre_label(44, Color.WHITE, 0.36)
	popup_lbl.modulate.a = 0.0
	count_lbl = _centre_label(80, ACCENT, 0.42)
	count_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	bar = Control.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(560, 46)
	hud.add_child(bar)
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 0.0
	bar.anchor_bottom = 0.0
	bar.offset_left = -280
	bar.offset_right = 280
	bar.offset_top = 16
	bar.offset_bottom = 62
	bar.draw.connect(_draw_bar)

	speed_lbl = _label("", 30)
	hud.add_child(speed_lbl)
	speed_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	speed_lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	speed_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _centre_label(size: int, col: Color, y: float) -> Label:
	var l := _label("", size, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = y
	l.anchor_bottom = y
	l.offset_left = 40
	l.offset_right = -40
	l.pivot_offset = Vector2(600, 30)
	l.visible = false
	hud.add_child(l)
	return l


func _modal(title: String, buttons: Array) -> Control:
	var wrap := CenterContainer.new()
	root.add_child(wrap)
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vb := _card(420)
	wrap.add_child(vb.get_parent())
	var t := _label(title, 52, ACCENT)
	t.name = "Title"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	for b in buttons:
		var btn := _button(b[0], 26)
		var sig: Signal = b[1]
		btn.pressed.connect(func(): sig.emit())
		vb.add_child(btn)
	wrap.visible = false
	return wrap


func _on_resize() -> void:
	var s := get_viewport().get_visible_rect().size
	menu_box.vertical = s.x < 1000.0
	popup_lbl.pivot_offset = Vector2(s.x / 2.0 - 40.0, 30)
	# Narrow screens: drop the steering bar below the money/buttons row.
	bar.offset_top = 16.0 if s.x >= 1000.0 else 150.0
	bar.offset_bottom = bar.offset_top + 46.0


func _draw_bar() -> void:
	var w := bar.size.x
	var h := bar.size.y
	var f := ThemeDB.fallback_font
	var span := BAR_MAX - BAR_MIN
	var u := func(c: float) -> float: return (clampf(c, BAR_MIN, BAR_MAX) - BAR_MIN) / span * w
	bar.draw_rect(Rect2(0, 8, w, h - 16), Color(0, 0, 0, 0.45))
	var station_col := Color(0.12, 0.62, 0.33, 0.85 if _bar_station else 0.18)
	bar.draw_rect(Rect2(0, 8, u.call(-0.5), h - 16), station_col)
	bar.draw_rect(Rect2(u.call(-0.5), 8, u.call(0.5) - u.call(-0.5), h - 16), Color(0.35, 0.38, 0.45, 0.85))
	bar.draw_rect(Rect2(u.call(0.5), 8, w - u.call(0.5), h - 16), Color(0.75, 0.25, 0.25, 0.7))
	bar.draw_string(f, Vector2(8, h - 15), "PETROL", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.9 if _bar_station else 0.35))
	bar.draw_string(f, Vector2(u.call(-0.5) + 6, h - 15), "YOUR LANE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	bar.draw_string(f, Vector2(u.call(0.5) + 6, h - 15), "ONCOMING", HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var bx: float = u.call(_bar_bus)
	bar.draw_rect(Rect2(bx - 6, 4, 12, h - 8), ACCENT)
	if not is_nan(_bar_ctrl):
		var cx: float = u.call(_bar_ctrl)
		bar.draw_circle(Vector2(cx, h / 2.0), 9.0, Color.WHITE)
		bar.draw_circle(Vector2(cx, h / 2.0), 5.0, Color("2b6cb0"))

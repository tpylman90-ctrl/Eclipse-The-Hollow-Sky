extends CanvasLayer
## Entire interface is native Godot Control nodes (no third-party fonts or sprites).

signal start_requested
signal restart_requested

var root: Control
var menu: Control
var hud: Control
var results: Control
var touch_layer: Control
var gate_label: Label
var shield_label: Label
var clock_label: Label
var speed_label: Label
var energy_label: Label
var result_title: Label
var result_detail: Label
var message_label: Label

const WHITE := Color(0.95, 0.97, 0.98)
const AQUA := Color(0.30, 1.0, 0.91)
const GOLD := Color(1.0, 0.75, 0.43)
const DARK := Color(0.035, 0.065, 0.12, 0.93)


func _ready() -> void:
    root = Control.new()
    root.name = "Interface"
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    _build_menu()
    _build_hud()
    _build_results()
    show_title()


func _label(text: String, size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var item := Label.new()
    item.text = text
    item.horizontal_alignment = alignment
    item.add_theme_font_size_override("font_size", size)
    item.add_theme_color_override("font_color", color)
    item.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.80))
    item.add_theme_constant_override("shadow_offset_x", 1)
    item.add_theme_constant_override("shadow_offset_y", 2)
    return item


func _button(text: String, primary: bool = false) -> Button:
    var item := Button.new()
    item.text = text
    item.custom_minimum_size = Vector2(214.0, 58.0)
    item.focus_mode = Control.FOCUS_NONE
    item.add_theme_font_size_override("font_size", 21)
    item.add_theme_color_override("font_color", DARK if primary else WHITE)
    item.add_theme_color_override("font_hover_color", Color(0.02, 0.1, 0.14) if primary else AQUA)
    var normal := StyleBoxFlat.new()
    normal.bg_color = AQUA if primary else Color(0.065, 0.13, 0.20, 0.85)
    normal.border_color = AQUA
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(13)
    normal.content_margin_left = 15.0
    normal.content_margin_right = 15.0
    item.add_theme_stylebox_override("normal", normal)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.85, 0.97, 0.95) if primary else Color(0.07, 0.24, 0.31, 0.96)
    item.add_theme_stylebox_override("hover", hover)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = GOLD
    item.add_theme_stylebox_override("pressed", pressed)
    return item


func _fill(target: Control) -> void:
    target.set_anchors_preset(Control.PRESET_FULL_RECT)
    target.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _scrim(parent: Control, opacity: float) -> void:
    var bg := ColorRect.new()
    _fill(bg)
    bg.color = Color(0.005, 0.015, 0.035, opacity)
    parent.add_child(bg)


func _build_menu() -> void:
    menu = Control.new()
    _fill(menu)
    root.add_child(menu)
    _scrim(menu, 0.69)
    var vertical := VBoxContainer.new()
    vertical.anchor_left = 0.14
    vertical.anchor_right = 0.86
    vertical.anchor_top = 0.18
    vertical.anchor_bottom = 0.86
    vertical.alignment = BoxContainer.ALIGNMENT_CENTER
    vertical.add_theme_constant_override("separation", 15)
    menu.add_child(vertical)
    var eyebrow := _label("A  S I G N A L  F R O M  B E Y O N D", 15, AQUA, HORIZONTAL_ALIGNMENT_CENTER)
    vertical.add_child(eyebrow)
    var heading := _label("E C L I P S E", 66, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    vertical.add_child(heading)
    var sub := _label("T H E   H O L L O W   S K Y", 26, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
    vertical.add_child(sub)
    var space := Control.new()
    space.custom_minimum_size.y = 28
    vertical.add_child(space)
    var blurb := _label("SEVEN SIGNALS. ONE LAST PASSAGE.\nFly through the lost beacons before the light runs out.", 19, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    vertical.add_child(blurb)
    var start := _button("BEGIN THE FLIGHT", true)
    start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    vertical.add_child(start)
    start.pressed.connect(func(): start_requested.emit())
    var hint_text := "DRAG THE VIRTUAL CONTROLS TO FLY  •  BOOST TO ACCELERATE" if OS.has_feature("mobile") else "WASD / ARROWS  •  SPACE BOOST  •  SHIFT BRAKE  •  ENTER START"
    var hint := _label(hint_text, 14, Color(0.68, 0.79, 0.82), HORIZONTAL_ALIGNMENT_CENTER)
    vertical.add_child(hint)


func _build_hud() -> void:
    hud = Control.new()
    _fill(hud)
    root.add_child(hud)
    var top := ColorRect.new()
    top.anchor_left = 0.0
    top.anchor_right = 1.0
    top.offset_top = 0.0
    top.offset_bottom = 91.0
    top.color = Color(0.018, 0.034, 0.075, 0.77)
    hud.add_child(top)
    gate_label = _label("SIGNAL 01 / 07", 28, WHITE)
    gate_label.position = Vector2(26, 13)
    top.add_child(gate_label)
    shield_label = _label("HULL  ◈◈◈", 17, AQUA)
    shield_label.position = Vector2(28, 52)
    top.add_child(shield_label)
    clock_label = _label("TIME  01:30", 23, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
    clock_label.anchor_left = 1.0
    clock_label.anchor_right = 1.0
    clock_label.offset_left = -278.0
    clock_label.offset_right = -24.0
    clock_label.offset_top = 18.0
    top.add_child(clock_label)
    speed_label = _label("036 M/S", 19, WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
    speed_label.anchor_left = 1.0
    speed_label.anchor_right = 1.0
    speed_label.offset_left = -278.0
    speed_label.offset_right = -24.0
    speed_label.offset_top = 51.0
    top.add_child(speed_label)
    energy_label = _label("BOOST  ██████████", 18, AQUA)
    energy_label.anchor_left = 0.5
    energy_label.anchor_right = 0.5
    energy_label.offset_left = -130.0
    energy_label.offset_right = 160.0
    energy_label.offset_top = 48.0
    top.add_child(energy_label)
    message_label = _label("ALIGN WITH THE GOLDEN HALO", 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
    message_label.anchor_left = 0.16
    message_label.anchor_right = 0.84
    message_label.anchor_top = 0.19
    message_label.anchor_bottom = 0.19
    message_label.offset_top = 0
    message_label.offset_bottom = 42
    hud.add_child(message_label)
    _build_touch()


func _build_touch() -> void:
    touch_layer = Control.new()
    _fill(touch_layer)
    hud.add_child(touch_layer)
    touch_layer.visible = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
    # Four fully separated 88x88 touch targets in a classic D-pad.
    # Horizontal / vertical gaps are at least 8 screen pixels.
    _touch_button("▲", "steer_up", 0.0, 114.0, -219.0, 88.0, 88.0)
    _touch_button("◀", "steer_left", 0.0, 18.0, -123.0, 88.0, 88.0)
    _touch_button("▼", "steer_down", 0.0, 114.0, -123.0, 88.0, 88.0)
    _touch_button("▶", "steer_right", 0.0, 210.0, -123.0, 88.0, 88.0)
    _touch_button("BRAKE", "brake", 1.0, -296.0, -104.0, 112.0, 73.0)
    _touch_button("BOOST", "boost", 1.0, -162.0, -125.0, 135.0, 73.0)


func _touch_button(caption: String, action: String, horizontal_anchor: float, offset_x: float, offset_y: float, size_x: float, size_y: float) -> void:
    var btn := _button(caption, action == "boost")
    btn.add_theme_font_size_override("font_size", 18)
    btn.anchor_left = horizontal_anchor
    btn.anchor_right = horizontal_anchor
    btn.anchor_top = 1.0
    btn.anchor_bottom = 1.0
    btn.offset_left = offset_x
    btn.offset_right = offset_x + size_x
    btn.offset_top = offset_y
    btn.offset_bottom = offset_y + size_y
    btn.custom_minimum_size = Vector2.ZERO
    touch_layer.add_child(btn)
    btn.button_down.connect(func(): Input.action_press(action))
    btn.button_up.connect(func(): Input.action_release(action))
    btn.mouse_exited.connect(func(): Input.action_release(action))


func _build_results() -> void:
    results = Control.new()
    _fill(results)
    root.add_child(results)
    _scrim(results, 0.78)
    var vertical := VBoxContainer.new()
    vertical.anchor_left = 0.15
    vertical.anchor_right = 0.85
    vertical.anchor_top = 0.22
    vertical.anchor_bottom = 0.80
    vertical.alignment = BoxContainer.ALIGNMENT_CENTER
    vertical.add_theme_constant_override("separation", 20)
    results.add_child(vertical)
    result_title = _label("THE SKY REMEMBERS", 44, AQUA, HORIZONTAL_ALIGNMENT_CENTER)
    vertical.add_child(result_title)
    result_detail = _label("THE SIGNAL HAS BEEN RESTORED", 21, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    vertical.add_child(result_detail)
    var retry := _button("FLY AGAIN", true)
    retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    vertical.add_child(retry)
    retry.pressed.connect(func(): restart_requested.emit())


func show_title() -> void:
    menu.show()
    hud.hide()
    results.hide()


func show_play() -> void:
    menu.hide()
    results.hide()
    hud.show()


func show_result(victory: bool, score: int, signals: int) -> void:
    hud.hide()
    menu.hide()
    results.show()
    result_title.text = "THE SKY REMEMBERS" if victory else "SIGNAL LOST"
    result_title.add_theme_color_override("font_color", AQUA if victory else GOLD)
    result_detail.text = ("SEVEN BEACONS RESTORED  •  SCORE %d" % score) if victory else ("REACHED %d / 7  •  SCORE %d\nYOUR FLIGHT IS NOT OVER" % [signals, score])
    for action in ["steer_left", "steer_right", "steer_up", "steer_down", "boost", "brake"]:
        Input.action_release(action)


func update_status(signals: int, total: int, shield: int, time_left: float, speed: float, energy: float, hint: String) -> void:
    gate_label.text = "SIGNAL %02d / %02d" % [mini(signals + 1, total), total]
    shield_label.text = "HULL   " + "◈".repeat(maxi(0, shield)) + "◇".repeat(maxi(0, 3 - shield))
    var secs := maxi(0, int(ceilf(time_left)))
    clock_label.text = "TIME  %02d:%02d" % [secs / 60, secs % 60]
    speed_label.text = "%03d M/S" % int(speed)
    energy_label.text = "BOOST  " + "█".repeat(clampi(int(energy / 10.0), 0, 10)) + "░".repeat(clampi(10 - int(energy / 10.0), 0, 10))
    message_label.text = hint

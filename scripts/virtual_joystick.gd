extends Control
## Genuine analog, multi-touch-safe on-screen flight stick.
## Captures one finger without stealing FIRE / BOOST / BRAKE touches.

var touch_id := -1
var mouse_held := false
var stick := Vector2.ZERO
const RADIUS := 73.0
const DEAD_ZONE := 0.10
const STICK_NAMES := ["steer_left", "steer_right", "steer_up", "steer_down"]


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_process_input(true)
    queue_redraw()


func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed and touch_id == -1:
        touch_id = event.index
        _set_position(event.position)
        accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed and not mouse_held:
            mouse_held = true
            _set_position(event.position)
        elif not event.pressed and mouse_held:
            reset_stick()
        accept_event()


func _input(event: InputEvent) -> void:
    if event is InputEventScreenDrag and event.index == touch_id:
        _set_position(to_local(event.position))
    elif event is InputEventScreenTouch and not event.pressed and event.index == touch_id:
        reset_stick()
    elif event is InputEventMouseMotion and mouse_held:
        _set_position(to_local(event.position))
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and mouse_held:
        reset_stick()


func _set_position(local_pos: Vector2) -> void:
    var center := size * 0.5
    var relative := (local_pos - center) / RADIUS
    stick = relative.limit_length(1.0)
    if stick.length() < DEAD_ZONE:
        stick = Vector2.ZERO
    _set_action("steer_left", maxf(-stick.x, 0.0))
    _set_action("steer_right", maxf(stick.x, 0.0))
    _set_action("steer_up", maxf(-stick.y, 0.0))
    _set_action("steer_down", maxf(stick.y, 0.0))
    queue_redraw()


func _set_action(action: String, amount: float) -> void:
    if amount < 0.02:
        Input.action_release(action)
    else:
        Input.action_press(action, amount)


func reset_stick() -> void:
    touch_id = -1
    mouse_held = false
    stick = Vector2.ZERO
    for action in STICK_NAMES:
        Input.action_release(action)
    queue_redraw()


func _notification(what: int) -> void:
    if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
        reset_stick()
    elif what == NOTIFICATION_EXIT_TREE:
        reset_stick()


func _draw() -> void:
    var center := size * 0.5
    var active := touch_id != -1 or mouse_held
    draw_circle(center, RADIUS + 18.0, Color(0.025, 0.065, 0.11, 0.45))
    draw_circle(center, RADIUS, Color(0.025, 0.11, 0.15, 0.55))
    draw_arc(center, RADIUS, 0.0, TAU, 72, Color(0.30, 1.0, 0.91, 0.82), 3.0, true)
    draw_arc(center, RADIUS - 19.0, 0.0, TAU, 72, Color(0.30, 1.0, 0.91, 0.25), 1.5, true)
    for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
        var outward := Vector2(cos(angle), sin(angle))
        draw_line(center + outward * 58.0, center + outward * 69.0, Color(0.42, 0.95, 0.93, 0.52), 2.0, true)
    var knob_center := center + stick * RADIUS
    draw_circle(knob_center, 34.0, Color(0.04, 0.19, 0.24, 0.94))
    draw_arc(knob_center, 33.0, 0.0, TAU, 42, Color(0.57, 1.0, 0.93, 0.99 if active else 0.74), 3.5, true)
    draw_circle(knob_center, 13.0, Color(0.33, 0.87, 0.88, 0.65))

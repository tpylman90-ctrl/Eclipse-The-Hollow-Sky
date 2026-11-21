extends Node3D
## Vertical slice game director: three modes, seven checkpoints, a visible win state.

const WorldScript = preload("res://scripts/sky_world.gd")
const FlightScript = preload("res://scripts/flight.gd")
const InterfaceScript = preload("res://scripts/interface.gd")
const SoundScript = preload("res://scripts/sound.gd")
const ArtScript = preload("res://scripts/art_direction.gd")

enum Mode { TITLE, FLIGHT, END }

const INITIAL_TIME := 88.0
const MAX_HULL := 3

var mode := Mode.TITLE
var world
var craft
var interface_layer
var sound_system
var art_director: Node3D
var elapsed := 0.0
var time_remaining := INITIAL_TIME
var gate_index := 0
var hull := MAX_HULL
var score := 0
var message := ""
var message_age := 0.0


func _ready() -> void:
    world = WorldScript.new()
    world.name = "HollowSky"
    add_child(world)
    craft = FlightScript.new()
    craft.name = "TheSkiff"
    add_child(craft)
    art_director = ArtScript.new()
    art_director.name = "CinematicArtDirection"
    add_child(art_director)
    craft.reset_flight()
    sound_system = SoundScript.new()
    add_child(sound_system)
    interface_layer = InterfaceScript.new()
    add_child(interface_layer)
    interface_layer.start_requested.connect(_start)
    interface_layer.restart_requested.connect(_start)
    interface_layer.show_title()
    craft.set_active(false)
    world.set_active_gate(0)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("start_game") and mode != Mode.FLIGHT:
        _start()
        get_viewport().set_input_as_handled()


func _start() -> void:
    elapsed = 0.0
    time_remaining = INITIAL_TIME
    score = 0
    hull = MAX_HULL
    gate_index = 0
    message_age = 0.0
    message = "ALIGN WITH THE GOLDEN HALO"
    craft.reset_flight()
    craft.set_active(true)
    sound_system.play_launch()
    world.set_active_gate(0)
    interface_layer.show_play()
    mode = Mode.FLIGHT


func _process(delta: float) -> void:
    world.update_world(delta)
    sound_system.set_boost(craft.current_boost, delta)
    if mode != Mode.FLIGHT:
        return
    elapsed += delta
    time_remaining = maxf(0.0, time_remaining - delta)
    message_age += delta
    if time_remaining <= 0.0:
        _finish(false)
        return
    _check_gate()
    if mode != Mode.FLIGHT:
        return
    var prompt := message if message_age < 2.4 else _navigation_prompt()
    interface_layer.update_status(gate_index, world.GATE_COUNT, hull, time_remaining, craft.forward_speed, craft.energy, prompt)


func _check_gate() -> void:
    if gate_index >= world.gates.size():
        return
    var gate: Node3D = world.gates[gate_index]
    if craft.position.z > gate.position.z:
        return
    var aim := Vector2(craft.position.x - gate.position.x, craft.position.y - gate.position.y)
    var success: bool = aim.length() <= (5.0 * gate.scale.x)
    if success:
        var precision := maxf(0.0, 5.0 - aim.length())
        sound_system.play_gate()
        score += 1000 + int(precision * 150.0) + int(craft.forward_speed * 4.0)
        message = "SIGNAL RESTORED  +%d" % (1000 + int(precision * 150.0))
    else:
        hull -= 1
        sound_system.play_damage()
        message = "MISSED THE HALO  •  HULL DAMAGED"
    message_age = 0.0
    gate_index += 1
    world.set_active_gate(gate_index)
    if hull <= 0:
        _finish(false)
    elif gate_index >= world.GATE_COUNT:
        _finish(true)


func _navigation_prompt() -> String:
    if gate_index >= world.gates.size():
        return "ALL SIGNALS RESTORED"
    var target: Node3D = world.gates[gate_index]
    var dx: float = target.position.x - craft.position.x
    var dy: float = target.position.y - craft.position.y
    var horizontal := "CENTER"
    var vertical := "LEVEL"
    if dx > 4.0:
        horizontal = "RIGHT"
    elif dx < -4.0:
        horizontal = "LEFT"
    if dy > 3.0:
        vertical = "CLIMB"
    elif dy < -3.0:
        vertical = "DIVE"
    return "BEACON AHEAD  /  %s  /  %s" % [horizontal, vertical]


func _finish(victory: bool) -> void:
    if mode != Mode.FLIGHT:
        return
    mode = Mode.END
    craft.set_active(false)
    if victory:
        sound_system.play_finish()
        score += int(time_remaining * 25.0) + hull * 500
    else:
        sound_system.play_damage()
    interface_layer.show_result(victory, score, gate_index)

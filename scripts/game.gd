extends Node3D
## ECLIPSE: THE HOLLOW SKY -- Aether War progression and sortie director.
## Game loops through escalating 7-beacon sectors. Permanent upgrades persist offline.

const WorldScript = preload("res://scripts/sky_world.gd")
const FlightScript = preload("res://scripts/flight.gd")
const InterfaceScript = preload("res://scripts/interface.gd")
const SoundScript = preload("res://scripts/sound.gd")
const ArtScript = preload("res://scripts/art_direction.gd")
const SkyFXScript = preload("res://scripts/sky_fx.gd")
const CombatScript = preload("res://scripts/combat.gd")
const RenderBudgetScript = preload("res://scripts/render_budget.gd")
const MobileBudgetScript = preload("res://scripts/mobile_frame_budget.gd")
const PROGRESS_PATH := "user://eclipse_hangar.cfg"
const GRAPHICS_NAMES := ["GRAPHICS", "AUTO 60", "AUTO 90", "FPS MAX"]

enum Mode { TITLE, FLIGHT, END }

var mode := Mode.TITLE
var world
var craft
var interface_layer
var sound_system
var art_director: Node3D
var sky_fx
var combat
var render_budget
var mobile_budget
var benchmark_mode := 0
const BENCH_NAMES := ["VSYNC", "UNLOCKED", "CAP 60", "NO SHADOW"]

var elapsed := 0.0
var time_remaining := 88.0
var gate_index := 0
var sector := 1
var max_hull := 3
var hull := 3
var score := 0
var run_salvage := 0
var credits := 0
var record_score := 0
var highest_sector := 1
var upgrades := {"hull": 0, "weapon": 0, "reactor": 0}
var total_kills := 0
var bosses_destroyed := 0
var combo := 1
var combo_timer := 0.0
var damage_immunity := 0.0
var message := ""
var message_age := 0.0
var perf_elapsed := 0.0
var slow_samples := 0
var recovery_samples := 0
var graphics_index := 1
var telemetry_elapsed := 0.0
var hud_refresh_elapsed := 0.0


func _ready() -> void:
    _load_progress()
    world = WorldScript.new()
    world.name = "HollowSky"
    add_child(world)
    craft = FlightScript.new()
    craft.name = "TheSkiff"
    add_child(craft)
    art_director = ArtScript.new()
    art_director.name = "CinematicArtDirection"
    add_child(art_director)
    sky_fx = SkyFXScript.new()
    sky_fx.name = "AmbientSkyEffects"
    add_child(sky_fx)
    craft.reset_flight()
    # Static working-set traversal is built once, at scene load.
    render_budget = RenderBudgetScript.new()
    render_budget.name = "SpatialRenderBudget"
    add_child(render_budget)
    render_budget.configure(world, art_director, sky_fx, craft.chase_camera)
    mobile_budget = MobileBudgetScript.new()
    mobile_budget.name = "AndroidFrameSupervisor"
    add_child(mobile_budget)
    mobile_budget.configure(get_viewport(), world, sky_fx, render_budget)

    combat = CombatScript.new()
    combat.name = "AetherHostiles"
    add_child(combat)
    combat.bind(world, craft)
    combat.enemy_destroyed.connect(_enemy_destroyed)
    combat.player_damaged.connect(_player_damaged)
    combat.supply_collected.connect(_supply_collected)

    sound_system = SoundScript.new()
    add_child(sound_system)
    combat.plasma_fired.connect(sound_system.play_plasma)
    combat.hostile_struck.connect(sound_system.play_impact)
    interface_layer = InterfaceScript.new()
    add_child(interface_layer)
    interface_layer.start_requested.connect(_start)
    interface_layer.restart_requested.connect(_start)
    interface_layer.graphics_preset_requested.connect(_cycle_graphics)
    interface_layer.benchmark_requested.connect(_toggle_benchmark)
    interface_layer.upgrade_requested.connect(_buy_upgrade)
    interface_layer.hangar_requested.connect(_return_hangar)
    interface_layer.update_hangar(credits, record_score, upgrades)
    interface_layer.show_title()
    craft.set_active(false)
    world.set_active_gate(0)
    _apply_graphics()
    mobile_budget.set_active(false)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("start_game") and mode != Mode.FLIGHT:
        _start()
        get_viewport().set_input_as_handled()


func _load_progress() -> void:
    var config := ConfigFile.new()
    if config.load(PROGRESS_PATH) != OK:
        return
    credits = maxi(0, int(config.get_value("hangar", "credits", 0)))
    record_score = maxi(0, int(config.get_value("hangar", "record_score", 0)))
    highest_sector = maxi(1, int(config.get_value("hangar", "highest_sector", 1)))
    graphics_index = clampi(int(config.get_value("settings", "quality_profile", 1)), 0, GRAPHICS_NAMES.size() - 1)
    for name in ["hull", "weapon", "reactor"]:
        upgrades[name] = clampi(int(config.get_value("upgrades", name, 0)), 0, 3)


func _save_progress() -> void:
    var config := ConfigFile.new()
    config.set_value("hangar", "credits", credits)
    config.set_value("hangar", "record_score", record_score)
    config.set_value("hangar", "highest_sector", highest_sector)
    config.set_value("settings", "quality_profile", graphics_index)
    for name in ["hull", "weapon", "reactor"]:
        config.set_value("upgrades", name, int(upgrades[name]))
    var error: Error = config.save(PROGRESS_PATH)
    if error != OK:
        push_warning("Could not save ECLIPSE hangar progression: %s" % error_string(error))


func _buy_upgrade(kind: String) -> void:
    if mode != Mode.TITLE or not upgrades.has(kind):
        return
    var level: int = int(upgrades[kind])
    if level >= 3:
        return
    var cost: int = 100 * (level + 1) * (level + 1)
    if credits < cost:
        return
    credits -= cost
    upgrades[kind] = level + 1
    _save_progress()
    interface_layer.update_hangar(credits, record_score, upgrades)


func _start() -> void:
    mode = Mode.FLIGHT
    elapsed = 0.0
    time_remaining = 90.0
    sector = 1
    score = 0
    run_salvage = 0
    total_kills = 0
    bosses_destroyed = 0
    combo = 1
    combo_timer = 0.0
    damage_immunity = 0.0
    max_hull = 3 + int(upgrades["hull"])
    hull = max_hull
    gate_index = 0
    message_age = 0.0
    perf_elapsed = 0.0
    slow_samples = 0
    recovery_samples = 0
    craft.max_energy = 100.0 + float(upgrades["reactor"]) * 30.0
    craft.reset_flight()
    craft.set_active(true)
    mobile_budget.set_active(true)
    combat.reset_sector(sector, int(upgrades["weapon"]))
    _apply_graphics()
    sound_system.play_launch()
    world.set_active_gate(0)
    render_budget.update_budget(true)
    message = "MISSION: HUNT WARDENS AND RECOVER SEVEN BEACONS"
    interface_layer.show_play()


func _process(delta: float) -> void:
    world.update_world(delta)
    sky_fx.update_fx(delta, mode == Mode.FLIGHT)
    render_budget.tick(delta)
    mobile_budget.tick(delta, benchmark_mode != 0)
    sound_system.set_boost(craft.current_boost, delta)
    if mode != Mode.FLIGHT:
        return
    elapsed += delta
    perf_elapsed += delta
    telemetry_elapsed += delta
    hud_refresh_elapsed += delta
    message_age += delta
    combo_timer += delta
    damage_immunity = maxf(0.0, damage_immunity - delta)
    if combo_timer > 7.0:
        combo = 1
    if telemetry_elapsed > 0.55:
        telemetry_elapsed = 0.0
        interface_layer.update_graphics_hud(
            "%s %d%%" % [mobile_budget.preset_name(), mobile_budget.percent_scale()],
            Engine.get_frames_per_second(),
            int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
            Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
            Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
            render_budget.visible_static,
            render_budget.total_static,
            DisplayServer.screen_get_refresh_rate(),
            RenderingServer.get_current_rendering_method())
    combat.update_combat(delta)
    if mode != Mode.FLIGHT:
        return
    time_remaining = maxf(0.0, time_remaining - delta)
    if time_remaining <= 0.0:
        _finish(false)
        return
    _check_gate()
    if mode != Mode.FLIGHT:
        return
    # UI text relayout is unnecessary at native render frame frequency.
    # Responsive flight, enemy AI and combat still update on every frame.
    if hud_refresh_elapsed >= 0.12:
        hud_refresh_elapsed = 0.0
        var prompt := message if message_age < 2.8 else _navigation_prompt()
        interface_layer.update_status(gate_index, world.GATE_COUNT, hull,
            time_remaining, craft.forward_speed, craft.energy, prompt, max_hull)
        interface_layer.update_combat_hud(sector, combat.count_alive(), total_kills, combo, _mission_title())


func _check_gate() -> void:
    if gate_index >= world.gates.size():
        return
    var gate: Node3D = world.gates[gate_index]
    if craft.position.z > gate.position.z:
        return
    var aim := Vector2(craft.position.x - gate.position.x, craft.position.y - gate.position.y)
    var success: bool = aim.length() <= 5.0 * gate.scale.x
    if success:
        var precision := maxf(0.0, 5.0 - aim.length())
        score += 900 + int(precision * 160.0) + int(craft.forward_speed * 4.0)
        run_salvage += 15 + int(precision * 3.0)
        combo = mini(combo + 1, 8)
        combo_timer = 0.0
        time_remaining = minf(115.0, time_remaining + 4.0)
        message = "BEACON RESTORED   +SALVAGE   COMBO x%d" % combo
        sound_system.play_gate()
    else:
        hull -= 1
        combo = 1
        message = "BEACON MISSED   •   HULL DAMAGED"
        sound_system.play_damage()
    message_age = 0.0
    gate_index += 1
    world.set_active_gate(gate_index)
    if hull <= 0:
        _finish(false)
    elif gate_index >= world.GATE_COUNT:
        _complete_sector()


func _complete_sector() -> void:
    var completed := sector
    var bonus: int = completed * 75 + hull * 35
    run_salvage += bonus
    score += 1800 * completed + hull * 250
    sector += 1
    highest_sector = maxi(highest_sector, sector)
    gate_index = 0
    combo = mini(combo + 1, 8)
    combo_timer = 0.0
    time_remaining = minf(118.0, time_remaining + 52.0)
    craft.reset_flight()
    craft.set_active(true)
    combat.reset_sector(sector, int(upgrades["weapon"]))
    world.set_active_gate(0)
    render_budget.update_budget(true)
    message = "SECTOR %02d CLEARED  •  +%d SALVAGE  •  NEXT: %s" % [completed, bonus, _mission_title()]
    message_age = 0.0
    sound_system.play_finish()
    # Save earned salvage at every checkpoint sector, even if the app closes.
    _bank_progress()


func _enemy_destroyed(points: int, salvage: int, elite: bool) -> void:
    if mode != Mode.FLIGHT:
        return
    total_kills += 1
    combo = mini(combo + 1, 8)
    combo_timer = 0.0
    score += points * combo
    run_salvage += salvage
    if elite:
        bosses_destroyed += 1
        time_remaining = minf(118.0, time_remaining + 11.0)
        message = "WARDEN DESTROYED  •  +%d SALVAGE  •  TIME BONUS" % salvage
        sound_system.play_finish()
    else:
        message = "HUNTER DOWN  •  x%d COMBO  •  +%d SALVAGE" % [combo, salvage]
        sound_system.play_gate()
    message_age = 0.0


func _player_damaged(amount: int) -> void:
    if mode != Mode.FLIGHT or damage_immunity > 0.0:
        return
    hull -= amount
    damage_immunity = 1.2
    combo = 1
    message = "INCOMING FIRE  •  HULL CRITICAL" if hull <= 1 else "INCOMING FIRE  •  TAKE EVASIVE ACTION"
    message_age = 0.0
    sound_system.play_damage()
    if hull <= 0:
        _finish(false)


func _supply_collected(kind: String) -> void:
    if mode != Mode.FLIGHT:
        return
    match kind:
        "shield":
            hull = mini(max_hull, hull + 1)
            message = "REPAIR CACHE  •  HULL RESTORED"
        "energy":
            craft.energy = minf(craft.max_energy, craft.energy + 65.0)
            message = "AETHER FUEL  •  REACTOR CHARGED"
        "salvage":
            run_salvage += 45
            score += 400
            message = "RECOVERED RELIC  •  +45 SALVAGE"
    message_age = 0.0
    sound_system.play_gate()


func _mission_title() -> String:
    match (sector - 1) % 3:
        0:
            return "RECOVER THE BEACONS"
        1:
            return "INTERCEPT THE HUNTERS"
        _:
            return "WARDEN PURSUIT"


func _navigation_prompt() -> String:
    if gate_index >= world.gates.size():
        return "SECTOR CLEARED"
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


func _bank_progress() -> void:
    credits += run_salvage
    run_salvage = 0
    record_score = maxi(record_score, score)
    highest_sector = maxi(highest_sector, sector)
    _save_progress()
    interface_layer.update_hangar(credits, record_score, upgrades)


func _finish(victory: bool) -> void:
    if mode != Mode.FLIGHT:
        return
    mode = Mode.END
    craft.set_active(false)
    mobile_budget.set_active(false)
    _bank_progress()
    if victory:
        sound_system.play_finish()
    else:
        sound_system.play_damage()
    interface_layer.show_result(victory, score, gate_index)
    interface_layer.update_results("SECTOR %02d   •   %d DRONES DEFEATED   •   %d WARDENS\nSCORE %d   •   BANKED SALVAGE %d   •   BEST %d" % [
        sector, total_kills, bosses_destroyed, score, credits, record_score])


func _return_hangar() -> void:
    mode = Mode.TITLE
    craft.set_active(false)
    mobile_budget.set_active(false)
    interface_layer.update_hangar(credits, record_score, upgrades)
    interface_layer.show_title()


func _cycle_graphics() -> void:
    graphics_index = (graphics_index + 1) % GRAPHICS_NAMES.size()
    _apply_graphics()
    _save_progress()
    telemetry_elapsed = 1.0


func _apply_graphics() -> void:
    if mobile_budget == null:
        return
    mobile_budget.set_preset(graphics_index)
    # Benchmark diagnostic temporarily overrides the preset's sun policy.
    if benchmark_mode == 3:
        world.set_realtime_sun_shadows(false)


func _toggle_benchmark() -> void:
    # Cycle repeatable device tests without changing the scene/level:
    # 0 = normal; 1 = remove frame pacing; 2 = thermal-friendly 60 FPS cap;
    # 3 = shadow-off diagnostic (NOT a recommended graphics preset).
    benchmark_mode = (benchmark_mode + 1) % BENCH_NAMES.size()
    var capped: bool = benchmark_mode == 2
    var unlocked: bool = benchmark_mode == 1 or benchmark_mode == 3
    Engine.max_fps = 60 if capped else 0
    DisplayServer.window_set_vsync_mode(
        DisplayServer.VSYNC_DISABLED if unlocked else DisplayServer.VSYNC_ENABLED)
    world.set_realtime_sun_shadows(benchmark_mode != 3)
    interface_layer.update_benchmark(BENCH_NAMES[benchmark_mode])
    telemetry_elapsed = 1.0

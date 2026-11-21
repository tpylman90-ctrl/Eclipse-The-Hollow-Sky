extends Node
## Mobile-frame budget supervisor inspired by the documented GRID Autosport
## Graphics / Performance tradeoff.  Keeps UI at native res and changes only 3D
## render scale on multi-second averages. No procedural scene rebuilds.
## Native Vulkan Mobile is retained in every preset.

const PRESET_NAMES := ["GRAPHICS", "AUTO 60", "AUTO 90", "FPS MAX"]
const TARGETS := [0, 60, 90, 120]
const MIN_SCALES := [1.0, 0.77, 0.67, 0.56]
const MAX_SCALES := [1.0, 0.97, 0.86, 0.77]
const INITIAL_SCALES := [1.0, 0.90, 0.77, 0.66]

var preset := 0
var current_scale := 1.0
var view: Viewport
var sun: DirectionalLight3D
var effects
var render_budget
var environment: Environment
var active := false
var enabled_auto := false
var sample_elapsed := 0.0
var sum_frame_time := 0.0
var sample_frames := 0
var poor_windows := 0
var good_windows := 0
var last_average_ms := 0.0
var changes := 0


func configure(viewport: Viewport, course, fx, budget) -> void:
    view = viewport
    sun = course.find_child("PrimarySun", true, false) as DirectionalLight3D
    effects = fx
    render_budget = budget
    var world_env := course.find_child("WorldEnvironment", true, false) as WorldEnvironment
    if world_env != null:
        environment = world_env.environment
    if view != null and RenderingServer.get_current_rendering_method() != "gl_compatibility":
        view.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
        view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
        view.msaa_3d = Viewport.MSAA_DISABLED
    set_preset(0)


func set_preset(index: int) -> void:
    preset = clampi(index, 0, PRESET_NAMES.size() - 1)
    sample_elapsed = 0.0
    sum_frame_time = 0.0
    sample_frames = 0
    poor_windows = 0
    good_windows = 0
    last_average_ms = 0.0
    enabled_auto = preset > 0
    _set_scale(INITIAL_SCALES[preset])
    if sun != null:
        sun.shadow_enabled = true
        if preset <= 1:
            sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
            sun.directional_shadow_max_distance = 120.0
            sun.shadow_blur = 1.0
        elif preset == 2:
            sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
            sun.directional_shadow_max_distance = 92.0
            sun.shadow_blur = 0.9
        else:
            sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
            sun.directional_shadow_max_distance = 65.0
            sun.shadow_blur = 0.75
    render_budget.set_quality(mini(preset, 2))
    # Preserve primary color design and glowing engine parts.
    # Cut only the redundant transparent cloud bank/remote cascades.
    effects.set_low_effects(preset >= 2)
    if environment != null:
        environment.glow_enabled = true
        environment.glow_intensity = 0.55 if preset < 3 else 0.41


func set_active(enabled: bool) -> void:
    active = enabled
    if not enabled:
        sample_elapsed = 0.0
        sum_frame_time = 0.0
        sample_frames = 0


func tick(delta: float, benchmarking: bool = false) -> void:
    if not active or not enabled_auto or benchmarking:
        return
    if delta <= 0.0 or delta > 0.15:
        # Avoid resolution thrash during pause/resume or shader first-use.
        return
    sample_elapsed += delta
    sum_frame_time += delta
    sample_frames += 1
    if sample_elapsed < 1.8:
        return
    var observed_ms: float = sum_frame_time * 1000.0 / float(maxi(1, sample_frames))
    last_average_ms = observed_ms
    sample_elapsed = 0.0
    sum_frame_time = 0.0
    sample_frames = 0
    var target: float = float(TARGETS[preset])
    if observed_ms > 1000.0 / (target * 0.93):
        poor_windows += 1
        good_windows = 0
    elif observed_ms < 1000.0 / (target * 1.09):
        good_windows += 1
        poor_windows = 0
    else:
        poor_windows = 0
        good_windows = 0
    if poor_windows >= 2:
        poor_windows = 0
        _set_scale(current_scale - 0.055)
    elif good_windows >= 3:
        good_windows = 0
        _set_scale(current_scale + 0.025)


func _set_scale(scale: float) -> void:
    var new_scale: float = clampf(scale, MIN_SCALES[preset], MAX_SCALES[preset])
    if absf(new_scale - current_scale) < 0.009 and changes > 0:
        return
    current_scale = new_scale
    if view != null and RenderingServer.get_current_rendering_method() != "gl_compatibility":
        view.scaling_3d_scale = current_scale
    changes += 1


func preset_name() -> String:
    return PRESET_NAMES[preset]


func target_fps() -> int:
    return TARGETS[preset]


func percent_scale() -> int:
    return roundi(current_scale * 100.0)

extends Node

const STRATA_SHADER = preload("res://shaders/strata.gdshader")
const WEATHER_SHADER = preload("res://shaders/weathered_architecture.gdshader")
## Static render working-set controller.
## Godot frustum culling handles camera angles. This conservative forward/back
## visibility window prevents submitting distant course sections, long before
## they matter visually. Does NOT unload physics, gates, or enemy logic.

var camera: Camera3D
var world
var sky_fx
var geometry: Array[Dictionary] = []
var gates: Array[Node3D] = []
var cascades: Array[Node3D] = []
var scan_elapsed := 0.0
var ahead_distance := 455.0
var behind_distance := 115.0
var total_static := 0
var visible_static := 0
var hidden_static := 0
var cheap_materials: Dictionary = {}
var low_detail_distant := false
var simplified_static := 0
var far_start := 230.0
var lod_eligible := 0

func configure(course, architecture, effects, chase: Camera3D) -> void:
    world = course
    sky_fx = effects
    camera = chase
    geometry.clear()
    cheap_materials.clear()
    lod_eligible = 0
    gates.clear()
    cascades.clear()
    _collect_static(course)
    _collect_static(architecture)
    for gate in course.gates:
        gates.append(gate)
    for waterfall in effects.cascades:
        cascades.append(waterfall)
    total_static = geometry.size()
    update_budget(true)
    print("ECLIPSE RENDER BUDGET: %d spatial meshes, %d gates, %d waterfall groups" % [
        total_static, gates.size(), cascades.size()])


func _collect_static(parent: Node) -> void:
    for child in parent.get_children():
        if child.name.begins_with("Gate_"):
            continue
        if child is MeshInstance3D:
            var item := child as MeshInstance3D
            if item.mesh != null:
                var box := item.get_aabb()
                var center := item.global_transform * box.get_center()
                var half_extent: float = box.size.length() * 0.5
                var huge: bool = half_extent > 160.0
                # Preserve the celestial background, which is designed to be
                # a persistent silhouette even when far beyond the course.
                if center.x < -180.0 and center.y > 55.0 and center.z < -1050.0:
                    huge = true
                if not huge:
                    var original: Material = item.material_override
                    var distant: Material = _make_far_material(original)
                    if distant != null:
                        lod_eligible += 1
                    geometry.append({
                        "mesh": item, "z": center.z, "radius": half_extent,
                        "original": original, "distant": distant, "is_distant": false
                    })
        _collect_static(child)


func _make_far_material(source: Material) -> Material:
    if not source is ShaderMaterial:
        return null
    var source_shader := (source as ShaderMaterial).shader
    var tint: Color
    if source_shader == STRATA_SHADER:
        tint = (source as ShaderMaterial).get_shader_parameter("stone_tint")
    elif source_shader == WEATHER_SHADER:
        tint = (source as ShaderMaterial).get_shader_parameter("base_tint")
    else:
        return null
    var key: String = tint.to_html(false)
    if cheap_materials.has(key):
        return cheap_materials[key]
    var far := StandardMaterial3D.new()
    far.albedo_color = tint * Color(0.96, 0.97, 1.0, 1.0)
    far.roughness = 0.77
    far.metallic = 0.12
    cheap_materials[key] = far
    return far


func set_quality(level: int) -> void:
    low_detail_distant = level >= 2
    match level:
        0:
            ahead_distance = 455.0
            far_start = 100000.0
        1:
            ahead_distance = 350.0
            far_start = 100000.0
        2:
            ahead_distance = 290.0
            far_start = 175.0
        _:
            ahead_distance = 245.0
            far_start = 130.0
    update_budget(true)


func tick(delta: float) -> void:
    scan_elapsed += delta
    if scan_elapsed >= 0.25:
        scan_elapsed = 0.0
        update_budget(false)


func update_budget(force: bool) -> void:
    if camera == null:
        return
    var forward_z: float = camera.global_position.z
    visible_static = 0
    hidden_static = 0
    simplified_static = 0
    for entry in geometry:
        var node := entry["mesh"] as MeshInstance3D
        if not is_instance_valid(node):
            continue
        var radius: float = float(entry["radius"])
        var delta_z: float = forward_z - float(entry["z"])
        var should_show: bool = delta_z > -behind_distance - radius and delta_z < ahead_distance + radius
        if node.visible != should_show:
            node.visible = should_show
        if should_show:
            visible_static += 1
        else:
            hidden_static += 1
        # Material-only LOD: geometry silhouettes are unchanged. Only far-away
        # mineral noise shading is replaced with palette-matched cheap PBR.
        var distant: Material = entry["distant"]
        if distant != null:
            var currently_distant: bool = bool(entry["is_distant"])
            var switch_distance: float = far_start + (-15.0 if currently_distant else 15.0)
            var want_distant: bool = low_detail_distant and should_show and delta_z > switch_distance
            if want_distant != currently_distant:
                node.material_override = distant if want_distant else entry["original"]
                entry["is_distant"] = want_distant
            if want_distant:
                simplified_static += 1
    # Ring lights, animated gate ornaments and waterfall ribbons need no
    # rendering when their entire landmark is outside the flight working set.
    for gate in gates:
        var distance_ahead: float = forward_z - gate.global_position.z
        gate.visible = distance_ahead > -behind_distance and distance_ahead < ahead_distance + 45.0
    for i in range(cascades.size()):
        var cascade: Node3D = cascades[i]
        var ahead: float = forward_z - cascade.global_position.z
        var in_range: bool = ahead > -behind_distance and ahead < ahead_distance
        var allowed: bool = not sky_fx.low_effects or i % 2 == 0
        cascade.visible = in_range and allowed


func visible_count() -> int:
    return visible_static

extends Node3D
## ECLIPSE art pass 03: atmospheric depth, aether cascades and floating remnants.
## Effects are assembled from original geometry and lightweight Godot shaders.

const FALL_SHADER = preload("res://shaders/aetherfall.gdshader")
const CLOUD_SHADER = preload("res://shaders/cloud_sea.gdshader")

var world
var scenery: Node3D
var cascades: Array[Node3D] = []
var time_elapsed := 0.0
var low_effects := false
var shard_material: StandardMaterial3D
var accent_material: StandardMaterial3D


func _ready() -> void:
    world = get_parent().get_node("HollowSky")
    scenery = Node3D.new()
    scenery.name = "AtmosphereAndAetherfalls"
    add_child(scenery)
    shard_material = StandardMaterial3D.new()
    shard_material.albedo_color = Color("#354858")
    shard_material.metallic = 0.19
    shard_material.roughness = 0.78
    accent_material = StandardMaterial3D.new()
    accent_material.albedo_color = Color("#61ced9")
    accent_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    accent_material.emission_enabled = true
    accent_material.emission = Color("#4dcfdb")
    accent_material.emission_energy_multiplier = 1.7
    _build_cloud_ocean()
    _build_cascades()
    _build_floating_shards()
    _build_sky_meridians()


func _build_cloud_ocean() -> void:
    var sea := PlaneMesh.new()
    sea.size = Vector2(1100.0, 1660.0)
    var bank := MeshInstance3D.new()
    bank.name = "LowerCloudSea"
    bank.mesh = sea
    bank.position = Vector3(0.0, -63.0, -560.0)
    var material := ShaderMaterial.new()
    material.shader = CLOUD_SHADER
    material.set_shader_parameter("cloud_blue", Color("#355975"))
    material.set_shader_parameter("cloud_peach", Color("#876077"))
    material.set_shader_parameter("cloud_opacity", 0.61)
    bank.material_override = material
    bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    scenery.add_child(bank)
    # Distant brighter layer adds separation without a volumetric renderer.
    var high_bank := MeshInstance3D.new()
    high_bank.name = "CloudHighlight"
    high_bank.mesh = sea
    high_bank.position = Vector3(0.0, -79.0, -570.0)
    high_bank.scale = Vector3(1.25, 1.0, 1.25)
    var highlight := ShaderMaterial.new()
    highlight.shader = CLOUD_SHADER
    highlight.set_shader_parameter("cloud_blue", Color("#405d80"))
    highlight.set_shader_parameter("cloud_peach", Color("#997e88"))
    highlight.set_shader_parameter("cloud_opacity", 0.32)
    high_bank.material_override = highlight
    high_bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    scenery.add_child(high_bank)


func _build_cascades() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 190527
    for i in range(world.gates.size()):
        var gate: Node3D = world.gates[i]
        var center: Vector3 = gate.position
        for side in [-1, 1]:
            var direction: float = float(side)
            var start := Vector3(
                center.x + direction * (25.0 + rng.randf_range(0.0, 8.0)),
                center.y - rng.randf_range(11.0, 19.0),
                center.z + rng.randf_range(-21.0, 21.0)
            )
            # Each cascade is several separate, thin ribbons rather than a flat rectangle.
            var root := Node3D.new()
            root.position = start
            root.name = "Aetherfall_%02d_%d" % [i, side]
            scenery.add_child(root)
            cascades.append(root)
            for strip in range(3):
                var width: float = rng.randf_range(1.4, 2.9)
                var height: float = rng.randf_range(37.0, 59.0)
                var drift: float = rng.randf_range(-3.2, 3.2)
                var offset_x: float = float(strip - 1) * 1.35
                var ribbon_mesh := _ribbon_mesh(width, height, drift, float(strip) * 1.82)
                var ribbon := MeshInstance3D.new()
                ribbon.mesh = ribbon_mesh
                ribbon.position = Vector3(offset_x, 0.0, float(strip) * 0.56)
                ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                var flow := ShaderMaterial.new()
                flow.shader = FALL_SHADER
                flow.set_shader_parameter("ribbon_seed", rng.randf_range(0.0, 15.0))
                flow.set_shader_parameter("flow_rate", rng.randf_range(0.82, 1.48))
                flow.set_shader_parameter("strength", 0.68)
                flow.set_shader_parameter("core_tint", Color("#2797c4"))
                flow.set_shader_parameter("rim_tint", Color("#85f2e9"))
                ribbon.material_override = flow
                root.add_child(ribbon)
            # Luminous arch at lip of the fall, without dynamic per-pixel lights.
            var crown := TorusMesh.new()
            crown.inner_radius = 2.0
            crown.outer_radius = 2.2
            crown.rings = 32
            crown.ring_segments = 6
            var frame := MeshInstance3D.new()
            frame.mesh = crown
            frame.rotation.x = PI / 2.0
            frame.position.y = 0.5
            frame.material_override = accent_material
            frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            root.add_child(frame)


func _ribbon_mesh(width: float, length: float, drift: float, seed_shift: float) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var sections := 20
    for i in range(sections):
        var ta: float = float(i) / float(sections)
        var tb: float = float(i + 1) / float(sections)
        var aa: float = sin(ta * 7.0 + seed_shift) * (0.25 + ta * 0.32)
        var ab: float = sin(tb * 7.0 + seed_shift) * (0.25 + tb * 0.32)
        var wa: float = width * (1.0 - ta * 0.62)
        var wb: float = width * (1.0 - tb * 0.62)
        var ca := Vector3(drift * ta + aa, -length * ta, 0.0)
        var cb := Vector3(drift * tb + ab, -length * tb, 0.0)
        _vertex(st, ca + Vector3(-wa, 0.0, 0.0), Vector2(0.0, ta))
        _vertex(st, ca + Vector3(wa, 0.0, 0.0), Vector2(1.0, ta))
        _vertex(st, cb + Vector3(wb, 0.0, 0.0), Vector2(1.0, tb))
        _vertex(st, ca + Vector3(-wa, 0.0, 0.0), Vector2(0.0, ta))
        _vertex(st, cb + Vector3(wb, 0.0, 0.0), Vector2(1.0, tb))
        _vertex(st, cb + Vector3(-wb, 0.0, 0.0), Vector2(0.0, tb))
    st.generate_normals()
    return st.commit()


func _vertex(st: SurfaceTool, pos: Vector3, uv: Vector2) -> void:
    st.set_uv(uv)
    st.add_vertex(pos)


func _build_floating_shards() -> void:
    # One instanced mesh for atmospheric debris, rather than hundreds of nodes.
    var rng := RandomNumberGenerator.new()
    rng.seed = 408276
    var rock := CylinderMesh.new()
    rock.top_radius = 0.08
    rock.bottom_radius = 0.73
    rock.height = 2.9
    rock.radial_segments = 5
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = rock
    mm.instance_count = 126
    for i in range(mm.instance_count):
        var z: float = rng.randf_range(-1060.0, -31.0)
        var side: float = -1.0 if i % 2 == 0 else 1.0
        var x: float = rng.randf_range(26.0, 79.0) * side
        var y: float = rng.randf_range(-30.0, 30.0)
        var size: float = rng.randf_range(0.35, 3.2)
        var angle: float = rng.randf_range(-PI, PI)
        var turn := Basis(Vector3(0.23, 0.90, 0.21).normalized(), angle)
        mm.set_instance_transform(i, Transform3D(turn.scaled(Vector3(size, size, size)), Vector3(x, y, z)))
    var debris := MultiMeshInstance3D.new()
    debris.name = "InstancedFracturedDebris"
    debris.multimesh = mm
    debris.material_override = shard_material
    debris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    scenery.add_child(debris)


func _build_sky_meridians() -> void:
    # Elegant silhouette bands along the flight corridor, deliberately well off the route.
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color("#b28c69")
    metal.metallic = 0.65
    metal.roughness = 0.33
    for i in range(5):
        var t: float = float(i)
        var center := Vector3((-1.0 if i % 2 == 0 else 1.0) * 78.0, 24.0 + t * 4.0, -160.0 - t * 191.0)
        var torus := TorusMesh.new()
        torus.inner_radius = 28.0 + t * 2.0
        torus.outer_radius = 28.25 + t * 2.0
        torus.rings = 64
        torus.ring_segments = 8
        var orbit := MeshInstance3D.new()
        orbit.mesh = torus
        orbit.position = center
        orbit.rotation = Vector3(PI * 0.5 + t * 0.1, 0.24, t * 0.32)
        orbit.material_override = metal
        orbit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        scenery.add_child(orbit)


func update_fx(delta: float, enabled: bool) -> void:
    time_elapsed += delta
    if not enabled:
        return
    # Very subtle structural motion; shader TIME provides the actual flow animation.
    for i in range(cascades.size()):
        cascades[i].rotation.z = sin(time_elapsed * 0.29 + float(i) * 2.03) * 0.013

func set_low_effects(enabled: bool) -> void:
    if low_effects == enabled:
        return
    low_effects = enabled
    for i in range(cascades.size()):
        cascades[i].visible = not low_effects or i % 2 == 0
    var high_bank := scenery.get_node_or_null("CloudHighlight")
    if high_bank != null:
        high_bank.visible = not low_effects

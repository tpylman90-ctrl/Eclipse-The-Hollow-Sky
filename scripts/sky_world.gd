extends Node3D
## Deterministic, original world geometry. All meshes are made at runtime.

const GATE_COUNT := 7
const COURSE_SPACING := 142.0

var gates: Array[Node3D] = []
var motion_time := 0.0
var rock_material: Material
var cliff_material: Material
var stone_material: StandardMaterial3D
var ivory_material: StandardMaterial3D
var gold_material: StandardMaterial3D
var cyan_material: StandardMaterial3D
var cloud_material: StandardMaterial3D
var gate_material: StandardMaterial3D
var active_gate := 0


func _ready() -> void:
    _make_materials()
    _make_atmosphere()
    _build_course()


func _make_materials() -> void:
    # World-space erosion shader gives large cliff faces mineral variation without texture tiling.
    var shader_asset := preload("res://shaders/strata.gdshader")
    var rock_shader := ShaderMaterial.new()
    rock_shader.shader = shader_asset
    rock_shader.set_shader_parameter("stone_tint", Color("#394b58"))
    rock_shader.set_shader_parameter("mineral_tint", Color("#6a7b83"))
    rock_shader.set_shader_parameter("stratum_frequency", 0.42)
    rock_shader.set_shader_parameter("relief", 0.58)
    rock_material = rock_shader
    var cliff_shader := ShaderMaterial.new()
    cliff_shader.shader = shader_asset
    cliff_shader.set_shader_parameter("stone_tint", Color("#384756"))
    cliff_shader.set_shader_parameter("mineral_tint", Color("#87918f"))
    cliff_shader.set_shader_parameter("stratum_frequency", 0.58)
    cliff_shader.set_shader_parameter("relief", 0.55)
    cliff_material = cliff_shader
    stone_material = _material(Color(0.28, 0.35, 0.43), 0.78, 0.12)
    ivory_material = _material(Color(0.62, 0.69, 0.70), 0.64, 0.18)
    gold_material = _material(Color(0.82, 0.52, 0.24), 0.43, 0.55)
    cyan_material = _glow(Color(0.14, 0.91, 0.91), 3.2)
    cloud_material = _material(Color(0.36, 0.31, 0.48, 0.20), 1.0, 0.0)
    cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    gate_material = _glow(Color(1.0, 0.66, 0.30), 3.5)


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    mat.metallic = metallic
    return mat


func _glow(color: Color, strength: float) -> StandardMaterial3D:
    var mat := _material(color, 0.3, 0.25)
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = strength
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return mat


func _make_atmosphere() -> void:
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color("#0b142c")
    sky_mat.sky_horizon_color = Color("#755067")
    sky_mat.ground_horizon_color = Color("#73576b")
    sky_mat.ground_bottom_color = Color("#172939")
    sky_mat.use_debanding = true
    var sky := Sky.new()
    sky.sky_material = sky_mat
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_energy = 0.85
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.fog_enabled = true
    environment.fog_light_color = Color("#465e74")
    environment.fog_density = 0.0015
    environment.fog_sky_affect = 0.14
    environment.glow_enabled = true
    environment.glow_intensity = 0.57
    environment.glow_bloom = 0.09
    environment.glow_hdr_threshold = 0.84
    environment.glow_hdr_scale = 1.75
    environment.tonemap_exposure = 1.07
    environment.adjustment_enabled = true
    environment.adjustment_contrast = 1.08
    environment.adjustment_saturation = 1.07
    var world_env := WorldEnvironment.new()
    world_env.environment = environment
    add_child(world_env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-38.0, -31.0, 0.0)
    sun.light_color = Color("#ffcb93")
    sun.light_energy = 1.63
    sun.shadow_enabled = true
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
    sun.directional_shadow_max_distance = 165.0
    sun.directional_shadow_blend_splits = true
    sun.shadow_blur = 1.35
    add_child(sun)
    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-8.0, 134.0, 0.0)
    fill.light_color = Color("#80b4d0")
    fill.light_energy = 0.68
    fill.shadow_enabled = false
    add_child(fill)
    var sun_disc := SphereMesh.new()
    sun_disc.radius = 30.0
    sun_disc.height = 60.0
    sun_disc.radial_segments = 28
    sun_disc.rings = 12
    _mesh(self, sun_disc, Vector3(-220.0, 140.0, -1100.0), _glow(Color(1.0, 0.59, 0.29), 2.0))


func _build_course() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 20481120
    for i in range(GATE_COUNT):
        var gate_x := sin(float(i) * 1.18) * 24.0 + cos(float(i) * 0.61) * 5.0
        var gate_y := 6.5 + sin(float(i) * 1.37) * 9.0 + float(i % 2) * 3.5
        var gate_z := -104.0 - float(i) * COURSE_SPACING
        var center := Vector3(gate_x, gate_y, gate_z)
        _make_gate(center, i)
        var left := Vector3(-66.0 + rng.randf_range(-9.0, 9.0), -15.0 + rng.randf_range(-9.0, 6.0), gate_z + rng.randf_range(-22.0, 22.0))
        var right := Vector3(67.0 + rng.randf_range(-12.0, 8.0), -17.0 + rng.randf_range(-7.0, 6.0), gate_z + rng.randf_range(-26.0, 26.0))
        _make_island(left, rng.randf_range(24.0, 34.0), rng, true)
        _make_island(right, rng.randf_range(23.0, 37.0), rng, i % 2 == 0)
        _make_arch_fragments(center, rng)
    for j in range(66):
        var rx := rng.randf_range(-220.0, 220.0)
        if absf(rx) < 41.0:
            rx += 62.0 if rx >= 0.0 else -62.0
        var rz := rng.randf_range(-1130.0, 55.0)
        var ry := rng.randf_range(-64.0, 8.0)
        _make_island(Vector3(rx, ry, rz), rng.randf_range(3.0, 13.0), rng, false)
    for k in range(12):
        var cx := rng.randf_range(-270.0, 270.0)
        var cy := rng.randf_range(-30.0, -4.0)
        var cz := rng.randf_range(-1080.0, -80.0)
        _cloud(Vector3(cx, cy, cz), rng.randf_range(35.0, 70.0))
    _make_final_monument()


func _make_island(pos: Vector3, radius: float, rng: RandomNumberGenerator, temple: bool) -> void:
    # Sculpted five-band silhouette: broken lip, cliff fractures, tapered stone root.
    # Replaces the original low-sided cone while keeping a single mesh/draw call per island.
    var root := Node3D.new()
    root.position = pos
    add_child(root)
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    surface.set_smooth_group(-1)
    var sections := 28 if radius >= 18.0 else 17
    var bands: Array = []
    for ring_index in range(5):
        var band: Array[Vector3] = []
        for n in range(sections):
            var a: float = TAU * float(n) / float(sections)
            var jag: float = 1.0 + sin(a * 5.0 + pos.x * 0.11) * 0.068 + cos(a * 11.0 + pos.z * 0.07) * 0.037
            var variance: float = rng.randf_range(0.91, 1.08)
            var contour: float = radius * jag * variance
            var factor: float = 0.46
            var height: float = 0.7
            match ring_index:
                0:
                    factor = 0.45
                    height = 1.3 + rng.randf_range(-0.52, 0.75)
                1:
                    factor = 1.0
                    height = rng.randf_range(-0.8, 1.1)
                2:
                    factor = rng.randf_range(0.88, 1.07)
                    height = -radius * rng.randf_range(0.24, 0.40)
                3:
                    factor = rng.randf_range(0.51, 0.73)
                    height = -radius * rng.randf_range(0.73, 0.94)
                4:
                    factor = rng.randf_range(0.19, 0.33)
                    height = -radius * rng.randf_range(1.19, 1.33)
            band.append(Vector3(cos(a) * contour * factor, height, sin(a) * contour * factor))
        bands.append(band)
    var top_center := Vector3(0.0, 1.22, 0.0)
    var bottom := Vector3(rng.randf_range(-1.5, 1.5), -radius * 1.56, rng.randf_range(-1.5, 1.5))
    for n in range(sections):
        var nxt := (n + 1) % sections
        _triangle(surface, top_center, bands[0][nxt], bands[0][n], Color(0.57, 0.61, 0.61))
        for j in range(4):
            var a: Vector3 = bands[j][n]
            var b: Vector3 = bands[j][nxt]
            var d: Vector3 = bands[j + 1][n]
            var e: Vector3 = bands[j + 1][nxt]
            var shade: float = 0.52 - float(j) * 0.085
            var tint := Color(shade * 0.90, shade, shade * 1.09)
            _triangle(surface, a, b, e, tint)
            _triangle(surface, a, e, d, tint)
        _triangle(surface, bands[4][n], bands[4][nxt], bottom, Color(0.12, 0.18, 0.25))
    surface.generate_normals()
    var rock := MeshInstance3D.new()
    rock.mesh = surface.commit()
    rock.material_override = rock_material
    rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    root.add_child(rock)
    if temple and radius > 20.0:
        _make_temple(root, radius, rng)


func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
    st.set_color(color)
    st.add_vertex(a)
    st.add_vertex(b)
    st.add_vertex(c)


func _make_temple(parent: Node3D, radius: float, rng: RandomNumberGenerator) -> void:
    var heading := rng.randf_range(-0.4, 0.4)
    var temple := Node3D.new()
    temple.rotation.y = heading
    parent.add_child(temple)
    var floor_box := BoxMesh.new()
    floor_box.size = Vector3(radius * 0.96, 1.4, radius * 0.62)
    _mesh(temple, floor_box, Vector3(0.0, 1.0, 0.0), stone_material)
    for side in [-1.0, 1.0]:
        for i in range(3):
            var x: float = side * radius * 0.37
            var z := (float(i) - 1.0) * radius * 0.22
            var column := CylinderMesh.new()
            column.top_radius = 0.74
            column.bottom_radius = 0.97
            column.height = rng.randf_range(9.0, 16.0)
            column.radial_segments = 7
            var node := _mesh(temple, column, Vector3(x, column.height / 2.0 + 1.3, z), ivory_material)
            node.rotation.y = rng.randf_range(-0.2, 0.2)
            var cap := BoxMesh.new()
            cap.size = Vector3(2.8, 0.65, 2.5)
            _mesh(temple, cap, Vector3(x, column.height + 1.5, z), gold_material)
        var rail := BoxMesh.new()
        rail.size = Vector3(1.1, 0.25, radius * 0.54)
        _mesh(temple, rail, Vector3(side * radius * 0.37, 2.0, 0.0), cyan_material)
    var altar := CylinderMesh.new()
    altar.top_radius = 2.0
    altar.bottom_radius = 2.6
    altar.height = 5.0
    altar.radial_segments = 6
    _mesh(temple, altar, Vector3(0.0, 4.4, 0.0), stone_material)
    var relic := SphereMesh.new()
    relic.radius = 1.65
    relic.height = 3.3
    relic.radial_segments = 8
    relic.rings = 4
    _mesh(temple, relic, Vector3(0.0, 8.0, 0.0), cyan_material)


func _make_gate(center: Vector3, index: int) -> void:
    var gate := Node3D.new()
    gate.name = "Gate_%02d" % index
    gate.position = center
    add_child(gate)
    gates.append(gate)
    var ring := TorusMesh.new()
    ring.inner_radius = 4.65
    ring.outer_radius = 5.07
    ring.rings = 44
    ring.ring_segments = 9
    var halo := _mesh(gate, ring, Vector3.ZERO, gate_material)
    halo.name = "Halo"
    halo.rotation.x = PI / 2.0
    var ring_inner := TorusMesh.new()
    ring_inner.inner_radius = 4.17
    ring_inner.outer_radius = 4.23
    ring_inner.rings = 44
    ring_inner.ring_segments = 5
    var inner := _mesh(gate, ring_inner, Vector3.ZERO, cyan_material)
    inner.rotation.x = PI / 2.0
    var ornaments := Node3D.new()
    ornaments.name = "Ornaments"
    gate.add_child(ornaments)
    for j in range(12):
        var theta := TAU * float(j) / 12.0
        var spike := PrismMesh.new()
        spike.size = Vector3(0.8, 1.65, 0.35)
        var spike_node := _mesh(ornaments, spike, Vector3(cos(theta) * 5.68, sin(theta) * 5.68, 0.0), gold_material)
        spike_node.rotation.z = theta - PI / 2.0
        var dot := SphereMesh.new()
        dot.radius = 0.22
        dot.height = 0.44
        dot.radial_segments = 8
        dot.rings = 4
        _mesh(ornaments, dot, Vector3(cos(theta) * 6.18, sin(theta) * 6.18, 0.0), cyan_material)
    var light := OmniLight3D.new()
    light.name = "BeaconLight"
    light.light_color = Color(1.0, 0.58, 0.22)
    light.light_energy = 1.6
    light.omni_range = 19.0
    light.shadow_enabled = false
    gate.add_child(light)
    var marker := Node3D.new()
    marker.name = "Marker"
    gate.add_child(marker)
    var pyramid := CylinderMesh.new()
    pyramid.top_radius = 0.0
    pyramid.bottom_radius = 1.5
    pyramid.height = 2.6
    pyramid.radial_segments = 4
    var tip := _mesh(marker, pyramid, Vector3(0.0, 8.7, 0.0), cyan_material)
    tip.rotation.y = PI / 4.0
    if index == GATE_COUNT - 1:
        gate.scale = Vector3.ONE * 1.13
    light.visible = index == 0


func _make_arch_fragments(center: Vector3, rng: RandomNumberGenerator) -> void:
    for side in [-1.0, 1.0]:
        var base_x: float = center.x + side * rng.randf_range(15.0, 20.0)
        var base_y := center.y - rng.randf_range(12.0, 17.0)
        var pedestal := CylinderMesh.new()
        pedestal.top_radius = 2.0
        pedestal.bottom_radius = 3.6
        pedestal.height = 20.0
        pedestal.radial_segments = 5
        var col := _mesh(self, pedestal, Vector3(base_x, base_y, center.z + rng.randf_range(-5.0, 5.0)), stone_material)
        col.rotation.z = side * rng.randf_range(0.08, 0.25)
        var stripe := CylinderMesh.new()
        stripe.top_radius = 2.05
        stripe.bottom_radius = 2.05
        stripe.height = 0.6
        stripe.radial_segments = 5
        _mesh(self, stripe, col.position + Vector3(0.0, 8.0, 0.0), cyan_material)
    for j in range(8):
        var shard := CylinderMesh.new()
        shard.top_radius = 0.0
        shard.bottom_radius = rng.randf_range(0.18, 0.65)
        shard.height = rng.randf_range(2.0, 6.0)
        shard.radial_segments = 4
        var x := center.x + rng.randf_range(-30.0, 30.0)
        var y := center.y + rng.randf_range(-18.0, 18.0)
        var z := center.z + rng.randf_range(-26.0, 26.0)
        var sh := _mesh(self, shard, Vector3(x, y, z), gold_material)
        sh.rotation = Vector3(rng.randf(), rng.randf(), rng.randf())


func _cloud(pos: Vector3, spread: float) -> void:
    var cloud := SphereMesh.new()
    cloud.radius = 1.0
    cloud.height = 2.0
    cloud.radial_segments = 12
    cloud.rings = 6
    var node := _mesh(self, cloud, pos, cloud_material)
    node.scale = Vector3(spread, 2.0, spread * 0.45)


func _make_final_monument() -> void:
    var root := Node3D.new()
    root.position = Vector3(0.0, -35.0, -1120.0)
    add_child(root)
    var platform := CylinderMesh.new()
    platform.top_radius = 55.0
    platform.bottom_radius = 47.0
    platform.height = 14.0
    platform.radial_segments = 12
    _mesh(root, platform, Vector3(0.0, 0.0, 0.0), cliff_material)
    for i in range(8):
        var angle := TAU * float(i) / 8.0
        var column := CylinderMesh.new()
        column.top_radius = 1.6
        column.bottom_radius = 3.4
        column.height = 46.0
        column.radial_segments = 5
        var node := _mesh(root, column, Vector3(cos(angle) * 34.0, 29.0, sin(angle) * 34.0), stone_material)
        node.rotation.z = 0.13 * sin(angle)
        var flame := SphereMesh.new()
        flame.radius = 2.2
        flame.height = 4.4
        flame.radial_segments = 8
        flame.rings = 4
        _mesh(root, flame, Vector3(cos(angle) * 34.0, 54.0, sin(angle) * 34.0), cyan_material)


func _mesh(parent: Node3D, shape: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.mesh = shape
    item.position = at
    item.material_override = mat
    item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(item)
    return item


func set_active_gate(index: int) -> void:
    active_gate = index
    for i in range(gates.size()):
        var lamp: OmniLight3D = gates[i].get_node("BeaconLight")
        lamp.visible = i == index
        var marker: Node3D = gates[i].get_node("Marker")
        marker.visible = i >= index


func update_world(delta: float) -> void:
    motion_time += delta
    for i in range(gates.size()):
        var gate := gates[i]
        var ornaments: Node3D = gate.get_node("Ornaments")
        ornaments.rotation.z += delta * (0.12 if i == active_gate else 0.032)
        var marker: Node3D = gate.get_node("Marker")
        marker.position.y = sin(motion_time * 2.0 + float(i)) * 0.35

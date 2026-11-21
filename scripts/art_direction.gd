extends Node3D

const MeshFactory = preload("res://scripts/mesh_factory.gd")
const PBR_WEATHER_SHADER = preload("res://shaders/weathered_architecture.gdshader")
## Art-pass 02: a cinematic architectural layer, entirely generated from reusable meshes.
## Designed for the Godot 4 Compatibility renderer and a midrange/entry-level Android GPU.

var world
var basalt: Material
var cut_stone: Material
var polished_stone: Material
var aged_bronze: Material
var dark_bronze: Material
var light_gold: StandardMaterial3D
var energy: StandardMaterial3D
var lunar: StandardMaterial3D
var atmosphere: StandardMaterial3D
var structural: Node3D
var seed := 260119

func _ready() -> void:
    world = get_parent().get_node("HollowSky")
    structural = Node3D.new()
    structural.name = "RuinsAndMonuments"
    add_child(structural)
    basalt = _pbr(Color("#293440"), Color("#111c24"), 0.04, 0.85, 0.83)
    cut_stone = _pbr(Color("#596d76"), Color("#233743"), 0.07, 0.72, 0.72)
    polished_stone = _pbr(Color("#899a9e"), Color("#334c55"), 0.14, 0.39, 0.42)
    aged_bronze = _pbr(Color("#aa8260"), Color("#40312c"), 0.64, 0.53, 0.34)
    dark_bronze = _pbr(Color("#4a4444"), Color("#201c23"), 0.59, 0.59, 0.48)
    light_gold = _glow(Color("#efb46d"), 1.9)
    energy = _glow(Color("#59d4d4"), 2.7)
    lunar = _glow(Color("#b89bac"), 0.72)
    atmosphere = _mat(Color(0.35, 0.64, 0.69, 0.12), 1.0, 0.0)
    atmosphere.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    atmosphere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _build_arrival()
    _build_cathedrals()
    _build_background_monoliths()
    _build_distant_planet()
    _build_starlight()


func _pbr(base: Color, veins: Color, metal: float, weather: float, rough: float) -> ShaderMaterial:
    var surface := ShaderMaterial.new()
    surface.shader = PBR_WEATHER_SHADER
    surface.set_shader_parameter("base_tint", base)
    surface.set_shader_parameter("vein_tint", veins)
    surface.set_shader_parameter("polished_edge_tint", base.lightened(0.30))
    surface.set_shader_parameter("metalness", metal)
    surface.set_shader_parameter("weathering", weather)
    surface.set_shader_parameter("roughness_level", rough)
    surface.set_shader_parameter("map_scale", 0.44)
    return surface


func _mat(color: Color, rough: float, metal: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    m.metallic = metal
    return m


func _glow(color: Color, power: float) -> StandardMaterial3D:
    var m := _mat(color, 0.25, 0.2)
    m.emission_enabled = true
    m.emission = color
    m.emission_energy_multiplier = power
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return m


func _mesh(parent: Node3D, shape: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    n.mesh = shape
    n.position = pos
    n.material_override = material
    n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if material in [basalt, cut_stone, polished_stone, aged_bronze, dark_bronze] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(n)
    return n


func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
    # Even narrow accent bars keep crisp physically illuminated bevels.
    var bevel: float = minf(0.26, minf(size.x, minf(size.y, size.z)) * 0.20)
    return _mesh(parent, MeshFactory.bevel_box(size, bevel), pos, material)


func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, sides: int, material: Material) -> MeshInstance3D:
    var b := CylinderMesh.new()
    b.top_radius = radius * 0.91
    b.bottom_radius = radius
    b.height = height
    b.radial_segments = sides
    return _mesh(parent, b, pos, material)


func _beam(parent: Node3D, from: Vector3, to: Vector3, width: float, material: Material) -> MeshInstance3D:
    var b := CylinderMesh.new()
    b.top_radius = width * 0.83
    b.bottom_radius = width
    b.height = from.distance_to(to)
    b.radial_segments = 6
    var node := _mesh(parent, b, (from + to) * 0.5, material)
    node.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
    return node


func _ring(parent: Node3D, at: Vector3, inner_r: float, outer_r: float, material: Material, segments: int = 44) -> MeshInstance3D:
    var ring := TorusMesh.new()
    ring.inner_radius = inner_r
    ring.outer_radius = outer_r
    ring.rings = segments
    ring.ring_segments = 7
    var n := _mesh(parent, ring, at, material)
    n.rotation.x = PI * 0.5
    return n


func _make_pedestal(root: Node3D, center: Vector3, radius: float) -> void:
    _cylinder(root, center, radius, 1.5, 12, basalt)
    _cylinder(root, center + Vector3.UP * 1.15, radius * 0.95, 0.8, 12, polished_stone)
    _cylinder(root, center + Vector3.UP * 1.62, radius * 0.90, 0.16, 12, aged_bronze)


func _build_arrival() -> void:
    # First 110 m of flight: ground silhouettes, arches and visible approach structures.
    _make_architecture(Vector3(-33.0, -8.0, -62.0), 0.91)
    _make_architecture(Vector3(34.0, -10.0, -67.0), 0.95)
    _make_beacon_column(Vector3(-24.0, -7.2, -25.0), 20.0)
    _make_beacon_column(Vector3(24.0, -7.2, -25.0), 19.5)
    for side in [-1, 1]:
        var sx: float = float(side)
        var positions := [
            Vector3(sx * 17.0, -17.0, -80.0),
            Vector3(sx * 22.0, -17.0, -118.0),
            Vector3(sx * 26.0, -17.0, -155.0)
        ]
        for p in positions:
            _make_broken_spire(p, 12.0, 1.0)


func _make_architecture(center: Vector3, scale_factor: float) -> void:
    var temple := Node3D.new()
    temple.position = center
    temple.scale = Vector3.ONE * scale_factor
    structural.add_child(temple)
    _make_pedestal(temple, Vector3.ZERO, 17.5)
    _box(temple, Vector3(0.0, 2.45, 0.0), Vector3(28.0, 2.4, 18.0), cut_stone)
    _box(temple, Vector3(0.0, 3.8, 0.0), Vector3(27.0, 0.33, 17.2), aged_bronze)
    for side in [-1, 1]:
        var sx: float = float(side)
        _beam(temple, Vector3(sx * 11.2, 4.0, -6.0), Vector3(sx * 11.2, 20.0, -6.0), 1.45, polished_stone)
        _beam(temple, Vector3(sx * 11.2, 4.0, 6.0), Vector3(sx * 11.2, 15.0, 6.0), 1.45, cut_stone)
        _box(temple, Vector3(sx * 11.2, 19.5, -6.0), Vector3(4.4, 1.0, 4.4), aged_bronze)
        _box(temple, Vector3(sx * 11.2, 20.4, -6.0), Vector3(3.7, 0.2, 3.7), light_gold)
        _box(temple, Vector3(sx * 11.2, 14.4, 6.0), Vector3(4.3, 1.2, 4.3), aged_bronze)
    _box(temple, Vector3(0.0, 17.0, 6.0), Vector3(24.0, 2.2, 2.2), polished_stone)
    _box(temple, Vector3(0.0, 18.55, 6.0), Vector3(24.5, 0.28, 2.6), light_gold)
    _cylinder(temple, Vector3(0.0, 6.0, 0.0), 2.3, 5.0, 8, dark_bronze)
    _cylinder(temple, Vector3(0.0, 10.8, 0.0), 1.20, 5.4, 8, energy)


func _make_beacon_column(base: Vector3, height: float) -> void:
    var root := Node3D.new()
    root.position = base
    structural.add_child(root)
    _make_pedestal(root, Vector3.ZERO, 3.8)
    _cylinder(root, Vector3(0.0, height * 0.51, 0.0), 1.45, height, 8, polished_stone)
    for i in range(5):
        var y: float = 4.0 + float(i) * (height - 4.0) / 5.0
        _cylinder(root, Vector3(0.0, y, 0.0), 1.8, 0.22, 8, aged_bronze)
    _cylinder(root, Vector3(0.0, height + 1.3, 0.0), 2.5, 1.0, 8, cut_stone)
    _cylinder(root, Vector3(0.0, height + 2.0, 0.0), 2.0, 0.20, 8, light_gold)
    _cylinder(root, Vector3(0.0, height + 3.45, 0.0), 0.80, 2.6, 6, energy)


func _make_broken_spire(base: Vector3, height: float, scale_factor: float) -> void:
    var r := Node3D.new()
    r.position = base
    r.scale = Vector3.ONE * scale_factor
    structural.add_child(r)
    var shaft := _cylinder(r, Vector3(0.0, height * 0.35, 0.0), 1.8, height * 0.70, 6, cut_stone)
    shaft.rotation.z = 0.07
    _cylinder(r, Vector3(0.05, height * 0.7, 0.0), 2.45, 0.60, 6, aged_bronze)
    _cylinder(r, Vector3(0.05, height * 0.79, 0.0), 0.18, height * 0.11, 6, energy)


func _build_cathedrals() -> void:
    for i in range(world.gates.size()):
        var gate: Node3D = world.gates[i]
        var center: Vector3 = gate.position
        var group := Node3D.new()
        group.name = "Sanctum_%02d" % i
        structural.add_child(group)
        # 3 staggered concentric, fractured crowns give each gate strong silhouette.
        _ring(group, center + Vector3(0.0, 0.0, -4.2), 11.1, 11.9, dark_bronze, 48)
        _ring(group, center + Vector3(0.0, 0.0, -3.7), 11.9, 12.05, aged_bronze, 48)
        _ring(group, center + Vector3(0.0, 0.0, -3.1), 13.5, 13.57, energy, 48)
        for side in [-1, 1]:
            var sx: float = float(side)
            var x: float = center.x + 12.8 * sx
            var p := Vector3(x, center.y - 14.1, center.z - 4.4)
            _make_broken_spire(p, 17.0 + float(i % 3) * 2.5, 1.0)
            # Halo-clasped meridian braces support the crown.
            _beam(group,
                Vector3(x, center.y + 1.2, center.z - 4.2),
                Vector3(center.x + sx * 8.3, center.y + 9.0, center.z - 4.2),
                0.72, polished_stone)
            _beam(group,
                Vector3(x, center.y + 1.2, center.z - 4.2),
                Vector3(center.x + sx * 8.3, center.y - 9.0, center.z - 4.2),
                0.72, polished_stone)
        # Flying through the front opening is always unobstructed.
        _cylinder(group, center + Vector3(0.0, -17.3, -4.3), 8.0, 1.9, 12, basalt)
        _cylinder(group, center + Vector3(0.0, -16.25, -4.3), 7.6, 0.18, 12, aged_bronze)
        if i % 2 == 0:
            _make_architecture(center + Vector3(39.0, -24.0, 19.0), 0.65)
            _make_architecture(center + Vector3(-41.0, -27.0, -16.0), 0.60)


func _build_background_monoliths() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    for i in range(28):
        var z: float = rng.randf_range(-1170.0, -185.0)
        var tower_side: float = -1.0 if i % 2 == 0 else 1.0
        var x: float = rng.randf_range(88.0, 155.0) * tower_side
        var y: float = rng.randf_range(-50.0, -19.0)
        var tall: float = rng.randf_range(32.0, 85.0)
        var t := Node3D.new()
        t.position = Vector3(x, y, z)
        t.rotation.y = rng.randf_range(-PI, PI)
        t.scale = Vector3.ONE * rng.randf_range(0.75, 1.1)
        structural.add_child(t)
        _cylinder(t, Vector3(0.0, tall * 0.46, 0.0), rng.randf_range(5.0, 10.0), tall, 5, basalt)
        _box(t, Vector3(0.0, tall * 0.84, 0.0), Vector3(19.0, 2.3, 14.0), cut_stone)
        _box(t, Vector3(0.0, tall * 0.88, 0.0), Vector3(18.0, 0.20, 14.0), aged_bronze)
        for side in [-1, 1]:
            var sx: float = float(side)
            _beam(t, Vector3(sx * 11.0, tall * 0.87, 0.0), Vector3(sx * 16.0, tall * 0.25, 0.0), 0.8, dark_bronze)
        var spike_height: float = rng.randf_range(10.0, 19.0)
        _cylinder(t, Vector3(0.0, tall + spike_height * 0.47, 0.0), 2.4, spike_height, 6, cut_stone)
        _cylinder(t, Vector3(0.0, tall + spike_height + 1.1, 0.0), 1.0, 1.8, 6, energy)


func _build_distant_planet() -> void:
    # Camera-facing relic moon and two brass orbital bands.
    var planet_position := Vector3(-245.0, 121.0, -1210.0)
    var p := SphereMesh.new()
    p.radius = 68.0
    p.height = 136.0
    p.radial_segments = 40
    p.rings = 22
    _mesh(structural, p, planet_position, lunar)
    _ring(structural, planet_position + Vector3(0.0, 0.0, 4.0), 86.0, 86.9, dark_bronze, 72)
    var orbit := _ring(structural, planet_position + Vector3(0.0, 0.0, 5.0), 95.0, 95.4, light_gold, 72)
    orbit.rotation.z = 0.27
    var orbit2 := _ring(structural, planet_position + Vector3(0.0, 0.0, -3.0), 104.0, 104.3, aged_bronze, 72)
    orbit2.rotation.z = -0.32
    # Far away, independent skyline gives atmospheric depth beyond the playable ruins.
    var nebula_plane := SphereMesh.new()
    nebula_plane.radius = 0.5
    nebula_plane.height = 1.0
    nebula_plane.radial_segments = 14
    nebula_plane.rings = 6
    for j in range(17):
        var pos := Vector3(-430.0 + float(j) * 52.0, 50.0 + 18.0 * sin(float(j) * 0.89), -1320.0)
        var cloud := _mesh(structural, nebula_plane, pos, atmosphere)
        cloud.scale = Vector3(95.0, 11.0, 18.0)


func _build_starlight() -> void:
    # Single instanced mesh/draw call rather than hundreds of particle nodes.
    var rng := RandomNumberGenerator.new()
    rng.seed = seed + 120
    var spark := SphereMesh.new()
    spark.radius = 0.16
    spark.height = 0.32
    spark.radial_segments = 6
    spark.rings = 4
    var amount := 390
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.instance_count = amount
    mm.mesh = spark
    for i in range(amount):
        var z: float = rng.randf_range(-1120.0, -12.0)
        var x: float = rng.randf_range(-75.0, 75.0)
        var y: float = rng.randf_range(-24.0, 46.0)
        var scale_factor: float = rng.randf_range(0.5, 2.8)
        mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * scale_factor), Vector3(x, y, z)))
    var field := MultiMeshInstance3D.new()
    field.name = "FloatingAetherDust"
    field.multimesh = mm
    field.material_override = energy
    field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    structural.add_child(field)

extends Node3D

const MeshFactory = preload("res://scripts/mesh_factory.gd")
## Art pass 02 - layered metallic hull, aviation panelization, glass canopy ribs.
## This is all original hard-surface geometry, built into the parent skiff at runtime.

var graphite: StandardMaterial3D
var steel: StandardMaterial3D
var titanium: StandardMaterial3D
var bronze: StandardMaterial3D
var glass: StandardMaterial3D
var turquoise: StandardMaterial3D
var ember: StandardMaterial3D
var bolt: StandardMaterial3D

func _ready() -> void:
    graphite = _material(Color("#17212c"), 0.50, 0.55)
    steel = _material(Color("#687e8b"), 0.23, 0.76)
    titanium = _material(Color("#a2b2ad"), 0.34, 0.69)
    bronze = _material(Color("#a48055"), 0.34, 0.65)
    glass = _material(Color("#133746"), 0.08, 0.45)
    turquoise = _emissive(Color("#56e4db"), 3.3)
    ember = _emissive(Color("#f0a165"), 4.0)
    bolt = _material(Color("#b7bcbd"), 0.26, 0.78)
    _body_panels()
    _wing_panels()
    _canopy()
    _engine_detail()
    _livery()


func _material(c: Color, rough: float, metal: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = rough
    m.metallic = metal
    return m


func _emissive(c: Color, strength: float) -> StandardMaterial3D:
    var m := _material(c, 0.25, 0.1)
    m.emission_enabled = true
    m.emission = c
    m.emission_energy_multiplier = strength
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return m


func _mesh(m: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    n.mesh = m
    n.position = pos
    n.material_override = material
    n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(n)
    return n


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
    var bevel: float = minf(0.14, minf(size.x, minf(size.y, size.z)) * 0.20)
    return _mesh(MeshFactory.bevel_box(size, bevel), pos, mat)


func _beam(a: Vector3, b: Vector3, width: float, material: Material) -> MeshInstance3D:
    var cylinder := CylinderMesh.new()
    cylinder.height = a.distance_to(b)
    cylinder.top_radius = width * 0.84
    cylinder.bottom_radius = width
    cylinder.radial_segments = 6
    var node := _mesh(cylinder, (a + b) * 0.5, material)
    node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
    return node


func _plate(verts: PackedVector3Array, material: Material) -> void:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    surface.set_smooth_group(-1)
    for v in verts:
        surface.add_vertex(v)
    surface.generate_normals()
    var mat := material.duplicate() as StandardMaterial3D
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    _mesh(surface.commit(), Vector3.ZERO, mat)


func _body_panels() -> void:
    _box(Vector3(1.38, 0.13, 2.8), Vector3(0.0, 0.38, 0.35), graphite)
    _box(Vector3(1.03, 0.18, 1.18), Vector3(0.0, 0.53, 1.07), steel)
    _box(Vector3(0.13, 0.045, 2.8), Vector3(0.0, 0.46, -1.63), bronze)
    _beam(Vector3(-0.7, 0.16, -2.48), Vector3(-0.13, 0.15, -4.08), 0.04, turquoise)
    _beam(Vector3(0.7, 0.16, -2.48), Vector3(0.13, 0.15, -4.08), 0.04, turquoise)
    for side in [-1, 1]:
        var x: float = float(side)
        _beam(Vector3(x * 0.82, 0.28, -2.30), Vector3(x * 1.18, 0.23, 1.55), 0.05, graphite)
        _beam(Vector3(x * 0.92, 0.12, -2.0), Vector3(x * 0.80, -0.17, 1.8), 0.025, bronze)
        for i in range(6):
            var z: float = -1.43 + float(i) * 0.45
            var slit := _box(Vector3(0.43, 0.065, 0.13), Vector3(x * 0.99, 0.30, z), graphite)
            slit.rotation.y = x * 0.16
        _box(Vector3(0.08, 0.14, 1.8), Vector3(x * 0.58, -0.19, 1.65), bronze)
    var plate := _box(Vector3(0.9, 0.055, 0.95), Vector3(0.0, 0.66, 1.03), titanium)
    plate.rotation.x = 0.11


func _wing_panels() -> void:
    for sign in [-1, 1]:
        var sx: float = float(sign)
        _plate(PackedVector3Array([
            Vector3(sx * 0.93, 0.17, -1.05),
            Vector3(sx * 3.72, 0.11, 0.27),
            Vector3(sx * 2.75, 0.20, 1.12),
            Vector3(sx * 0.93, 0.17, -1.05),
            Vector3(sx * 2.75, 0.20, 1.12),
            Vector3(sx * 1.0, 0.24, 1.16)
        ]), steel)
        _plate(PackedVector3Array([
            Vector3(sx * 1.04, 0.22, -0.80),
            Vector3(sx * 2.75, 0.15, 0.06),
            Vector3(sx * 2.14, 0.27, 0.70)
        ]), graphite)
        _beam(Vector3(sx * 1.05, 0.27, -0.82), Vector3(sx * 3.80, 0.13, 0.28), 0.035, bronze)
        _beam(Vector3(sx * 3.80, 0.13, 0.28), Vector3(sx * 2.80, 0.20, 1.08), 0.04, turquoise)
        _box(Vector3(0.08, 0.11, 1.4), Vector3(sx * 2.50, 0.12, 0.80), graphite)
        _box(Vector3(0.11, 0.04, 0.95), Vector3(sx * 2.45, 0.13, 0.65), turquoise)
        _box(Vector3(0.70, 0.10, 0.4), Vector3(sx * 3.45, -0.08, 0.58), bronze)
        for i in range(3):
            var z: float = 0.30 + float(i) * 0.36
            _box(Vector3(0.50, 0.065, 0.095), Vector3(sx * 2.6, 0.14, z), graphite)
        # Segmented airframe strakes and wingtip strobe housings.
        var tip := _box(Vector3(0.3, 0.27, 0.73), Vector3(sx * 4.08, -0.13, 0.17), graphite)
        tip.rotation.y = sx * 0.29
        _box(Vector3(0.12, 0.17, 0.22), Vector3(sx * 4.10, -0.12, -0.19), turquoise)
        _beam(Vector3(sx * 1.50, 0.22, 1.54), Vector3(sx * 2.07, 1.03, 2.28), 0.07, bronze)


func _canopy() -> void:
    # Dark, almost-black cockpit glass with structural framing and an illuminated spine.
    for i in range(5):
        var t: float = float(i) / 4.0
        var z: float = -1.45 + t * 2.44
        var rise: float = sin(t * PI) * 0.32
        _beam(Vector3(-0.51, 0.47 + rise, z), Vector3(0.51, 0.47 + rise, z), 0.035, titanium)
    _beam(Vector3(-0.53, 0.40, -1.60), Vector3(-0.61, 0.68, 0.78), 0.046, bronze)
    _beam(Vector3(0.53, 0.40, -1.60), Vector3(0.61, 0.68, 0.78), 0.046, bronze)
    _beam(Vector3(0.0, 0.68, -1.44), Vector3(0.0, 0.74, 0.63), 0.038, turquoise)
    _box(Vector3(0.63, 0.055, 0.27), Vector3(0.0, 0.27, -1.65), glass)


func _engine_detail() -> void:
    for side in [-1, 1]:
        var sx: float = float(side)
        var engine_z: float = 2.89
        # Toroidal nozzle rims face rear, so the illuminated turbines have clear silhouette.
        for i in range(3):
            var ring := TorusMesh.new()
            ring.inner_radius = 0.35 + float(i) * 0.042
            ring.outer_radius = 0.39 + float(i) * 0.042
            ring.rings = 20
            ring.ring_segments = 8
            var obj := _mesh(ring, Vector3(sx * 1.30, -0.24, engine_z - 0.16 + float(i) * 0.11), titanium if i == 0 else bronze)
            obj.rotation.x = PI / 2.0
        for j in range(4):
            var angle: float = float(j) * TAU / 4.0
            _beam(
                Vector3(sx * 1.3 + cos(angle) * 0.30, -0.24 + sin(angle) * 0.30, 2.89),
                Vector3(sx * 1.30, -0.24, 2.89),
                0.032, graphite)
        _box(Vector3(0.35, 0.075, 0.75), Vector3(sx * 2.48, 0.25, 1.23), graphite)
        _box(Vector3(0.29, 0.035, 0.65), Vector3(sx * 2.48, 0.29, 1.23), bronze)
    _box(Vector3(1.06, 0.18, 0.11), Vector3(0.0, 0.17, 2.14), steel)
    for i in range(3):
        var x: float = (float(i) - 1.0) * 0.27
        _box(Vector3(0.18, 0.08, 0.10), Vector3(x, 0.20, 2.21), ember)


func _livery() -> void:
    _box(Vector3(0.77, 0.03, 0.52), Vector3(0.0, 0.53, 1.22), bronze)
    _box(Vector3(0.55, 0.04, 0.23), Vector3(0.0, 0.565, 1.28), graphite)
    _box(Vector3(0.21, 0.04, 0.07), Vector3(0.0, 0.57, 1.05), turquoise)
    # Aviation hardware reads through even when the craft is small on the phone screen.
    var rivet := SphereMesh.new()
    rivet.radius = 0.035
    rivet.height = 0.07
    rivet.radial_segments = 6
    rivet.rings = 4
    for side in [-1, 1]:
        var sx: float = float(side)
        for i in range(7):
            _mesh(rivet, Vector3(sx * 0.72, 0.39, -1.91 + float(i) * 0.45), bolt)

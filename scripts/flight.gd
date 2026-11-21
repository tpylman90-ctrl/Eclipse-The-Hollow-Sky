extends Node3D

const MeshFactory = preload("res://scripts/mesh_factory.gd")
const FORGED_SHADER = preload("res://shaders/forged_metal.gdshader")

const SkiffArtScript = preload("res://scripts/skiff_art.gd")
const ThrusterFXScript = preload("res://scripts/thruster_fx.gd")
## Lightweight third-person flight controller and original hard-surface skiff mesh.

var active := false
var energy := 100.0
var max_energy := 100.0
var forward_speed := 36.0
var velocity_xy := Vector2.ZERO
var current_boost := false
var phase := 0.0
var body: Node3D
var chase_camera: Camera3D
var plume_left: MeshInstance3D
var plume_right: MeshInstance3D
var ion_wake

var hull_mat: Material
var armor_mat: Material
var canopy_mat: StandardMaterial3D
var trim_mat: StandardMaterial3D
var thruster_mat: StandardMaterial3D


func _ready() -> void:
    hull_mat = _forged(Color("#304352"), 0.64, 0.33)
    armor_mat = _forged(Color("#7e99a2"), 0.78, 0.23)
    canopy_mat = _material(Color("#133547"), 0.10, 0.47)
    trim_mat = _emissive(Color(0.17, 0.96, 0.92), 3.1)
    thruster_mat = _emissive(Color(1.0, 0.49, 0.22), 3.8)
    body = Node3D.new()
    body.name = "Aether_Skiff"
    add_child(body)
    _make_skiff()
    var detail := SkiffArtScript.new()
    detail.name = "HullDetailArt"
    body.add_child(detail)
    ion_wake = ThrusterFXScript.new()
    ion_wake.name = "IonWakeFX"
    body.add_child(ion_wake)
    chase_camera = Camera3D.new()
    chase_camera.name = "ChaseCamera"
    chase_camera.current = true
    chase_camera.fov = 72.0
    chase_camera.near = 0.13
    chase_camera.far = 1450.0
    get_parent().add_child(chase_camera)
    chase_camera.global_position = global_position + Vector3(0.0, 4.0, 10.4)
    chase_camera.look_at(global_position + Vector3(0.0, 1.0, -12.0), Vector3.UP)


func _forged(tint: Color, metal: float, rough: float) -> ShaderMaterial:
    var result := ShaderMaterial.new()
    result.shader = FORGED_SHADER
    result.set_shader_parameter("paint_color", tint)
    result.set_shader_parameter("exposed_metal", tint.lightened(0.32))
    result.set_shader_parameter("metalness", metal)
    result.set_shader_parameter("roughness_base", rough)
    result.set_shader_parameter("wear", 0.18)
    return result


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.metallic = metallic
    return m


func _emissive(color: Color, intensity: float) -> StandardMaterial3D:
    var m := _material(color, 0.24, 0.10)
    m.emission_enabled = true
    m.emission = color
    m.emission_energy_multiplier = intensity
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return m


func _make_skiff() -> void:
    # Forward is -Z. Multiplane fuselage, stepped armored shoulder and split tail.
    _box(Vector3(1.55, 0.49, 4.65), Vector3(0.0, 0.0, -0.35), hull_mat)
    _box(Vector3(1.20, 0.20, 2.9), Vector3(0.0, 0.27, -0.50), armor_mat)
    _box(Vector3(1.05, 0.22, 1.95), Vector3(0.0, -0.30, 0.75), hull_mat)
    # Long bevelled nose.
    _surface([
        Vector3(-0.77, 0.12, -2.5), Vector3(0.77, 0.12, -2.5), Vector3(0.0, -0.02, -4.28),
        Vector3(-0.77, -0.21, -2.5), Vector3(-0.77, 0.12, -2.5), Vector3(0.0, -0.02, -4.28),
        Vector3(0.77, 0.12, -2.5), Vector3(0.77, -0.21, -2.5), Vector3(0.0, -0.02, -4.28)
    ], armor_mat)
    # Low-poly swept lifting surfaces.
    _surface([
        Vector3(-0.45, 0.02, -1.15), Vector3(-4.6, -0.16, 0.25), Vector3(-3.15, 0.05, 1.65),
        Vector3(-0.45, 0.02, -1.15), Vector3(-3.15, 0.05, 1.65), Vector3(-0.65, 0.12, 1.22),
        Vector3(0.45, 0.02, -1.15), Vector3(3.15, 0.05, 1.65), Vector3(4.6, -0.16, 0.25),
        Vector3(0.45, 0.02, -1.15), Vector3(0.65, 0.12, 1.22), Vector3(3.15, 0.05, 1.65)
    ], hull_mat)
    _surface([
        Vector3(-0.68, 0.1, -1.14), Vector3(-3.9, 0.04, 0.20), Vector3(-2.9, 0.19, 1.12),
        Vector3(0.68, 0.1, -1.14), Vector3(2.9, 0.19, 1.12), Vector3(3.9, 0.04, 0.20)
    ], armor_mat)
    # Twin outer armored float pods.
    for sign_x in [-1.0, 1.0]:
        _box(Vector3(0.83, 0.38, 2.16), Vector3(sign_x * 2.42, -0.17, 0.65), armor_mat)
        _box(Vector3(0.27, 0.12, 1.7), Vector3(sign_x * 2.42, 0.08, 0.62), trim_mat)
        _box(Vector3(1.3, 0.1, 0.21), Vector3(sign_x * 3.28, 0.13, 1.1), trim_mat)
        # Forward swept bladelets.
        _surface([
            Vector3(sign_x * 2.65, 0.13, -0.10),
            Vector3(sign_x * 3.42, 0.04, -1.7),
            Vector3(sign_x * 2.19, 0.09, -0.83)
        ], armor_mat)
        # Tall split stabilizers.
        _surface([
            Vector3(sign_x * 1.38, 0.12, 1.32),
            Vector3(sign_x * 2.06, 1.02, 2.36),
            Vector3(sign_x * 1.67, 0.05, 2.30),
            Vector3(sign_x * 1.38, 0.12, 1.32),
            Vector3(sign_x * 1.83, 0.92, 2.06),
            Vector3(sign_x * 2.06, 1.02, 2.36)
        ], hull_mat)
        _cylinder(0.40, 1.18, Vector3(sign_x * 0.73, -0.12, 2.28), hull_mat)
        _cylinder(0.26, 0.11, Vector3(sign_x * 0.73, -0.12, 2.94), thruster_mat)
    var cockpit := SphereMesh.new()
    cockpit.radius = 1.0
    cockpit.height = 2.0
    cockpit.radial_segments = 20
    cockpit.rings = 12
    var glass := _mesh(cockpit, Vector3(0.0, 0.34, -0.33), canopy_mat)
    glass.scale = Vector3(0.69, 0.39, 1.62)
    _box(Vector3(0.1, 0.035, 2.4), Vector3(0.0, 0.72, -0.44), trim_mat)
    _box(Vector3(0.85, 0.10, 0.17), Vector3(0.0, 0.4, -2.34), trim_mat)
    for sign_x in [-1.0, 1.0]:
        var engine := CylinderMesh.new()
        engine.top_radius = 0.44
        engine.bottom_radius = 0.49
        engine.height = 1.45
        engine.radial_segments = 12
        var node := _mesh(engine, Vector3(sign_x * 1.30, -0.24, 1.92), hull_mat)
        node.rotation.x = PI / 2.0
        var plume := SphereMesh.new()
        plume.radius = 0.45
        plume.height = 0.9
        plume.radial_segments = 12
        plume.rings = 8
        var glow_node := _mesh(plume, Vector3(sign_x * 1.30, -0.24, 2.82), thruster_mat)
        glow_node.scale = Vector3(0.65, 0.65, 1.6)
        if sign_x < 0.0:
            plume_left = glow_node
        else:
            plume_right = glow_node


func _box(size: Vector3, at: Vector3, material: Material) -> void:
    var bevel: float = minf(0.22, minf(size.x, minf(size.y, size.z)) * 0.22)
    _mesh(MeshFactory.bevel_box(size, bevel), at, material)


func _cylinder(radius: float, length: float, at: Vector3, material: Material) -> void:
    var shape := CylinderMesh.new()
    shape.top_radius = radius
    shape.bottom_radius = radius
    shape.height = length
    shape.radial_segments = 12
    var mesh_node := _mesh(shape, at, material)
    mesh_node.rotation.x = PI / 2.0


func _mesh(shape: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = shape
    node.position = at
    node.material_override = material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    body.add_child(node)
    return node


func _surface(vertices: Array[Vector3], material: Material) -> void:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    tool.set_smooth_group(-1)
    for vertex in vertices:
        tool.add_vertex(vertex)
    tool.generate_normals()
    var surf_material := material.duplicate() as Material
    if surf_material is BaseMaterial3D:
        (surf_material as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
    _mesh(tool.commit(), Vector3.ZERO, surf_material)


func reset_flight() -> void:
    position = Vector3(0.0, 7.5, 18.0)
    velocity_xy = Vector2.ZERO
    energy = max_energy
    forward_speed = 36.0
    current_boost = false
    body.rotation = Vector3.ZERO


func set_active(enabled: bool) -> void:
    active = enabled


func _physics_process(delta: float) -> void:
    phase += delta
    if active:
        # Analog strengths from touch stick, physical controller or keyboard.
        var axis := Input.get_vector("steer_left", "steer_right", "steer_down", "steer_up", 0.07)
        var side: float = axis.x
        var pitch: float = -axis.y
        velocity_xy.x = move_toward(velocity_xy.x, side * 30.0, delta * 55.0)
        velocity_xy.y = move_toward(velocity_xy.y, pitch * 24.0, delta * 44.0)
        var wants_boost := Input.is_action_pressed("boost") and energy > 3.0
        current_boost = wants_boost
        if wants_boost:
            energy = maxf(0.0, energy - 31.0 * delta)
        else:
            energy = minf(max_energy, energy + 14.0 * delta)
        var target_speed := 64.0 if wants_boost else (19.0 if Input.is_action_pressed("brake") else 36.0)
        forward_speed = move_toward(forward_speed, target_speed, delta * 37.0)
        position += Vector3(velocity_xy.x, velocity_xy.y, -forward_speed) * delta
        position.x = clampf(position.x, -43.0, 43.0)
        position.y = clampf(position.y, -13.0, 43.0)
        body.rotation.z = lerpf(body.rotation.z, -side * 0.34, delta * 5.0)
        body.rotation.x = lerpf(body.rotation.x, pitch * 0.18, delta * 4.0)
        body.rotation.y = lerpf(body.rotation.y, -side * 0.14, delta * 3.0)
    else:
        body.position.y = sin(phase * 1.8) * 0.15
        body.rotation.z = lerpf(body.rotation.z, 0.0, delta * 1.5)
    if ion_wake != null:
        ion_wake.update_wake(delta, active, current_boost, forward_speed)
    if plume_left != null:
        plume_left.scale.z = lerpf(plume_left.scale.z, 3.3 if current_boost else 1.6, delta * 9.0)
        plume_right.scale.z = plume_left.scale.z
    var follow_pos := global_position + Vector3(-velocity_xy.x * 0.017, 3.9 - velocity_xy.y * 0.013, 10.4)
    chase_camera.global_position = chase_camera.global_position.lerp(follow_pos, minf(1.0, delta * 5.5))
    chase_camera.look_at(global_position + Vector3(0.0, 0.7, -20.0), Vector3.UP)
    chase_camera.rotate_object_local(Vector3.FORWARD, clampf(velocity_xy.x * -0.0027, -0.085, 0.085))
    chase_camera.fov = lerpf(chase_camera.fov, 82.0 if current_boost else 72.0, minf(1.0, delta * 3.5))

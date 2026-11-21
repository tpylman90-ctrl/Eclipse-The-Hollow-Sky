extends Node3D
## Procedural camera-visible energy wakes. Original geometry and original shader.
## Scales wake length with boost, avoiding expensive GPU particle systems.

const PLUME_SHADER = preload("res://shaders/thruster_plume.gdshader")

var trails: Array[MeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var phase := 0.0


func _ready() -> void:
    var shader_mat := ShaderMaterial.new()
    shader_mat.shader = PLUME_SHADER
    shader_mat.set_shader_parameter("hot_core", Color("#c6fff0"))
    shader_mat.set_shader_parameter("outer_flame", Color("#2499d0"))
    shader_mat.set_shader_parameter("brightness", 0.84)
    materials.append(shader_mat)
    for side in [-1, 1]:
        var sx: float = float(side)
        for cross in range(2):
            var plane := MeshInstance3D.new()
            plane.name = "ReactiveIonWake"
            plane.mesh = _trail_mesh(cross == 1)
            plane.position = Vector3(sx * 1.30, -0.24, 3.1)
            plane.material_override = shader_mat
            plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            add_child(plane)
            trails.append(plane)
        # Outer pods receive a smaller, distinct turquoise wake.
        var pod := MeshInstance3D.new()
        pod.name = "PodWake"
        pod.mesh = _trail_mesh(false, 0.55)
        pod.position = Vector3(sx * 2.43, -0.16, 1.76)
        pod.material_override = shader_mat
        pod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(pod)
        trails.append(pod)


func _trail_mesh(vertical: bool, width_scale: float = 1.0) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var steps := 15
    for i in range(steps):
        var a: float = float(i) / float(steps)
        var b: float = float(i + 1) / float(steps)
        var wa: float = 0.32 * width_scale * (1.0 - pow(a, 1.35) * 0.85)
        var wb: float = 0.32 * width_scale * (1.0 - pow(b, 1.35) * 0.85)
        var ao: float = sin(a * 10.5) * 0.06 * a
        var bo: float = sin(b * 10.5) * 0.06 * b
        var a1: Vector3
        var a2: Vector3
        var b1: Vector3
        var b2: Vector3
        if vertical:
            a1 = Vector3(ao, -wa, a)
            a2 = Vector3(ao, wa, a)
            b1 = Vector3(bo, -wb, b)
            b2 = Vector3(bo, wb, b)
        else:
            a1 = Vector3(-wa, ao, a)
            a2 = Vector3(wa, ao, a)
            b1 = Vector3(-wb, bo, b)
            b2 = Vector3(wb, bo, b)
        _point(st, a1, Vector2(0.0, a))
        _point(st, a2, Vector2(1.0, a))
        _point(st, b2, Vector2(1.0, b))
        _point(st, a1, Vector2(0.0, a))
        _point(st, b2, Vector2(1.0, b))
        _point(st, b1, Vector2(0.0, b))
    st.generate_normals()
    return st.commit()


func _point(st: SurfaceTool, p: Vector3, uv: Vector2) -> void:
    st.set_uv(uv)
    st.add_vertex(p)


func update_wake(delta: float, active: bool, boosting: bool, speed: float) -> void:
    phase += delta
    var intended: float = (6.3 if boosting else 3.0) if active else 1.85
    for i in range(trails.size()):
        var trail: MeshInstance3D = trails[i]
        var offset: float = 0.72 if i % 3 == 2 else 1.0
        trail.scale.z = lerpf(trail.scale.z, intended * offset, minf(1.0, delta * 9.0))
        trail.scale.x = lerpf(trail.scale.x, (1.45 if boosting else 1.0), minf(1.0, delta * 8.0))
        trail.scale.y = trail.scale.x
        trail.visible = active or speed > 0.0
    var p: float = 1.1 if boosting else 0.75
    materials[0].set_shader_parameter("brightness", p)

extends RefCounted
## Geometry factory: proper chamfered hard-surface boxes with outward-facing flat normals.
## This replaces razor-sharp primitive boxes without an imported 3D model library.

static func bevel_box(size: Vector3, bevel_size: float = 0.16) -> ArrayMesh:
    var hx: float = maxf(0.008, size.x * 0.5)
    var hy: float = maxf(0.008, size.y * 0.5)
    var hz: float = maxf(0.008, size.z * 0.5)
    var b: float = minf(bevel_size, minf(hx, minf(hy, hz)) * 0.48)
    var h := Vector3(hx, hy, hz)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.set_smooth_group(-1)
    # Six inset faces.
    for axis in range(3):
        for signum in [-1.0, 1.0]:
            var a := Vector3.ZERO
            var q := Vector3.ZERO
            var r := Vector3.ZERO
            if axis == 0:
                a = Vector3(signum * hx, -hy + b, -hz + b)
                q = Vector3(signum * hx, hy - b, -hz + b)
                r = Vector3(signum * hx, hy - b, hz - b)
                _quad(st, a, q, r, Vector3(signum * hx, -hy + b, hz - b))
            elif axis == 1:
                a = Vector3(-hx + b, signum * hy, -hz + b)
                q = Vector3(hx - b, signum * hy, -hz + b)
                r = Vector3(hx - b, signum * hy, hz - b)
                _quad(st, a, q, r, Vector3(-hx + b, signum * hy, hz - b))
            else:
                a = Vector3(-hx + b, -hy + b, signum * hz)
                q = Vector3(hx - b, -hy + b, signum * hz)
                r = Vector3(hx - b, hy - b, signum * hz)
                _quad(st, a, q, r, Vector3(-hx + b, hy - b, signum * hz))
    # 12 diagonal edge planes, four on each axis.
    for sx in [-1.0, 1.0]:
        for sy in [-1.0, 1.0]:
            _quad(st,
                Vector3(sx * hx, sy * (hy - b), -(hz - b)),
                Vector3(sx * hx, sy * (hy - b), hz - b),
                Vector3(sx * (hx - b), sy * hy, hz - b),
                Vector3(sx * (hx - b), sy * hy, -(hz - b)))
            _quad(st,
                Vector3(-(hx - b), sy * hy, sx * (hz - b)),
                Vector3(hx - b, sy * hy, sx * (hz - b)),
                Vector3(hx - b, sy * (hy - b), sx * hz),
                Vector3(-(hx - b), sy * (hy - b), sx * hz))
            _quad(st,
                Vector3(sy * hx, -(hy - b), sx * (hz - b)),
                Vector3(sy * hx, hy - b, sx * (hz - b)),
                Vector3(sy * (hx - b), hy - b, sx * hz),
                Vector3(sy * (hx - b), -(hy - b), sx * hz))
    # Eight triangular 3-way corner mitres.
    for sx in [-1.0, 1.0]:
        for sy in [-1.0, 1.0]:
            for sz in [-1.0, 1.0]:
                _tri(st,
                    Vector3(sx * hx, sy * (hy - b), sz * (hz - b)),
                    Vector3(sx * (hx - b), sy * hy, sz * (hz - b)),
                    Vector3(sx * (hx - b), sy * (hy - b), sz * hz))
    st.generate_normals()
    return st.commit()


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    _tri(st, a, b, c)
    _tri(st, a, c, d)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
    var normal := (b - a).cross(c - a)
    var centroid := (a + b + c) / 3.0
    if normal.dot(centroid) < 0.0:
        st.add_vertex(a)
        st.add_vertex(c)
        st.add_vertex(b)
    else:
        st.add_vertex(a)
        st.add_vertex(b)
        st.add_vertex(c)

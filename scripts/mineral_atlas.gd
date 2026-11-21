extends RefCounted
## Deterministic RGBA material atlas compiled on the CPU during offline stage baking.
## R = sediment, G = mineral grain, B = chips, A = microsurface irregularity.
## Replaces dozens of ALU-heavy noise/hash evaluations per fragment.
## The ImageTexture is embedded in the baked PackedScene; no paid assets.
const SIZE := 256
static var _cache: ImageTexture


static func get_atlas() -> ImageTexture:
    if _cache != null:
        return _cache
    var noise := FastNoiseLite.new()
    noise.seed = 827041
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    noise.fractal_octaves = 2
    noise.fractal_gain = 0.52
    var picture := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
    # A few controlled periodic frequencies with seamless blending at the edges.
    # All expensive detail is computed before APK export, not by GPU fragments.
    var frequencies := PackedFloat32Array([1.0, 3.0, 7.0, 15.0])
    for y in range(SIZE):
        var v: float = float(y) / float(SIZE - 1)
        for x in range(SIZE):
            var u: float = float(x) / float(SIZE - 1)
            var rgba := Color(0.0, 0.0, 0.0, 1.0)
            for channel in range(4):
                var f: float = frequencies[channel]
                # Tileable noise: blend four opposite samples so both edges match.
                var ox: float = u * 61.0 * f
                var oy: float = v * 61.0 * f
                var period: float = 61.0 * f
                var a: float = noise.get_noise_2d(ox, oy)
                var b: float = noise.get_noise_2d(ox - period, oy)
                var c: float = noise.get_noise_2d(ox, oy - period)
                var d: float = noise.get_noise_2d(ox - period, oy - period)
                var nx: float = lerpf(a, b, u)
                var ny: float = lerpf(c, d, u)
                var amount: float = clampf(lerpf(nx, ny, v) * 0.5 + 0.5, 0.0, 1.0)
                match channel:
                    0:
                        rgba.r = amount
                    1:
                        rgba.g = amount
                    2:
                        rgba.b = amount
                    3:
                        rgba.a = amount
            picture.set_pixel(x, y, rgba)
    picture.generate_mipmaps()
    _cache = ImageTexture.create_from_image(picture)
    return _cache

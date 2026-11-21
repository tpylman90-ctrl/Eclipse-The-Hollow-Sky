shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

// ECLIPSE Ultra: brush-anisotropy impression, metal grain, microchips, clearcoat.
// Geometry remains original. Detail lives in the material rather than texture imports.
uniform vec4 paint_color : source_color = vec4(0.39, 0.50, 0.55, 1.0);
uniform vec4 exposed_metal : source_color = vec4(0.74, 0.80, 0.79, 1.0);
uniform float metalness : hint_range(0.0, 1.0) = 0.75;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.25;
uniform float wear : hint_range(0.0, 1.0) = 0.23;
uniform float scratch_density : hint_range(0.1, 10.0) = 1.0;

varying vec3 p_local;
varying vec3 n_local;

float hash(vec3 p) {
    return fract(sin(dot(p,vec3(19.27,87.31,112.41))) * 43758.5453);
}
float n3(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(
        mix(mix(hash(i),hash(i+vec3(1.,0.,0.)),f.x),
            mix(hash(i+vec3(0.,1.,0.)),hash(i+vec3(1.,1.,0.)),f.x),f.y),
        mix(mix(hash(i+vec3(0.,0.,1.)),hash(i+vec3(1.,0.,1.)),f.x),
            mix(hash(i+vec3(0.,1.,1.)),hash(i+vec3(1.,1.,1.)),f.x),f.y),
        f.z);
}
void vertex() {
    p_local = VERTEX;
    n_local = NORMAL;
}
void fragment() {
    vec3 p = p_local;
    float large = n3(p * 2.3);
    float pores = n3(p * 24.0);
    float pixels = n3(p * 83.0);
    // High-frequency directional brush grain and scattered paint chips.
    float linear = abs(sin(p.z * 182.0 * scratch_density + large * 3.0 + p.x * 47.0));
    float brush = pow(linear, 14.0) * 0.105;
    float chips = smoothstep(0.72, 0.94, pores * 0.8 + pixels * 0.2 + (1.0-large)*0.08);
    float worn = clamp(chips * wear * 0.85 + brush * wear * 0.16, 0.0, 0.4);
    vec3 paint = paint_color.rgb * mix(0.86, 1.13, large);
    paint *= 0.975 + pixels * 0.045;
    ALBEDO = mix(paint, exposed_metal.rgb, worn);
    METALLIC = metalness;
    ROUGHNESS = clamp(roughness_base + (0.5-pores) * 0.14 + brush * 0.42, 0.07, 0.85);
    AO = 0.94 + pores * 0.06;
    SPECULAR = 0.68;
}

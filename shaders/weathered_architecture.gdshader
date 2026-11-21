shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Engineered stone and bronze with CPU-prebaked periodic grain, mineral pitting,
// etched seams and surface wear, 3 triplanar taps instead of many runtime hashes.
uniform vec4 base_tint : source_color = vec4(0.39, 0.51, 0.53, 1.0);
uniform vec4 vein_tint : source_color = vec4(0.13, 0.22, 0.29, 1.0);
uniform vec4 polished_edge_tint : source_color = vec4(0.72, 0.78, 0.73, 1.0);
uniform sampler2D mineral_atlas : repeat_enable, filter_linear_mipmap;
uniform float metalness : hint_range(0.0, 1.0) = 0.08;
uniform float weathering : hint_range(0.0, 1.0) = 0.5;
uniform float roughness_level : hint_range(0.0, 1.0) = 0.72;
uniform float map_scale : hint_range(0.01, 10.0) = 0.45;
varying vec3 p_world;
varying vec3 n_world;

void vertex() {
    p_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    n_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
    vec3 normal = normalize(n_world);
    vec3 axis = pow(abs(normal), vec3(4.0));
    axis /= max(axis.x + axis.y + axis.z, 0.001);
    vec3 uv_pos = p_world * map_scale * 0.050;
    vec4 packed = texture(mineral_atlas, uv_pos.yz) * axis.x
                + texture(mineral_atlas, uv_pos.xz) * axis.y
                + texture(mineral_atlas, uv_pos.xy) * axis.z;
    float large = packed.r;
    float medium = packed.g;
    float small = packed.b;
    float grit = packed.a;
    float fbm = large * 0.47 + medium * 0.29 + small * 0.16 + grit * 0.08;
    float pores = smoothstep(0.45, 0.92, small * 0.75 + grit * 0.42);
    float groove = 1.0 - smoothstep(0.0, 0.043,
        abs(sin(p_world.y * 5.2 + large * 7.0 + p_world.x * 0.47)));
    float etched = mix(0.24, 1.0, axis.y) * groove * 0.16;
    float crack = smoothstep(0.48, 0.72, medium - large * 0.16) * (0.13 + etched);
    float erosion = (1.0 - fbm) * (1.0 - fbm) * weathering * 0.23;
    vec3 color = base_tint.rgb * mix(0.70, 1.21, fbm);
    color = mix(color, vein_tint.rgb, clamp(crack * weathering + etched + erosion, 0.0, 0.48));
    float gleam = smoothstep(0.67, 0.94, large * 0.61 + small * 0.39) * 0.16;
    color = mix(color, polished_edge_tint.rgb, gleam);
    color *= 1.0 - pores * 0.10 * weathering;
    ALBEDO = color;
    ROUGHNESS = clamp(roughness_level + (0.5 - fbm) * 0.26 + pores * 0.07, 0.16, 1.0);
    METALLIC = metalness;
    AO = clamp(1.0 - crack * 0.25 - pores * 0.12, 0.65, 1.0);
    SPECULAR = 0.45;
}

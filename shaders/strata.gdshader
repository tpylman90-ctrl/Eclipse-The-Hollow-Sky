shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// V0.7: CPU-baked, tileable channel-packed mineral data sampled triplanar.
// The original shader ran 32+ sine/hash lattice evaluations for each fragment.
// Four levels of noise now arrive from 3 sampled texels.
uniform vec4 stone_tint : source_color = vec4(0.23, 0.32, 0.40, 1.0);
uniform vec4 mineral_tint : source_color = vec4(0.42, 0.49, 0.52, 1.0);
uniform sampler2D mineral_atlas : repeat_enable, filter_linear_mipmap;
uniform float stratum_frequency : hint_range(0.05, 3.0) = 0.6;
uniform float relief : hint_range(0.0, 1.0) = 0.45;

varying vec3 p_world;
varying vec3 n_world;

void vertex() {
    p_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    n_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
    vec3 normal = normalize(n_world);
    vec3 weighting = pow(abs(normal), vec3(4.0));
    weighting /= max(weighting.x + weighting.y + weighting.z, 0.001);
    vec3 p = p_world * 0.025;
    vec4 grain = texture(mineral_atlas, p.yz) * weighting.x
              + texture(mineral_atlas, p.xz) * weighting.y
              + texture(mineral_atlas, p.xy) * weighting.z;
    float slow = grain.r;
    float ridge = grain.g;
    float chips = grain.b;
    float grit = grain.a;
    float fbm = slow * 0.49 + ridge * 0.27 + chips * 0.16 + grit * 0.08;
    float bedding = smoothstep(-0.62, 0.70,
        sin(p_world.y * stratum_frequency * 0.63 + slow * 5.0 + ridge * 1.5)) * 0.22;
    float fracture = 1.0 - smoothstep(0.015, 0.11, abs(ridge - chips * 0.85 - 0.08));
    fracture *= clamp((1.0 - abs(normal.y)) * 0.72 + 0.31, 0.0, 1.0);
    float mineral = smoothstep(0.55, 0.83, slow * 0.55 + ridge * 0.31 + chips * 0.2);
    float eroded = smoothstep(0.43, 0.83, chips * 0.69 + grit * 0.31);
    float recess = clamp(fracture * 0.27 + eroded * 0.09, 0.0, 0.33);
    float tonal = 0.64 + fbm * 0.70 + bedding * relief;
    vec3 col = stone_tint.rgb * tonal;
    col = mix(col, mineral_tint.rgb, mineral * (0.21 + relief * 0.24));
    col *= 1.0 - recess * 0.73;
    col = mix(col, col * 1.16, clamp(normal.y * 0.36, 0.0, 0.36));
    ALBEDO = col * mix(vec3(1.0), COLOR.rgb * 1.17, 0.14);
    ROUGHNESS = clamp(0.84 + (grit - fbm) * 0.25, 0.67, 0.98);
    METALLIC = 0.04;
    AO = 1.0 - recess * 0.41;
    SPECULAR = 0.27;
}

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Ultra geological material: broad sediment plates, fractured shelves,
// mineral veins and fine pitting. World anchored: no repeated UV tiling.
uniform vec4 stone_tint : source_color = vec4(0.23, 0.32, 0.40, 1.0);
uniform vec4 mineral_tint : source_color = vec4(0.42, 0.49, 0.52, 1.0);
uniform float stratum_frequency : hint_range(0.05, 3.0) = 0.6;
uniform float relief : hint_range(0.0, 1.0) = 0.45;

varying vec3 p_world;
varying vec3 n_world;

float hash31(vec3 p) {
    return fract(sin(dot(p, vec3(17.17, 53.23, 87.13))) * 43758.5453);
}
float value_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f*f*(3.0-2.0*f);
    float n00 = mix(hash31(i), hash31(i+vec3(1.0,0.0,0.0)),f.x);
    float n10 = mix(hash31(i+vec3(0.0,1.0,0.0)),hash31(i+vec3(1.0,1.0,0.0)),f.x);
    float n01 = mix(hash31(i+vec3(0.0,0.0,1.0)),hash31(i+vec3(1.0,0.0,1.0)),f.x);
    float n11 = mix(hash31(i+vec3(0.0,1.0,1.0)),hash31(i+vec3(1.0,1.0,1.0)),f.x);
    return mix(mix(n00,n10,f.y),mix(n01,n11,f.y),f.z);
}
void vertex() {
    p_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    n_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
    vec3 p = p_world * 0.19;
    float slow = value_noise(p * 0.54);
    float ridge = value_noise(p * 1.95);
    float chips = value_noise(p * 6.6);
    float grit = value_noise(p * 23.4);
    float fbm = slow * 0.49 + ridge * 0.27 + chips * 0.16 + grit * 0.08;

    // Broad, broken bedding planes instead of regular high-contrast stripes.
    float strata = sin(p_world.y * stratum_frequency * 0.63 + slow * 5.0 + ridge * 1.5);
    float bedding = smoothstep(-0.62, 0.70, strata) * 0.22;
    float fracture = 1.0 - smoothstep(0.015, 0.11, abs(ridge - chips * 0.85 - 0.08));
    fracture *= clamp((1.0 - abs(n_world.y)) * 0.72 + 0.31, 0.0, 1.0);
    float mineral = smoothstep(0.55, 0.83, slow * 0.55 + ridge * 0.31 + chips * 0.2);
    float eroded = smoothstep(0.43, 0.83, chips * 0.69 + grit * 0.31);
    float recess = clamp(fracture * 0.27 + eroded * 0.09, 0.0, 0.33);
    float tonal = 0.64 + fbm * 0.70 + bedding * relief;
    vec3 col = stone_tint.rgb * tonal;
    col = mix(col, mineral_tint.rgb, mineral * (0.21 + relief * 0.24));
    col *= 1.0 - recess * 0.73;
    // Top shelves receive chalk weathering and shadows remain darker.
    col = mix(col, col * 1.16, clamp(n_world.y * 0.36,0.0,0.36));
    ALBEDO = col * mix(vec3(1.0), COLOR.rgb * 1.17, 0.14);
    ROUGHNESS = clamp(0.84 + (grit - fbm) * 0.25, 0.67, 0.98);
    METALLIC = 0.04;
    AO = 1.0 - recess * 0.41;
    SPECULAR = 0.27;
}

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Original tile-free procedural sandstone: world-space strata, chips and mineral flecks.
// No texture downloads, texture UVs or proprietary assets.
uniform vec4 stone_tint : source_color = vec4(0.23, 0.32, 0.40, 1.0);
uniform vec4 mineral_tint : source_color = vec4(0.42, 0.49, 0.52, 1.0);
uniform float stratum_frequency : hint_range(0.05, 3.0) = 0.6;
uniform float relief : hint_range(0.0, 1.0) = 0.45;

varying vec3 world_pos;

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
    world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
    vec3 p = world_pos * 0.32;
    float coarse = value_noise(p * 0.62);
    float medium = value_noise(p * 2.4);
    float fine = value_noise(p * 7.1);
    float strata = sin(world_pos.y * stratum_frequency * 6.2831853 + coarse * 2.3 + medium * 0.48);
    float layer = smoothstep(-0.44, 0.58, strata);
    float mineral = smoothstep(0.57,0.82,coarse * 0.50 + medium * 0.45 + fine * 0.18);
    vec3 base = mix(stone_tint.rgb * 0.67, stone_tint.rgb * 1.25, layer * relief + 0.32);
    base = mix(base, mineral_tint.rgb, mineral * 0.34);
    base *= mix(0.76,1.17,medium * 0.6 + fine * 0.4);
    ALBEDO = base * mix(vec3(1.0), COLOR.rgb * 1.32, 0.31);
    ROUGHNESS = 0.84;
    METALLIC = 0.03;
}

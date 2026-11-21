shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// World-space weathering, engraved sandstone grain and fine bevel wear.
// PBR roughness and metallic responses, no external texture assets.
uniform vec4 base_tint : source_color = vec4(0.39, 0.51, 0.53, 1.0);
uniform vec4 vein_tint : source_color = vec4(0.13, 0.22, 0.29, 1.0);
uniform vec4 polished_edge_tint : source_color = vec4(0.72, 0.78, 0.73, 1.0);
uniform float metalness : hint_range(0.0, 1.0) = 0.08;
uniform float weathering : hint_range(0.0, 1.0) = 0.5;
uniform float roughness_level : hint_range(0.0, 1.0) = 0.72;
uniform float map_scale : hint_range(0.01, 10.0) = 0.45;

varying vec3 p_world;
varying vec3 v_world_normal;

float h31(vec3 p) {
    return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}
float n31(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0*f);
    float a = mix(h31(i),h31(i+vec3(1.,0.,0.)),f.x);
    float b = mix(h31(i+vec3(0.,1.,0.)),h31(i+vec3(1.,1.,0.)),f.x);
    float c = mix(h31(i+vec3(0.,0.,1.)),h31(i+vec3(1.,0.,1.)),f.x);
    float d = mix(h31(i+vec3(0.,1.,1.)),h31(i+vec3(1.,1.,1.)),f.x);
    return mix(mix(a,b,f.y),mix(c,d,f.y),f.z);
}
void vertex() {
    p_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
    vec3 p = p_world * map_scale;
    vec3 n = normalize(v_world_normal);
    float large = n31(p * 0.64);
    float medium = n31(p * 2.42);
    float small = n31(p * 7.4);
    float grit = n31(p * 17.8);
    float fbm = large * 0.47 + medium * 0.29 + small * 0.16 + grit * 0.08;

    vec3 axis = abs(n);
    axis = pow(axis, vec3(3.0));
    axis /= max(dot(axis, vec3(1.0)), 0.001);
    float bedding = sin(p_world.y * 4.17 + large * 7.0 + medium * 2.3);
    float pores = smoothstep(0.45, 0.92, small * 0.75 + grit * 0.42);
    float hairline = 1.0 - smoothstep(0.0, 0.043, abs(sin(p_world.y * 5.2 + large * 7.0 + p_world.x * 0.47)) );
    float grooves = mix(0.24, 1.0, axis.y) * hairline * 0.16;
    float crack = smoothstep(0.48, 0.72, medium - large * 0.16) * (0.13 + grooves);
    float erosion = pow(1.0 - fbm, 2.4) * weathering * 0.23;
    vec3 color = base_tint.rgb * mix(0.70,1.21,fbm);
    color = mix(color, vein_tint.rgb, clamp(crack * weathering + grooves + erosion, 0.0, 0.48));
    float gleam = smoothstep(0.67,0.94,large * 0.61 + small * 0.39) * 0.16;
    color = mix(color, polished_edge_tint.rgb, gleam);
    color *= 1.0 - pores * 0.10 * weathering;

    ALBEDO = color;
    ROUGHNESS = clamp(roughness_level + (0.5 - fbm) * 0.26 + pores * 0.07,0.16,1.0);
    METALLIC = metalness;
    AO = clamp(1.0 - crack * 0.25 - pores * 0.12, 0.65, 1.0);
    SPECULAR = 0.45;
}

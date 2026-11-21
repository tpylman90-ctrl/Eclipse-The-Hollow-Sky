shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

// Two low-cost noise octaves on a single large transparent plane.
uniform vec4 cloud_blue : source_color = vec4(0.20, 0.33, 0.49, 1.0);
uniform vec4 cloud_peach : source_color = vec4(0.54, 0.34, 0.39, 1.0);
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.63;

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(42.53, 83.29))) * 9631.239);
}
float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i),hash2(i+vec2(1.0,0.0)),f.x),
               mix(hash2(i+vec2(0.0,1.0)),hash2(i+vec2(1.0,1.0)),f.x),f.y);
}
void fragment() {
    vec2 p = UV * vec2(13.0, 20.0);
    float large = noise2(p * 0.64 + vec2(TIME * 0.006, 0.0));
    float detail = noise2(p * 1.83 + vec2(-TIME * 0.014, TIME * 0.011));
    float density = large * 0.68 + detail * 0.32;
    float crest = smoothstep(0.32, 0.68, density);
    ALBEDO = mix(cloud_blue.rgb, cloud_peach.rgb, clamp(large * 0.53 + UV.y * 0.4, 0.0, 1.0));
    EMISSION = ALBEDO * 0.08;
    ALPHA = crest * cloud_opacity;
}

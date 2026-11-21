shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

// Two animated samples from the offline-produced texture atlas replace
// expensive procedural lattice noise for every cloud-covered screen pixel.
uniform vec4 cloud_blue : source_color = vec4(0.20, 0.33, 0.49, 1.0);
uniform vec4 cloud_peach : source_color = vec4(0.54, 0.34, 0.39, 1.0);
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.63;
uniform sampler2D noise_atlas : repeat_enable, filter_linear_mipmap;

void fragment() {
    vec2 p = UV * vec2(13.0, 20.0);
    float large = texture(noise_atlas, p * 0.64 + vec2(TIME * 0.006, 0.0)).r;
    float detail = texture(noise_atlas, p * 1.83 + vec2(-TIME * 0.014, TIME * 0.011)).g;
    float density = large * 0.68 + detail * 0.32;
    float crest = smoothstep(0.32, 0.68, density);
    ALBEDO = mix(cloud_blue.rgb, cloud_peach.rgb, clamp(large * 0.53 + UV.y * 0.4, 0.0, 1.0));
    EMISSION = ALBEDO * 0.08;
    ALPHA = crest * cloud_opacity;
}

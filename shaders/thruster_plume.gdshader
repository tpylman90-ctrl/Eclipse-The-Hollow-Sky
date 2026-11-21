shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 hot_core : source_color = vec4(0.63, 1.0, 0.95, 1.0);
uniform vec4 outer_flame : source_color = vec4(0.10, 0.57, 0.95, 1.0);
uniform float brightness : hint_range(0.0, 2.0) = 1.0;

float hash21(vec2 v) {
    return fract(sin(dot(v, vec2(12.98, 78.23))) * 43758.55);
}

void fragment() {
    vec2 p = UV;
    float center = 1.0 - abs(p.x * 2.0 - 1.0);
    float fade = (1.0 - smoothstep(0.32, 0.99, p.y));
    float jet = 0.74 + 0.26 * sin(p.y * 34.0 - TIME * 32.0 + p.x * 17.0);
    float turbulence = hash21(floor(vec2(p.x * 13.0, p.y * 38.0 - TIME * 20.0)));
    ALBEDO = mix(outer_flame.rgb, hot_core.rgb, center * 0.75);
    EMISSION = ALBEDO * (1.5 + center * 1.4);
    ALPHA = clamp(brightness * fade * (0.42 + center * 0.48) * (jet * 0.82 + turbulence * 0.18), 0.0, 0.85);
}

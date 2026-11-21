shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

// Transparent, animated aether streams, no texture atlas or imported particle textures.
uniform vec4 core_tint : source_color = vec4(0.22, 0.83, 0.87, 1.0);
uniform vec4 rim_tint : source_color = vec4(0.70, 0.98, 0.94, 1.0);
uniform float strength : hint_range(0.0, 3.0) = 1.0;
uniform float flow_rate : hint_range(0.0, 6.0) = 1.2;
uniform float ribbon_seed = 0.0;

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
        mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y
    );
}

void fragment() {
    vec2 p = UV;
    float scroll = p.y * 11.0 + TIME * flow_rate + ribbon_seed * 4.3;
    float warped = p.x + (noise2(vec2(scroll * 0.34, ribbon_seed)) - 0.5) * 0.23;
    float edge = pow(max(0.0, 1.0 - abs(warped * 2.0 - 1.0)), 2.5);
    float filaments = 0.51 + 0.49 * sin(warped * 47.0 + scroll * 3.1);
    float drops = smoothstep(0.15, 0.89, noise2(vec2(warped * 13.0, scroll * 1.9)));
    float tip = smoothstep(0.01, 0.15, p.y) * (1.0 - smoothstep(0.76, 1.0, p.y));
    float alpha = edge * tip * (0.24 + filaments * 0.29 + drops * 0.34) * strength;
    ALBEDO = mix(core_tint.rgb, rim_tint.rgb, filaments * 0.34 + drops * 0.16);
    EMISSION = ALBEDO * (0.6 + filaments * 0.4);
    ALPHA = clamp(alpha, 0.0, 0.85);
}

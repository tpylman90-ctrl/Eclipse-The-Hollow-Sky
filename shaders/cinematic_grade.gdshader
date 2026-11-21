shader_type canvas_item;
render_mode unshaded;

// A restrained cinematic lens treatment (no post-process dependency).
uniform float corner_strength : hint_range(0.0, 1.0) = 0.35;
uniform float grain_strength : hint_range(0.0, 0.06) = 0.012;

float rand(vec2 v) {
    // Integer-ish arithmetic noise; avoids a transcendental sine for
    // every full-resolution film-grain fragment on Android.
    vec3 p = fract(vec3(v.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yzx + 19.19);
    return fract((p.x + p.y) * p.z);
}

void fragment() {
    vec2 centered = UV * 2.0 - vec2(1.0);
    float radial = length(centered * vec2(0.90, 1.06));
    float shadow = smoothstep(0.44, 1.38, radial);
    float grain = rand(floor(SCREEN_UV * vec2(1360.0, 740.0)));
    float edge = shadow * corner_strength;
    float noise_luma = (grain - 0.5) * grain_strength;
    COLOR = vec4(vec3(0.012, 0.021, 0.038) + noise_luma, clamp(edge + abs(noise_luma), 0.0, 0.6));
}

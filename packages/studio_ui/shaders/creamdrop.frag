#version 460 core
#include <flutter/runtime_effect.glsl>

uniform float uResolutionX;  // 0
uniform float uResolutionY;  // 1
uniform float uTime;         // 2
uniform float uBass;         // 3
uniform float uMid;          // 4
uniform float uTreble;       // 5
uniform float uBeat;         // 6
uniform float uColorSeed;    // 7
uniform float uSelected;     // 8
uniform float uProgress;     // 9

out vec4 fragColor;

// ── Simplex 2D noise (Ashima Arts) ──

vec3 mod289v3(vec3 x) { return x - floor(x / 289.0) * 289.0; }
vec2 mod289v2(vec2 x) { return x - floor(x / 289.0) * 289.0; }
vec3 permute(vec3 x) { return mod289v3(((x * 34.0) + 1.0) * x); }

float snoise(vec2 v) {
    const vec4 C = vec4(
        0.211324865405187,   // (3.0 - sqrt(3.0)) / 6.0
        0.366025403784439,   // 0.5 * (sqrt(3.0) - 1.0)
       -0.577350269189626,   // -1.0 + 2.0 * C.x
        0.024390243902439    // 1.0 / 41.0
    );
    vec2 i = floor(v + dot(v, C.yy));
    vec2 x0 = v - i + dot(i, C.xx);
    vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod289v2(i);
    vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
    vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m = m * m;
    m = m * m;
    vec3 x_ = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x_) - 0.5;
    vec3 ox = floor(x_ + 0.5);
    vec3 a0 = x_ - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
    vec3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

// ── Fractal Brownian Motion ──

float fbm(vec2 p) {
    float value = 0.0;
    float amp = 0.5;
    vec2 shift = vec2(100.0);
    for (int i = 0; i < 5; i++) {
        value += amp * snoise(p);
        p = p * 2.0 + shift;
        amp *= 0.5;
    }
    return value;
}

// ── Cosine palette ──

vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
    return a + b * cos(6.28318 * (c * t + d));
}

void main() {
    vec2 res = vec2(uResolutionX, uResolutionY);
    vec2 uv = FlutterFragCoord().xy / res;
    vec2 p = (uv - 0.5) * 2.0;
    p.x *= res.x / res.y;

    // Time with non-integer multiplier to avoid obvious 2s loop
    float t = uTime * 6.28318 * 1.618;

    // Polar coordinates for symmetry
    float angle = atan(p.y, p.x);
    float radius = length(p);

    // Dynamic symmetry fold (8-fold base, treble adds more)
    float sym = 8.0 + uTreble * 4.0;
    float sector = 6.28318 / sym;
    angle = mod(angle + 3.14159, sector) - sector * 0.5;
    vec2 sp = vec2(cos(angle), sin(angle)) * radius;

    // Domain warping — bass drives warp intensity
    float warp = 0.4 + uBass * 0.8 + uBeat * 0.3;

    vec2 q = vec2(
        fbm(sp * 1.8 + t * 0.12),
        fbm(sp * 1.8 + vec2(5.2, 1.3) + t * 0.10)
    );

    vec2 r = vec2(
        fbm(sp * 1.8 + warp * q + vec2(1.7, 9.2) + t * 0.06),
        fbm(sp * 1.8 + warp * q + vec2(8.3, 2.8) + t * 0.05)
    );

    // Field value from warped noise
    float f = length(r);
    float f2 = dot(r, q);

    // Color via cosine palette — hue shifted by colorSeed
    float hueBase = uColorSeed / 360.0;
    vec3 col = palette(
        hueBase + f * 0.35 + f2 * 0.15 + t * 0.008,
        vec3(0.5, 0.5, 0.5),
        vec3(0.5, 0.5, 0.5),
        vec3(1.0, 0.7, 0.4),
        vec3(hueBase, hueBase + 0.15, hueBase + 0.30)
    );

    // Brightness from field + audio
    float brightness = 0.15 + f * 0.55 + uBass * 0.15 + uBeat * 0.20;
    brightness += uSelected * 0.08;
    col *= brightness;

    // Vignette
    float vig = 1.0 - radius * 0.3;
    col *= clamp(vig, 0.2, 1.0);

    // Beat flash (white strobe on hard hits)
    float flash = max(0.0, uBeat - 0.3) * 0.25;
    col += vec3(flash);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

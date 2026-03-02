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
        0.211324865405187,
        0.366025403784439,
       -0.577350269189626,
        0.024390243902439
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

// ── FBM with 4 octaves ──

float fbm4(vec2 p) {
    float value = 0.0;
    float amp = 0.5;
    vec2 shift = vec2(100.0);
    for (int i = 0; i < 4; i++) {
        value += amp * snoise(p);
        p = p * 2.0 + shift;
        amp *= 0.5;
    }
    return value;
}

// ── HSV to RGB ──

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
    vec2 res = vec2(uResolutionX, uResolutionY);
    vec2 uv = FlutterFragCoord().xy / res;
    vec2 p = (uv - 0.5) * 2.0;
    p.x *= res.x / res.y;

    float t = uTime * 6.28318 * 1.618;
    float hueBase = uColorSeed / 360.0;

    // ── Fluid distortion field ──
    vec2 warp = vec2(
        snoise(p * 1.5 + t * 0.15) * (0.3 + uBeat * 0.5),
        snoise(p * 1.5 + vec2(5.0, 3.0) + t * 0.12) * (0.3 + uBeat * 0.5)
    );
    vec2 wp = p + warp;

    // ── Independent RGB noise channels driven by frequency bands ──
    // Bass → red channel, Mid → green channel, Treble → blue channel
    float rNoise = fbm4(wp * 2.0 + vec2(t * 0.18, 0.0));
    float gNoise = fbm4(wp * 2.3 + vec2(0.0, t * 0.15));
    float bNoise = fbm4(wp * 2.6 + vec2(t * 0.12, t * 0.10));

    // Second warp layer for depth
    vec2 warp2 = vec2(
        snoise(wp * 2.0 + t * 0.08) * (0.2 + uBass * 0.3),
        snoise(wp * 2.0 + vec2(7.0, 2.0) + t * 0.06) * (0.2 + uMid * 0.3)
    );
    float rNoise2 = fbm4((wp + warp2) * 1.8);
    float gNoise2 = fbm4((wp + warp2 * 1.1) * 2.1);
    float bNoise2 = fbm4((wp + warp2 * 0.9) * 2.4);

    // Mix layers
    float rVal = mix(rNoise, rNoise2, 0.5) * (0.3 + uBass * 0.7);
    float gVal = mix(gNoise, gNoise2, 0.5) * (0.3 + uMid * 0.7);
    float bVal = mix(bNoise, bNoise2, 0.5) * (0.3 + uTreble * 0.7);

    // ── Color composition ──
    // Shift hue space by colorSeed — rotate the RGB contribution angles
    float hs = hueBase * 6.28318;
    vec3 col;
    col.r = rVal * (0.5 + 0.5 * cos(hs)) + gVal * (0.5 + 0.5 * cos(hs + 2.094)) + bVal * (0.5 + 0.5 * cos(hs + 4.189));
    col.g = rVal * (0.5 + 0.5 * cos(hs + 2.094)) + gVal * (0.5 + 0.5 * cos(hs + 4.189)) + bVal * (0.5 + 0.5 * cos(hs));
    col.b = rVal * (0.5 + 0.5 * cos(hs + 4.189)) + gVal * (0.5 + 0.5 * cos(hs)) + bVal * (0.5 + 0.5 * cos(hs + 2.094));

    // Boost saturation and contrast
    col = pow(abs(col), vec3(0.75));
    col *= (0.6 + uBeat * 0.4 + uSelected * 0.08);

    // ── Radial energy burst ──
    float r = length(p);
    float burstAngle = atan(p.y, p.x);
    float burst = snoise(vec2(burstAngle * 4.0 + t * 0.5, r * 2.0 - t * 0.8));
    burst = max(0.0, burst) * exp(-r * 0.8) * (0.3 + uBeat * 0.6);
    vec3 burstCol = hsv2rgb(vec3(hueBase + 0.1, 0.9, 0.7));
    col += burst * burstCol;

    // ── Center hotspot ──
    float hotspot = exp(-r * r * (4.0 - uBeat * 2.0)) * (0.15 + uBeat * 0.35);
    col += hotspot * vec3(0.8, 0.7, 0.9);

    // Vignette
    float vig = 1.0 - r * 0.25;
    col *= clamp(vig, 0.15, 1.0);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

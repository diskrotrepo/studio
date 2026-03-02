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
    float r = length(p);
    float a = atan(p.y, p.x);
    float hue = uColorSeed / 360.0;

    // Dark background
    vec3 col = vec3(0.02, 0.02, 0.04);

    // ── Concentric rings with noise displacement ──
    float ringSpacing = 0.18 + uBass * 0.06;
    float ringWidth = 0.015 + uBeat * 0.012;
    float totalRings = 0.0;

    for (int i = 0; i < 10; i++) {
        float fi = float(i);
        float targetR = (fi + 1.0) * ringSpacing;
        // Each ring wobbles differently
        float noiseDisp = snoise(vec2(a * 3.0 + fi * 1.7, t * 0.4 + fi * 0.5)) * 0.06 * (1.0 + uMid * 0.8);
        float d = abs(r - targetR - noiseDisp);
        float ring = smoothstep(ringWidth, 0.0, d);
        // Fade outer rings
        ring *= max(0.0, 1.0 - fi * 0.08);
        // Hue shift per ring
        float ringHue = hue + fi * 0.06 + t * 0.01;
        float ringVal = 0.6 + uBeat * 0.3 + uSelected * 0.08;
        col += ring * hsv2rgb(vec3(ringHue, 0.85, ringVal));
        totalRings += ring;
    }

    // ── Radial petals via angular repetition ──
    float petalCount = 24.0 + uTreble * 16.0;
    float petals = sin(a * petalCount + t * 1.5) * 0.5 + 0.5;
    petals *= smoothstep(0.08, 0.4, r);  // Fade near center
    petals *= smoothstep(2.0, 1.2, r);   // Fade at edges
    // Petal noise modulation
    float petalNoise = snoise(vec2(a * 5.0, r * 4.0 + t * 0.3)) * 0.3 + 0.7;
    petals *= petalNoise;

    vec3 petalCol = hsv2rgb(vec3(hue + 0.45, 0.7, 0.45 + uSelected * 0.05));
    col += petals * petalCol * (0.3 + uBeat * 0.4);

    // ── Center glow ──
    float glowSize = 2.5 - uBeat * 1.2;
    float glow = exp(-r * r * glowSize) * (0.25 + uBeat * 0.5);
    vec3 glowCol = hsv2rgb(vec3(hue + 0.02, 0.9, 0.55 + uBeat * 0.3 + uSelected * 0.08));
    col += glow * glowCol;

    // ── Outer aura (noise-based) ──
    float aura = snoise(vec2(a * 2.0 + t * 0.2, r * 3.0 - t * 0.15));
    aura = smoothstep(0.2, 0.8, aura) * smoothstep(0.5, 1.5, r) * smoothstep(2.5, 1.8, r);
    vec3 auraCol = hsv2rgb(vec3(hue + 0.30, 0.6, 0.3));
    col += aura * auraCol * (0.15 + uBass * 0.2);

    // ── Beat pulse ring ──
    float pulseR = 0.3 + uBeat * 0.8;
    float pulseDist = abs(r - pulseR);
    float pulseRing = smoothstep(0.04, 0.0, pulseDist) * uBeat;
    col += pulseRing * hsv2rgb(vec3(hue, 0.95, 0.8));

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

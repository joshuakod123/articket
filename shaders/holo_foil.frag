#version 460 core
#include <flutter/runtime_effect.glsl>

// 회절 포일(diffraction foil).
//
// 기존 HoloOverlay 는 4-stop LinearGradient 의 begin/end 를 밀어 흉내냈습니다.
// 그건 색 띠가 "평행이동"할 뿐이라, 기울여도 같은 무지개가 옆으로 미끄러집니다.
//
// 실제 포일은 표면의 미세한 격자가 빛을 파장별로 다른 각도로 꺾어 보냅니다.
// 그래서 각도가 바뀌면 색이 이동하는 게 아니라 **순서가 뒤집히고 간격이
// 좁아졌다 넓어집니다.** 그건 그라디언트로 표현할 수 없고, 여기가 셰이더가
// 정답인 몇 안 되는 자리입니다.
//
// uniform 은 선언 순서대로 인덱스가 매겨집니다. Dart 쪽과 순서를 맞추세요.
//   0,1 = uSize    2 = uTilt    3 = uStrength    4 = uSeed

uniform vec2  uSize;      // 그리는 영역의 픽셀 크기
uniform float uTilt;      // 기울기 -1.0 ~ 1.0 (자이로)
uniform float uStrength;  // 세기 0.0 ~ 1.0
uniform float uSeed;      // 티켓마다 다른 표면 무늬

out vec4 fragColor;

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7)) + uSeed) * 43758.5453);
}

// 값 노이즈. 포일 표면의 미세한 요철.
float valueNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 centered = uv - 0.5;

  // 1) 보는 각도가 흐르는 축. 살짝 기울인 대각선.
  float axis = dot(centered, normalize(vec2(1.0, 0.85)));

  // 2) 표면 요철. 이것 때문에 색 띠가 곧게 뻗지 않고 일렁입니다.
  //    세로로 길게 늘여, 압인된 포일의 결처럼 보이게 합니다.
  float ripple = valueNoise(uv * vec2(6.0, 24.0)) - 0.5;

  // 3) 광로차. 기울기가 위상을 밀면서 동시에 스펙트럼 간격을 바꿉니다.
  //    이 두 번째 항이 "색 순서가 뒤집히는" 느낌을 만듭니다.
  float spread = 5.2 + uTilt * 2.6;
  float phase  = axis * spread + uTilt * 1.9 + ripple * 0.55;

  // 4) 파장별 위상차 → 무지개.
  vec3 spectral = 0.5 + 0.5 * cos(6.2831853 * (phase + vec3(0.0, 0.33, 0.67)));

  // 5) 정반사 하이라이트. 각도가 맞는 좁은 띠에서만 확 밝아집니다.
  //    포일이 "번쩍" 하는 건 대부분 이 항입니다.
  float glintAxis = axis * 2.6 - uTilt * 1.5;
  float glint = exp(-glintAxis * glintAxis * 2.2);

  // 6) 가장자리로 갈수록 약해집니다. 평면 전체가 균일하게 빛나면 스티커처럼 보입니다.
  float vignette = smoothstep(1.15, 0.30, length(centered) * 1.35);

  float amount = uStrength * vignette * (0.28 + glint * 0.80);

  // BlendMode.screen 으로 얹히므로 premultiplied 로 내보냅니다.
  fragColor = vec4(spectral * amount, 1.0);
}

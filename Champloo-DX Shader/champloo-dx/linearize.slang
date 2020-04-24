#version 450

#include "include/champloo-dx-settings.inc"

float GAMMA_INPUT = global.GAMMA_INPUT;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D AfterglowPass;

#define PassPrev3Texture AfterglowPass

void main()
{
   FragColor = pow(vec4(COMPAT_TEXTURE(PassPrev3Texture, vTexCoord)), vec4(GAMMA_INPUT));
}
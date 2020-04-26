#version 450

#include "include/champloo-dx-settings.inc"

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

#define PassPrev6Texture AfterglowPass

void main()
{
   FragColor = vec4(pow(vec3(COMPAT_TEXTURE(PassPrev6Texture, vTexCoord).rgb), vec3(10.0)),1.0);
}

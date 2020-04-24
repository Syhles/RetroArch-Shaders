#version 450

layout(push_constant) uniform Push
{
    float gamma_lcd;
    float gamma_in;
    float gamma_type;
    float wp_temperature;
    float g_vibr;
    float g_hpfix;
    float g_lum;
    float g_cntrst;
    float g_mid;
    float black_level;
    float blr;
    float blg;
    float blb;
    float r;
    float g;
    float b;
    float rg;
    float rb;
    float gr;
    float gb;
    float br;
    float bg;
	float ia_XPOS;
	float ia_YPOS;
} params;

/*
   Grade
   > Ubershader grouping some color related monolithic shaders like color-mangler, vignette, white_point,
   > and the addition of vibrance, black level, sigmoidal contrast and proper gamma transforms.

   Author: hunterk, Guest, Dr. Venom, Dogway
   License: Public domain
*/

#pragma parameter gamma_type "[Gamma] Mode: (POW = 0, sRGB = 1)" 1.0 0.0 1.0 1.0
#pragma parameter gamma_lcd "[Gamma] LCD:" 2.20 0.0 3.0 0.05
#pragma parameter gamma_in "[Gamma] CRT:" 2.40 0.0 3.0 0.05
#pragma parameter wp_temperature "[White] Temperature:" 9311.0 1031.0 12047.0 72.0
#pragma parameter r "[White] Red Tint:" 1.0 0.0 2.0 0.01
#pragma parameter g "[White] Green Tint:" 1.0 0.0 2.0 0.01
#pragma parameter b "[White] Blue Tint:" 1.0 0.0 2.0 0.01
#pragma parameter sat_r "[Saturation] Red Saturation:" 0.0 -1.0 2.0 0.01
#pragma parameter sat_g "[Saturation] Green Saturation:" 0.0 -1.0 2.0 0.01
#pragma parameter sat_b "[Saturation] Blue Saturation:" 0.0 -1.0 2.0 0.01
#pragma parameter g_vibr "[Saturation] Dullness/Vibrance:" 0.0 -1.0 1.0 0.05
#pragma parameter g_hpfix "[Color] Clipping Fix:" 0.0 0.0 1.0 1.00
#pragma parameter g_lum "[Color] Brightness Level:" 0.0 -0.5 1.0 0.01
#pragma parameter g_cntrst "[Color] Contrast Level:" 0.0 -1.0 1.0 0.05
#pragma parameter g_mid "[Color] Contrast Pivot:" 0.5 0.0 1.0 0.01
#pragma parameter black_level "[Black] Lift Level:" 0.0 -0.5 0.5 0.01
#pragma parameter blr "[Black] Red Tint:" 0.0 0.0 1.0 0.01
#pragma parameter blg "[Black] Green Tint:" 0.0 0.0 1.0 0.01
#pragma parameter blb "[Black] Blue Tint:" 0.0 0.0 1.0 0.01
#pragma parameter rg "[Red] Green Tint:" 0.0 -1.0 1.0 0.005
#pragma parameter rb "[Red] Blue Tint:" 0.0 -1.0 1.0 0.005
#pragma parameter gr "[Green] Red Tint:" 0.0 -1.0 1.0 0.005
#pragma parameter gb "[Green] Blue Tint:" 0.0 -1.0 1.0 0.005
#pragma parameter br "[Blue] Red Tint:" 0.0 -1.0 1.0 0.005
#pragma parameter bg "[Blue] Green Tint:" 0.0 -1.0 1.0 0.005
#pragma parameter ia_XPOS "[Position] X Modifier:" 0.0 -2.0 2.0 0.005
#pragma parameter ia_YPOS "[Position] Y Modifier:" 0.0 -2.0 2.0 0.005


layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    float sat_r;
    float sat_g;
    float sat_b;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord + vec2(params.ia_XPOS, params.ia_YPOS);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;


// White Point Mapping function
//
// From the first comment post (sRGB primaries and linear light compensated)
//      http://www.zombieprototypes.com/?p=210#comment-4695029660
// Based on the Neil Bartlett's blog update
//      http://www.zombieprototypes.com/?p=210
// Inspired itself by Tanner Helland's work
//      http://www.tannerhelland.com/4435/convert-temperature-rgb-algorithm-code/

vec3 wp_adjust(vec3 color){

    float temp = params.wp_temperature / 100.;
    float k = params.wp_temperature / 10000.;
    float lk = log(k);

    vec3 wp = vec3(1.);

    // calculate RED
    wp.r = (temp <= 65.) ? 1. : 0.32068362618584273 + (0.19668730877673762 * pow(k - 0.21298613432655075, - 1.5139012907556737)) + (- 0.013883432789258415 * lk);

    // calculate GREEN
    float mg = 1.226916242502167 + (- 1.3109482654223614 * pow(k - 0.44267061967913873, 3.) * exp(- 5.089297600846147 * (k - 0.44267061967913873))) + (0.6453936305542096 * lk);
    float pg = 0.4860175851734596 + (0.1802139719519286 * pow(k - 0.14573069517701578, - 1.397716496795082)) + (- 0.00803698899233844 * lk);
    wp.g = (temp <= 65.5) ? ((temp <= 8.) ? 0. : mg) : pg;

    // calculate BLUE
    wp.b = (temp <= 19.) ? 0. : (temp >= 66.) ? 1. : 1.677499032830161 + (- 0.02313594016938082 * pow(k - 1.1367244820333684, 3.) * exp(- 4.221279555918655 * (k - 1.1367244820333684))) + (1.6550275798913296 * lk);

    // clamp
    wp.rgb = clamp(wp.rgb, vec3(0.), vec3(1.));

    // Linear color input
    return color * wp;
}

vec3 sRGB_to_XYZ(vec3 RGB){

    const mat3x3 m = mat3x3(
    0.4124564, 0.3575761, 0.1804375,
    0.2126729, 0.7151522, 0.0721750,
    0.0193339, 0.1191920, 0.9503041);
    return RGB * m;
}


vec3 XYZtoYxy(vec3 XYZ){

    float XYZrgb = XYZ.r+XYZ.g+XYZ.b;
    float Yxyg = (XYZrgb <= 0.0) ? 0.3805 : XYZ.r / XYZrgb;
    float Yxyb = (XYZrgb <= 0.0) ? 0.3769 : XYZ.g / XYZrgb;
    return vec3(XYZ.g, Yxyg, Yxyb);
}


vec3 XYZ_to_sRGB(vec3 XYZ){

    const mat3x3 m = mat3x3(
    3.2404542, -1.5371385, -0.4985314,
   -0.9692660,  1.8760108,  0.0415560,
    0.0556434, -0.2040259,  1.0572252);
    return XYZ * m;
}


vec3 YxytoXYZ(vec3 Yxy){

    float Xs = Yxy.r * (Yxy.g/Yxy.b);
    float Xsz = (Yxy.r <= 0.0) ? 0.0 : 1.0;
    vec3 XYZ = vec3(Xsz,Xsz,Xsz) * vec3(Xs, Yxy.r, (Xs/Yxy.g)-Xs-Yxy.r);
    return XYZ;
}

// This shouldn't be necessary but it seems some undefined values can
// creep in and each GPU vendor handles that differently. This keeps
// all values within a safe range
vec3 mixfix(vec3 a, vec3 b, float c)
{
    return (a.z < 1.0) ? mix(a, b, c) : a;
}


vec4 mixfix_v4(vec4 a, vec4 b, float c)
{
    return (a.z < 1.0) ? mix(a, b, c) : a;
}


float SatMask(float color_r, float color_g, float color_b)
{
    float max_rgb = max(color_r, max(color_g, color_b));
    float min_rgb = min(color_r, min(color_g, color_b));
    float msk = clamp((max_rgb - min_rgb) / (max_rgb + min_rgb), 0.0, 1.0);
    return msk;
}

float moncurve_f( float color, float gamma, float offs)
{
    // Forward monitor curve
    color = clamp(color, 0.0, 1.0);
    float fs = (( gamma - 1.0) / offs) * pow( offs * gamma / ( ( gamma - 1.0) * ( 1.0 + offs)), gamma);
    float xb = offs / ( gamma - 1.0);

    color = ( color > xb) ? pow( ( color + offs) / ( 1.0 + offs), gamma) : color * fs;
    return color;
}

vec3 moncurve_f_f3( vec3 color, float gamma, float offs)
{
    color.r = moncurve_f( color.r, gamma, offs);
    color.g = moncurve_f( color.g, gamma, offs);
    color.b = moncurve_f( color.b, gamma, offs);
    return color.rgb;
}

float moncurve_r( float color, float gamma, float offs)
{
    // Reverse monitor curve
    color = clamp(color, 0.0, 1.0);
    float yb = pow( offs * gamma / ( ( gamma - 1.0) * ( 1.0 + offs)), gamma);
    float rs = pow( ( gamma - 1.0) / offs, gamma - 1.0) * pow( ( 1.0 + offs) / gamma, gamma);

    color = ( color > yb) ? ( 1.0 + offs) * pow( color, 1.0 / gamma) - offs : color * rs;
    return color;
}


vec3 moncurve_r_f3( vec3 color, float gamma, float offs)
{
    color.r = moncurve_r( color.r, gamma, offs);
    color.g = moncurve_r( color.g, gamma, offs);
    color.b = moncurve_r( color.b, gamma, offs);
    return color.rgb;
}

//  Performs better in gamma encoded space
float contrast_sigmoid(float color, float cont, float pivot){

    cont = pow(cont + 1., 3.);

    float knee = 1. / (1. + exp(cont * pivot));
    float shldr = 1. / (1. + exp(cont * (pivot - 1.)));

    color = (1. / (1. + exp(cont * (pivot - color))) - knee) / (shldr - knee);

    return color;
}


//  Performs better in gamma encoded space
float contrast_sigmoid_inv(float color, float cont, float pivot){

    cont = pow(cont - 1., 3.);

    float knee = 1. / (1. + exp (cont * pivot));
    float shldr = 1. / (1. + exp (cont * (pivot - 1.)));

    color = pivot - log(1. / (color * (shldr - knee) + knee) - 1.) / cont;

    return color;
}

float rolled_gain(float color, float gain){

    float gx = gain + 1.0;
    float ax = (max(0.5 - (gx / 2.0), 0.5));
    float cx = (gx > 0.0) ? (1.0 - gx + (gx / 2.0)) : abs(gx) / 2.0;

    float gain_plus = ((color * gx) > ax) ? (ax + cx * tanh((color * gx - ax) / cx)) : (color * gx);
    float ax_g = 1.0 - abs(gx);
    float gain_minus = (color > ax_g) ? (ax_g + cx * tanh((color - ax_g) / cx)) : color;
    color = (gx > 0.0) ? gain_plus : gain_minus;

    return color;
}

vec4 rolled_gain_v4(vec4 color, float gain){

    color.r = rolled_gain(color.r, gain);
    color.g = rolled_gain(color.g, gain);
    color.b = rolled_gain(color.b, gain);

    return vec4(color.rgb, 1.0);
}

void main()
{

//  Pure power was crushing blacks (eg. DKC2). You can mimic pow(c, 2.4) by raising the gamma_in value to 2.55
    vec3 imgColor = texture(Source, vTexCoord.xy).rgb;
    imgColor = (params.gamma_type == 1.0) ? moncurve_f_f3(imgColor, params.gamma_in + 0.15, 0.055) : pow(imgColor, vec3(params.gamma_in));


//  Saturation agnostic sigmoidal contrast
    vec3 Yxy = XYZtoYxy(sRGB_to_XYZ(imgColor));
    float toGamma = clamp(moncurve_r(Yxy.r, 2.40, 0.055), 0.0, 1.0);
    toGamma = (params.g_hpfix == 0.0) ? toGamma : ((Yxy.r > 0.5) ? contrast_sigmoid_inv(toGamma, 2.3, 0.5) : toGamma);
    float sigmoid = (params.g_cntrst > 0.0) ? contrast_sigmoid(toGamma, params.g_cntrst, params.g_mid) : contrast_sigmoid_inv(toGamma, params.g_cntrst, params.g_mid);
    vec3 contrast = vec3(moncurve_f(sigmoid, 2.40, 0.055), Yxy.g, Yxy.b);
    vec3 XYZsrgb = clamp(XYZ_to_sRGB(YxytoXYZ(contrast)), 0.0, 1.0);
    contrast = (params.g_cntrst == 0.0) && (params.g_hpfix == 0.0) ? imgColor : ((params.g_cntrst != 0.0) || (params.g_hpfix != 0.0) ? XYZsrgb : imgColor);

    contrast += (params.black_level / 20.0) * (1.0 - contrast);

//  RGB related transforms
    vec4 screen = vec4(max(contrast, 0.0), 1.0);
    float r_sat = global.sat_r + 1.0;
    float g_sat = global.sat_g + 1.0;
    float b_sat = global.sat_b + 1.0;
	
                   //  r               g           b  alpha ; alpha does nothing for our purposes
    mat4 color = mat4(params.r, params.rg,  params.rb,  0.0,  //red tint
                     params.gr,  params.g,  params.gb,  0.0,  //green tint
                     params.br, params.bg,   params.b,  0.0,  //blue tint
                    params.blr/20., params.blg/20., params.blb/20., 0.0); //black tint

    mat4 adjust = mat4((1.0 - r_sat) * 0.2126 + r_sat, (1.0 - r_sat) * 0.2126, (1.0 - r_sat) * 0.2126, 1.0,
                       (1.0 - g_sat) * 0.7152, (1.0 - g_sat) * 0.7152 + g_sat, (1.0 - g_sat) * 0.7152, 1.0,
                       (1.0 - b_sat) * 0.0722, (1.0 - b_sat) * 0.0722, (1.0 - b_sat) * 0.0722 + b_sat, 1.0,
                        0.0, 0.0, 0.0, 1.0);

    screen = clamp(rolled_gain_v4(screen, params.g_lum * 2.0), 0.0, 1.0);
    screen = color * screen;
    float sat_msk = (params.g_vibr > 0.0) ? clamp(1.0 - (SatMask(screen.r, screen.g, screen.b) * params.g_vibr), 0.0, 1.0) : clamp(1.0 - abs(SatMask(screen.r, screen.g, screen.b) - 1.0) * abs(params.g_vibr), 0.0, 1.0);
    screen = mixfix_v4(screen, adjust * screen, sat_msk);


//  Color Temperature
    vec3 adjusted = wp_adjust(screen.rgb);
    vec3 base_luma = XYZtoYxy(sRGB_to_XYZ(screen.rgb));
    vec3 adjusted_luma = XYZtoYxy(sRGB_to_XYZ(adjusted));
    adjusted = adjusted_luma + (vec3(base_luma.r, 0.0, 0.0) - vec3(adjusted_luma.r, 0.0, 0.0));
    adjusted = clamp(XYZ_to_sRGB(YxytoXYZ(adjusted)), 0.0, 1.0);


    FragColor = vec4(moncurve_r_f3(adjusted, params.gamma_lcd + 0.20, 0.055), 1.0);
}
layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 FinalViewportSize;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float GAMMA_INPUT, scanline_black, IOS, h_sharp, s_sharp, brightboost, brightboost1, gamma_out;
	float inter, interm;
	float scan_res, gsl, scanline1, scanline2, beam_min, beam_max, beam_size, spike, scans;
	float MASK_STYLE, MASK_DARK;
	float Bloom_Mode, HALATION, DIFFUSION;
	float CURVE_STYLE, csize, bsize;
	float TATE, OS, BLOOM, lsmooth, XFX_STATIC, XFX_VIGNETTE, XFX_HOTSPOT;
	float hmbz_tube_glass_image_opacity;
} global;

layout(push_constant) uniform Push
{
	float curvature_mode;
	float curvature_3D_radius;
	float curvature_3D_view_dist;
	float curvature_3D_tilt_angle_x;
	float curvature_3D_tilt_angle_y;
	float hmss_curvature_2D_long_axis;
	float hmss_curvature_2D_short_axis;	
} params;

// Champloo-DX Pass - Display Settings:
#pragma parameter GAMMA_INPUT "[Display] Gamma: (Input)" 2.4 0.1 5.0 0.05
#pragma parameter scanline_black "[Display] Black: Level" 0.0 0.0 0.1 0.01
#pragma parameter IOS "[Display] Smart Integer Scaling: (1.0:Y, 2.0:'X'+Y)" 0.0 0.0 2.0 1.0
#pragma parameter h_sharp "[Display] Horizontal Sharpness:" 5.25 1.0 15.0 0.25
#pragma parameter s_sharp "[Display] Substractive Sharpness:" 0.40 0.0 1.0 0.05
#pragma parameter brightboost "[Display] Brightboost Dark Pixels:" 1.40 0.50 4.00 0.05
#pragma parameter brightboost1 "[Display] Brightboost Bright Pixels:" 1.15 0.50 3.00 0.05
#pragma parameter gamma_out "[Display] Gamma: (Output)" 2.4 1.0 3.5 0.05

// Champloo-DX Pass - Interlacing Settings:
#pragma parameter inter "[Interlacing] Trigger Resolution:" 400.0 0.0 800.0 25.0
#pragma parameter interm "[Interlacing] Mode: (0.0 = OFF)" 1.0 0.0 3.0 1.0

// Champloo-DX Pass - Scanline Settings:
#pragma parameter scan_res "[Scanline] Resolution Multiplier: (1.0 = Native)" 1.0 1.0 8.0 1.0
#pragma parameter gsl "[Scanline] Style:" 0.0 0.0 2.0 1.0
#pragma parameter scanline1 "[Scanline] Shape Center:" 6.0 1.0 15.0 1.0
#pragma parameter scanline2 "[Scanline] Shape Edge:" 8.0 5.0 23.0 1.0
#pragma parameter beam_min "[Scanline] Dark Pixel Strength:" 1.35 0.5 2.5 0.05
#pragma parameter beam_max "[Scanline] Bright Pixel Strength:" 1.05 0.5 2.5 0.05
#pragma parameter beam_size "[Scanline] Bright Pixel Boost:" 0.70 0.0 1.0 0.05
#pragma parameter spike "[Scanline] Spike Removal:" 1.0 0.0 2.0 0.10 
#pragma parameter scans "[Scanline] Saturation: (Only Mode 1&2)" 0.5 0.0 1.0 0.1

// Champloo-DX Pass - Mask Settings:
#pragma parameter MASK_STYLE "[Mask] Style:" 1.0 0.0 19.0 1.0
#pragma parameter MASK_DARK "[Mask] Phosphor Strength:" 0.7 0.0 1.0 0.05

// Champloo-DX Pass - Bloom Settings:
#pragma parameter Bloom_Mode "[Bloom] Mode:" 1.0 0.0 1.0 1.0
#pragma parameter HALATION "[Bloom] Halation Strength:" 0.03 0.0 1.0 0.01
#pragma parameter DIFFUSION "[Bloom] Diffusion Strength:" 0.0 0.0 1.0 0.01

// Champloo-DX Pass - Curvature Settings:
#pragma parameter curvature_mode "[Curvature] Mode: (0:Off 1-2:3D Sphere, 3:3D Cyl)" 2.0 0.0 3.0 1.0
#pragma parameter curvature_3D_radius "[Curvature] Radius:" 2 0.16 1024 0.01
#pragma parameter curvature_3D_view_dist "[Curvature] View Distance:" 2 0.5 1024 0.05
#pragma parameter curvature_3D_tilt_angle_x "[Curvature] Tilt Angle X:" 0 -3.1415 3.1415 0.01745
#pragma parameter curvature_3D_tilt_angle_y "[Curvature] Tilt Angle Y:" 0 -3.1415 3.1415 0.01745
#pragma parameter hmss_curvature_2D_long_axis "[Curvature] Extra X Curvature: (Def =  2)" 2.0 0.0 100.0 0.2
#pragma parameter hmss_curvature_2D_short_axis "[Curvature] Extra Y Curvature: (Def = 3)" 3.0 0.0 100.0 0.2
#pragma parameter csize "[Curvature] Corner Size:" 0.0 0.0 0.13 0.01
#pragma parameter bsize "[Curvature] Border Smooth:" 600.0 100.0 600.0 25.0

// Champloo-DX Pass - Effect(s) Settings:
#pragma parameter TATE "[Effect] TATE: (Off/On)" 0.0 0.0 1.0 1.0
#pragma parameter OS "[Effect] Over-Bloom Overscan Style:" 1.0 0.0 2.0 1.0
#pragma parameter BLOOM "[Effect] Over-Bloom %:" 0.0 0.0 20.0 1.0
#pragma parameter lsmooth "[Effect] Over-Bloom Smoothing:" 0.90 0.50 0.99 0.01
#pragma parameter XFX_STATIC "[Effect] Static:" 0.0 0.0 99.0 3.0
#pragma parameter XFX_VIGNETTE "[Effect] Vignette: (Def = 0.15)" 0.0 0.0 0.5 0.01
#pragma parameter XFX_HOTSPOT "[Effect] Hotspot: (Def = 15.0)" 10.0 10.0 40.0 1.0
#pragma parameter hmbz_tube_glass_image_opacity "[Tube-Glass] Strength:" 0.0 0.0 50.0 0.1

#define COMPAT_TEXTURE(c,d) texture(c,d)
#define SourceSize global.SourceSize
#define InputSize SourceSize
#define TEX0 vTexCoord

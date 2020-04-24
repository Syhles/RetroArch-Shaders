#version 450

/*
   CRT - Guest - Dr. Venom
   
   Copyright (C) 2018-2020 guest(r) - guest.r@gmail.com

   Incorporates many good ideas and suggestions from Dr. Venom.
   
   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
   
*/

#include "include/subpixel_masks.h"
#include "include/champloo-dx-settings.inc"
#include "include/hsm-royale-geometry-functions.inc"

//-----------------------------------------------------------------------------
// Constants
//-----------------------------------------------------------------------------

// Display Settings:
float IOS = global.IOS;
float h_sharp = global.h_sharp;
float s_sharp = global.s_sharp;
float brightboost = global.brightboost;
float brightboost1 = global.brightboost1;
float gamma_out = global.gamma_out;

// Interlacing Settings:
float inter = global.inter;
float interm = global.interm;

// Scanline Settings:
float scan_res = global.scan_res;
float gsl = global.gsl;
float scanline1 = global.scanline1;
float scanline2 = global.scanline2;
float beam_min = global.beam_min;
float beam_max = global.beam_max;
float beam_size = global.beam_size;
float spike = global.spike;
float scans = global.scans;

// Mask Settings:
float MASK_STYLE = global.MASK_STYLE;
float MASK_DARK = global.MASK_DARK;

// Bloom Settings:
float Bloom_Mode = global.Bloom_Mode;
float HALATION = global.HALATION;
float DIFFUSION = global.DIFFUSION;

// Curvature Setting:
float curvature_mode = params.curvature_mode;
float curvature_3D_radius = params.curvature_3D_radius;
float curvature_3D_view_dist = params.curvature_3D_view_dist;
float curvature_3D_tilt_angle_x = params.curvature_3D_tilt_angle_x;
float curvature_3D_tilt_angle_y = params.curvature_3D_tilt_angle_y;
float hmss_curvature_2D_long_axis = params.hmss_curvature_2D_long_axis;
float hmss_curvature_2D_short_axis = params.hmss_curvature_2D_short_axis;
float csize = global.csize;
float bsize = global.bsize;

// Effect(s) Settings:
float TATE = global.TATE;
float OS = global.OS;
float BLOOM = global.BLOOM;
float XFX_STATIC = global.XFX_STATIC;
float XFX_VIGNETTE = global.XFX_VIGNETTE;
float XFX_HOTSPOT = global.XFX_HOTSPOT;
float vertmask_r = global.vertmask_r;
float vertmask_g = global.vertmask_g;
float vertmask_b = global.vertmask_b;

//-----------------------------------------------------------------------------
// Defines
//-----------------------------------------------------------------------------

#define TextureSize SourceSize
#define FrameCount global.FrameCount

#define SourceSize global.SourceSize
#define OutputSize global.OutputSize
#define gl_FragCoord (vTexCoord * OutputSize.xy)

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.00001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D LinearizePass;
layout(set = 0, binding = 4) uniform sampler2D AvgLumPass;
layout(set = 0, binding = 5) uniform sampler2D GlowPass;

#define Texture Source
#define PassPrev5Texture AvgLumPass
#define PassPrev4Texture LinearizePass
#define PassPrev2Texture GlowPass

float st(float x)
{
	return exp2(-10.0*x*x);
} 
   
vec3 sw0(vec3 x, vec3 color, float scanline)
{
	vec3 tmp = mix(vec3(beam_min),vec3(beam_max), color);
	vec3 ex = x*tmp;
	return exp2(-scanline*ex*ex);
} 

vec3 sw1(vec3 x, vec3 color, float scanline)
{	
	float mx = max(max(color.r, color.g),color.b);
	x = mix (x, beam_min*x, max(x-0.4*mx,0.0));
	vec3 tmp = mix(vec3(1.2*beam_min),vec3(beam_max), color);
	vec3 ex = x*tmp;
	float br = clamp(0.8*beam_min - 1.0, 0.2, 0.45);
	vec3 res = exp2(-scanline*ex*ex)/(1.0-br+br*mx);
	mx = max(max(res.r,res.g),res.b);
	vec3 scans1 = vec3(scans);
	if (vertmask_r != 0.0) scans1.r =1.0;
	if (vertmask_g != 0.0) scans1.g =1.0;
	if (vertmask_b != 0.0) scans1.b =1.0;
	return mix(vec3(mx), res, scans1);		
}    

vec3 sw2(vec3 x, vec3 color, float scanline)
{
	float mx = max(max(color.r, color.g),color.b);
	vec3 tmp = mix(vec3(2.5*beam_min),vec3(beam_max), color);
	tmp = mix(vec3(beam_max), tmp, pow(abs(x), color+0.3));
	vec3 ex = x*tmp;
	vec3 res = exp2(-scanline*ex*ex)/(0.6 + 0.4*mx);
	mx = max(max(res.r,res.g),res.b);
	vec3 scans1 = vec3(scans);
	if (vertmask_r != 0.0) scans1.r =0.85;
	if (vertmask_g != 0.0) scans1.g =0.85;
	if (vertmask_b != 0.0) scans1.b =0.85;
	return mix(vec3(mx), res, scans1);
}

vec2 Overscan(vec2 pos, float dx, float dy){
	pos=pos*2.0-1.0;    
	pos*=vec2(dx,dy);
	return pos*0.5+0.5;
}

// Borrowed from cgwg's crt-geom, under GPL

float corner(vec2 coord)
{
	coord *= SourceSize.xy / InputSize.xy;
	coord = (coord - vec2(0.5)) * 1.0 + vec2(0.5);
	coord = min(coord, vec2(1.0)-coord) * vec2(1.0, OutputSize.y/OutputSize.x);
	vec2 cdist = vec2(max(csize, max((1.0-smoothstep(100.0,600.0,bsize))*0.01,0.002)));
	coord = (cdist - min(coord,cdist));
	float dist = sqrt(dot(coord,coord));
	return clamp((cdist.x-dist)*bsize,0.0, 1.0);
}

vec3 filmGrain(vec2 uv, float strength )
{
	float x = (uv.x + 4.0 ) * (uv.y + 4.0 ) * ((mod(vec2(FrameCount, FrameCount).x, 800.0) + 10.0) * 10.0);
	return  vec3(mod((mod(x, 13.0) + 1.0) * (mod(x, 123.0) + 1.0), 0.01)-0.005) * strength;
}

vec3 declip(vec3 c, float b)
{
	float m = max(max(c.r,c.g),c.b);
	if (m > b) c = c*b/m;
	return c;
}

vec2 HMSS_GetCurvatureValues()
{
	vec2 curvature_values = vec2(hmss_curvature_2D_long_axis / 100, hmss_curvature_2D_short_axis / 100 );
	return curvature_values;
}

void main()
{
	float lum = COMPAT_TEXTURE(PassPrev5Texture, vec2(0.1,0.1)).a;

	// Calculating texel coordinates
   
	vec2 texcoord = TEX0.xy;
	if (IOS > 0.0){
		vec2 ofactor = OutputSize.xy/InputSize.xy;
		vec2 intfactor = round(ofactor);
		vec2 diff = ofactor/intfactor;
		float scan = mix(diff.y, diff.x, TATE);
		texcoord = Overscan(texcoord*(SourceSize.xy/InputSize.xy), scan, scan)*(InputSize.xy/SourceSize.xy);
		if (IOS == 1.0) texcoord = mix(vec2(TEX0.x, texcoord.y), vec2(texcoord.x, TEX0.y), TATE);
	}
   
	float factor  = 1.00 + (1.0-0.5*OS)*BLOOM/100.0 - lum*BLOOM/100.0;
	texcoord  = Overscan(texcoord*(SourceSize.xy/InputSize.xy), factor, factor)*(InputSize.xy/SourceSize.xy);
	vec3 film_grain = filmGrain(texcoord, XFX_STATIC);

	// HSM Added
	vec2 pos = texcoord;
	vec2 pos0 = TEX0;
	if (curvature_mode > 0.5)
	{
		float screen_aspect = global.FinalViewportSize.x / global.FinalViewportSize.y;
		vec2 extra_curvature_mult = HMSS_GetCurvatureValues() / 2 * 50 + 1;
		mat2x2 pixel_to_video_uv;
		pos = HRG_GetGeomCurvedCoord(	texcoord, 
										curvature_mode, 
										curvature_3D_radius,
										curvature_3D_view_dist,
										curvature_3D_tilt_angle_x,
										curvature_3D_tilt_angle_y,
										screen_aspect,
										extra_curvature_mult,
										pixel_to_video_uv);
		pos0 = HRG_GetGeomCurvedCoord(	TEX0, 
										curvature_mode, 
										curvature_3D_radius,
										curvature_3D_view_dist,
										curvature_3D_tilt_angle_x,
										curvature_3D_tilt_angle_y,
										screen_aspect,
										extra_curvature_mult,
										pixel_to_video_uv);
	}
	
	vec2 coffset = vec2(0.5, 0.5);
	bool interb = (interm > 0.5 && interm < 2.5 && inter <= mix(SourceSize.y, SourceSize.x, TATE));
	bool notate  = (TATE < 0.5);
	
	if (interb) coffset = ((notate) ? vec2(0.5,0.0) : vec2(0.0, 0.5));

	vec2 scanres = vec2(1.0,1.0);
	
	vec2 ps;
	if (interm == 0.0) { scanres = vec2(1.0,1.0/scan_res); ps = SourceSize.zw*vec2(1.0, scan_res);} else
	ps = SourceSize.zw;
	
	vec2 OGL2Pos = pos * SourceSize.xy*scanres - coffset;
	vec2 fp = fract(OGL2Pos);
	
	vec2 dx = vec2(ps.x,0.0);
	vec2 dy = vec2(0.0, ps.y);
   
	// Reading the texels
	vec2 x2 = 2.0*dx;
	vec2 y2 = 2.0*dy;

	vec2 offx = dx;
	vec2 off2 = x2;
	vec2 offy = dy;
	float fpx = fp.x;
	if(!notate)
	{
		offx = dy;
		off2 = y2;
		offy = dx;
		fpx = fp.y;
	}
	float  f = (notate) ? fp.y : fp.x;
	
	vec2 pC4 = floor(OGL2Pos) * ps + 0.5*ps;
	
	float zero = exp2(-h_sharp);   
	float sharp1 = s_sharp * zero;
	
	float wl3 = 2.0 + fpx;
	float wl2 = 1.0 + fpx;
	float wl1 =       fpx;
	float wr1 = 1.0 - fpx;
	float wr2 = 2.0 - fpx;
	float wr3 = 3.0 - fpx;

	wl3*=wl3; wl3 = exp2(-h_sharp*wl3);
	wl2*=wl2; wl2 = exp2(-h_sharp*wl2);
	wl1*=wl1; wl1 = exp2(-h_sharp*wl1);
	wr1*=wr1; wr1 = exp2(-h_sharp*wr1);
	wr2*=wr2; wr2 = exp2(-h_sharp*wr2);
	wr3*=wr3; wr3 = exp2(-h_sharp*wr3);

	float fp1 = 1.-fpx;
	
	float twl3 = max(wl3 - sharp1, 0.0);
	float twl2 = max(wl2 - sharp1, mix(0.0,mix(-0.17, -0.01, fpx),float(s_sharp > 0.05)));
	float twl1 = max(wl1 - sharp1, 0.0);
	float twr1 = max(wr1 - sharp1, 0.0);	
	float twr2 = max(wr2 - sharp1, mix(0.0,mix(-0.17, -0.01, fp1),float(s_sharp > 0.05)));
	float twr3 = max(wr3 - sharp1, 0.0);
	
	float wtt = 1.0/(twl3+twl2+twl1+twr1+twr2+twr3);
	float wt  = 1.0/(wl2+wl1+wr1+wr2);
	bool sharp = (s_sharp > 0.05);
	
	vec3 l3 = COMPAT_TEXTURE(PassPrev4Texture, pC4 -off2).xyz;
	vec3 l2 = COMPAT_TEXTURE(PassPrev4Texture, pC4 -offx).xyz;
	vec3 l1 = COMPAT_TEXTURE(PassPrev4Texture, pC4      ).xyz;
	vec3 r1 = COMPAT_TEXTURE(PassPrev4Texture, pC4 +offx).xyz;
	vec3 r2 = COMPAT_TEXTURE(PassPrev4Texture, pC4 +off2).xyz;
	vec3 r3 = COMPAT_TEXTURE(PassPrev4Texture, pC4 +offx+off2).xyz;
	
	vec3 sl2 = COMPAT_TEXTURE(Texture, pC4 -offx).xyz;
	vec3 sl1 = COMPAT_TEXTURE(Texture, pC4      ).xyz;
	vec3 sr1 = COMPAT_TEXTURE(Texture, pC4 +offx).xyz;
	vec3 sr2 = COMPAT_TEXTURE(Texture, pC4 +off2).xyz;
	
	vec3 color1 = (l3*twl3 + l2*twl2 + l1*twl1 + r1*twr1 + r2*twr2 + r3*twr3)*wtt;

	vec3 colmin = min(min(l1,r1), min(l2,r2));
	vec3 colmax = max(max(l1,r1), max(l2,r2));
	
	if (sharp) color1 = clamp(color1, colmin, colmax);
	
	vec3 gtmp = vec3(gamma_out*0.1); 
	vec3 scolor1 = color1;

	scolor1 = (sl2*wl2 + sl1*wl1 + sr1*wr1 + sr2*wr2)*wt;
	scolor1 = pow(scolor1, gtmp);
	scolor1 = mix(color1, scolor1, spike); 
	
	pC4+=offy;
	
	l3 = COMPAT_TEXTURE(PassPrev4Texture, pC4 -off2).xyz;
	l2 = COMPAT_TEXTURE(PassPrev4Texture, pC4 -offx).xyz;
	l1 = COMPAT_TEXTURE(PassPrev4Texture, pC4      ).xyz;
	r1 = COMPAT_TEXTURE(PassPrev4Texture, pC4 +offx).xyz;
	r2 = COMPAT_TEXTURE(PassPrev4Texture, pC4 +off2).xyz;
	r3 = COMPAT_TEXTURE(PassPrev4Texture, pC4 +offx+off2).xyz;
	
	sl2 = COMPAT_TEXTURE(Texture, pC4 -offx).xyz;
	sl1 = COMPAT_TEXTURE(Texture, pC4      ).xyz;
	sr1 = COMPAT_TEXTURE(Texture, pC4 +offx).xyz;
	sr2 = COMPAT_TEXTURE(Texture, pC4 +off2).xyz;
	
	vec3 color2 = (l3*twl3 + l2*twl2 + l1*twl1 + r1*twr1 + r2*twr2 + r3*twr3)*wtt;

	colmin = min(min(l1,r1), min(l2,r2));
	colmax = max(max(l1,r1), max(l2,r2));
	
	if (sharp) color2 = clamp(color2, colmin, colmax);

	vec3 scolor2 = color2;
	
	scolor2 = (sl2*wl2 + sl1*wl1 + sr1*wr1 + sr2*wr2)*wt;
	scolor2 = pow(scolor2, gtmp);
	scolor2 = mix(color2, scolor2, spike); 
	
	vec3 color0 = color1;

	if (interb)
	{
		pC4-= 2.*offy;
	
		l3 = COMPAT_TEXTURE(PassPrev4Texture, pC4 -off2).xyz;
		l2 = COMPAT_TEXTURE(PassPrev4Texture, pC4 -offx).xyz;
		l1 = COMPAT_TEXTURE(PassPrev4Texture, pC4      ).xyz;
		r1 = COMPAT_TEXTURE(PassPrev4Texture, pC4 +offx).xyz;
		r2 = COMPAT_TEXTURE(PassPrev4Texture, pC4 +off2).xyz;
		r3 = COMPAT_TEXTURE(PassPrev4Texture, pC4 +offx+off2).xyz;
	
		color0 = (l3*twl3 + l2*twl2 + l1*twl1 + r1*twr1 + r2*twr2 + r3*twr3)*wtt;
	
		colmin = min(min(l1,r1), min(l2,r2));
		colmax = max(max(l1,r1), max(l2,r2));
	
		if (sharp) color0 = clamp(color0, colmin, colmax);
	}
	
	//Calculating Scanlines
	
	float shape1 = mix(scanline1, scanline2, f);
	float shape2 = mix(scanline1, scanline2, 1.0-f);	
	
	float wt1 = st(f);
	float wt2 = st(1.0-f);

	vec3 color00 = color1*wt1 + color2*wt2;
	vec3 scolor0 = scolor1*wt1 + scolor2*wt2;

	vec3 ctmp = color00/(wt1+wt2);
	vec3 sctmp = scolor0/(wt1+wt2);
	
	vec3 tmp = pow(ctmp, vec3(1.0/gamma_out));

	vec3 w1,w2 = vec3(0.0);
	
	vec3 cref1 = mix(sctmp, scolor1, beam_size);
	vec3 cref2 = mix(sctmp, scolor2, beam_size);
	
	//Vertical Deconvergence
	vec3 shift = vec3(vertmask_r, vertmask_g, vertmask_b);
	vec3 f1 = vec3(f); 
	vec3 f2 = vec3(1.0-f);

	f1 = max(f1 + shift*0.5*(1.0+f), 0.75*f); 
	f2 = max(f2 - shift*0.5*(2.0-f), 0.75*(1.0-f));
	
	// Scanline Style;
	if (gsl == 0.0) { w1 = sw0(f1,cref1,shape1); w2 = sw0(f2,cref2,shape2);} else
	if (gsl == 1.0) { w1 = sw1(f1,cref1,shape1); w2 = sw1(f2,cref2,shape2);} else
	if (gsl == 2.0) { w1 = sw2(f1,cref1,shape1); w2 = sw2(f2,cref2,shape2);}
	
	vec3 color = color1*w1 + color2*w2;
	color = min(color, 1.0);

	// Interlacing Mode: 0 = No Interlacing/Scanlines, 1 = Interlacing, 2 = No Scanline Mode/Hi-Res Mode, 3 = 30fps Interlacing
	if (interm > 0.5 && inter <= mix(SourceSize.y, SourceSize.x, TATE)) 
	{
		if (interm < 2.5)
		{
			float line_no  = floor(mod(mix(  OGL2Pos.y,  OGL2Pos.x, TATE),2.0));		
			float frame_no = floor(mod(float(FrameCount),2.0));
			float ii = (interm > 1.5) ? 0.5 : abs(line_no-frame_no);
			
			vec3 icolor1 = mix(color1, color0, ii);
			vec3 icolor2 = mix(color1, color2, ii);
			
			color = mix(icolor1, icolor2, f);			
		} 
		else color = mix(color1, color2, f);
	}
	
	ctmp = 0.5*(ctmp+tmp);
	color*=mix(brightboost, brightboost1, max(max(ctmp.r,ctmp.g),ctmp.b)); 

	//Static Effect
    color *= (XFX_STATIC > 0.0) ? 1.0 + film_grain : vec3(1.0);

	// Apply Mask
	vec3 mask_weight = (notate) ? mask_weights(gl_FragCoord.xy, MASK_DARK, int(MASK_STYLE)) : mask_weights(gl_FragCoord.yx, MASK_DARK, int(MASK_STYLE));
	color *= mask_weight;

	//Apply Bloom
	vec3 diff = COMPAT_TEXTURE(PassPrev2Texture, pos).rgb;
	vec3 orig1 = color; float pixbr = max(max(ctmp.r,ctmp.g),ctmp.b);
	vec3 one = vec3(1.0); w1 = w1+w2; float w3 = max(max(w1.r,w1.g),w1.b);

	if (Bloom_Mode == 1.0)
	{
		color += diff * mask_weight * HALATION;
		if (interm < 0.5 || inter > mix(SourceSize.y, SourceSize.x, TATE)) color = declip(color, pow(w3,0.5));
		color = min(color, mix(mask_weight,one,0.6));
		color += diff * DIFFUSION;
	}

	color = pow(color, vec3(1.0/gamma_out));

	//Simple Vignette, from https://www.shadertoy.com/view/lsKSWR
	if (XFX_VIGNETTE > 0.0)
	{
		vec2 vpos = pos*(TextureSize.xy/InputSize.xy);
		vpos *= 1.0 - vpos.yx;
		float vig = vpos.x*vpos.y * XFX_HOTSPOT;
		vig = pow(vig, XFX_VIGNETTE);
		color *= vig;
	}

	FragColor = vec4(color*corner(pos0), 1.0);
}

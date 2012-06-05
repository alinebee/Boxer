<?xml version="1.0" encoding="UTF-8"?>
<!--
Hyllian's 5xBR v3.5 Shader
   
   Copyright (C) 2011 Hyllian/Jararaca - sergiogdb@gmail.com

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
   -->
<shader language="GLSL">
  <vertex><![CDATA[
    uniform vec2 rubyTextureSize;

    void main() {
      float x = 1.0 / rubyTextureSize.x;
      float y = 1.0 / rubyTextureSize.y;

      gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
      gl_TexCoord[0] = gl_MultiTexCoord0;
      gl_TexCoord[1].xy = vec2(x, 0.0);
      gl_TexCoord[1].zw = vec2(0.0, y);
    }
  ]]></vertex>
   <fragment filter="point"><![CDATA[
   uniform sampler2D rubyTexture;
   uniform vec2 rubyTextureSize;
vec4 OGL2Param = vec4(0);


const float coef = 2.0;
const vec3 dtt = vec3(65536,255,1);
const float y_weight = 48.0;
const float u_weight = 7.0;
const float v_weight = 6.0;
const mat3 yuv = mat3(0.299, 0.587, 0.114, -0.169, -0.331, 0.499, 0.499, -0.418, -0.0813);
const mat3 yuv_weighted = mat3(y_weight*yuv[0], u_weight*yuv[1], v_weight*yuv[2]);
//const mat3x3 yuv_weighted = mat3x3(14.352, 28.176, 5.472, -1.183, -2.317, 3.5, 3.0, -2.514, -0.486);


bvec4 and(vec4 a, vec4 b)
{
	return bvec4(a.x != 0.0 && b.x != 0.0, a.y != 0.0 && b.y != 0.0, a.z != 0.0 && b.z != 0.0, a.w != 0.0 && b.w != 0.0);
}

bvec4 and(bvec4 a, bvec4 b)
{
	return bvec4(a.x && b.x, a.y && b.y, a.z && b.z, a.w && b.w);
}

vec4 RGBtoYUV(mat4 mat_color)
{
	float a = abs(dot(yuv_weighted[0], mat_color[0].xyz));
	float b = abs(dot(yuv_weighted[0], mat_color[1].xyz));
	float c = abs(dot(yuv_weighted[0], mat_color[2].xyz));
	float d = abs(dot(yuv_weighted[0], mat_color[3].xyz));

	return vec4(a, b, c, d);
}

vec4 df(vec4 A, vec4 B)
{
	return vec4(abs(A-B));
}

vec4 weighted_distance(vec4 a, vec4 b, vec4 c, vec4 d, vec4 e, vec4 f, vec4 g, vec4 h)
{
	return (df(a,b) + df(a,c) + df(d,e) + df(d,f) + 4.0*df(g,h));
}

void main(void)
{
	bvec4 edr, edr_left, edr_up, px; // px = pixel, edr = edge detection rule
	bvec4 interp_restriction_lv1, interp_restriction_lv2_left, interp_restriction_lv2_up;
	
	vec2 fp = fract(gl_TexCoord[0].xy * rubyTextureSize.xy); // Texture size

	vec2 dx = gl_TexCoord[1].xy;
	vec2 dy = gl_TexCoord[1].zw;

	vec4 A = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy -dx -dy).xyz, 0.0);
	vec4 B = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy -dy).xyz, 0.0);
	vec4 C = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy +dx -dy).xyz, 0.0);
	vec4 D = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy -dx ).xyz, 0.0);
	vec4 E = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy ).xyz, 0.0);
	vec4 F = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy +dx ).xyz, 0.0);
	vec4 G = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy -dx +dy).xyz, 0.0);
	vec4 H = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy +dy).xyz, 0.0);
	vec4 I = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy +dx +dy).xyz, 0.0);

	vec4 A1 = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy -dx -2.0*dy).xyz, 0.0);
	vec4 C1 = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy +dx -2.0*dy).xyz, 0.0);
	vec4 A0 = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy -2.0*dx -dy).xyz, 0.0);
	vec4 G0 = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy -2.0*dx +dy).xyz, 0.0);
	vec4 C4 = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy +2.0*dx -dy).xyz, 0.0);
	vec4 I4 = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy +2.0*dx +dy).xyz, 0.0);
	vec4 G5 = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy -dx +2.0*dy).xyz, 0.0);
	vec4 I5 = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy +dx +2.0*dy).xyz, 0.0);
	vec4 B1 = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy -2.0*dy).xyz, 0.0);
	vec4 D0 = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy -2.0*dx ).xyz, 0.0);
	vec4 H5 = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy +2.0*dy).xyz, 0.0);
	vec4 F4 = vec4(texture2D(rubyTexture, gl_TexCoord[0].xy +2.0*dx ).xyz, 0.0);

	//vec4 a = RGBtoYUV( mat4(A, G, I, C) );
	vec4 b = RGBtoYUV( mat4(B, D, H, F) );
	vec4 c = RGBtoYUV( mat4(C, A, G, I) );
	vec4 d = RGBtoYUV( mat4(D, H, F, B) );
	vec4 e = RGBtoYUV( mat4(E, E, E, E) );
	vec4 f = RGBtoYUV( mat4(F, B, D, H) );
	vec4 g = RGBtoYUV( mat4(G, I, C, A) );
	vec4 h = RGBtoYUV( mat4(H, F, B, D) );
	vec4 i = RGBtoYUV( mat4(I, C, A, G) );

	//vec4 a1 = RGBtoYUV( mat4(A1, G0, I5, C4) );
	//vec4 c1 = RGBtoYUV( mat4(C1, A0, G5, I4) );
	//vec4 a0 = RGBtoYUV( mat4(A0, G5, I4, C1) );
	//vec4 g0 = RGBtoYUV( mat4(G0, I5, C4, A1) );
	//vec4 c4 = RGBtoYUV( mat4(C4, A1, G0, I5) );
	vec4 i4 = RGBtoYUV( mat4(I4, C1, A0, G5) );
	//vec4 g5 = RGBtoYUV( mat4(G5, I4, C1, A0) );
	vec4 i5 = RGBtoYUV( mat4(I5, C4, A1, G0) );
	//vec4 b1 = RGBtoYUV( mat4(B1, D0, H5, F4) );
	//vec4 d0 = RGBtoYUV( mat4(D0, H5, F4, B1) );
	vec4 h5 = RGBtoYUV( mat4(H5, F4, B1, D0) );
	vec4 f4 = RGBtoYUV( mat4(F4, B1, D0, H5) );

	interp_restriction_lv1 = and(notEqual(e,f), notEqual(e,h));
	interp_restriction_lv2_left = and(notEqual(e,g), notEqual(d,g));
	interp_restriction_lv2_up = and(notEqual(e,c), notEqual(b,c));

	edr = and(lessThan(weighted_distance( e, c, g, i, h5, f4, h, f), weighted_distance( h, d, i5, f, i4, b, e, i)), interp_restriction_lv1);
	edr_left = and(lessThanEqual(coef*df(f,g),df(h,c)), interp_restriction_lv2_left);
	edr_up = and(greaterThanEqual(df(f,g), (coef*df(h,c))), interp_restriction_lv2_up);

	vec3 E0 = E.xyz;
	vec3 E1 = E.xyz;
	vec3 E2 = E.xyz;
	vec3 E3 = E.xyz;

	px = lessThanEqual(df(e,f), df(e,h));

	vec3 P[4];

	P[0] = px.x ? F.xyz : H.xyz;
	P[1] = px.y ? B.xyz : F.xyz;
	P[2] = px.z ? D.xyz : B.xyz;
	P[3] = px.w ? H.xyz : D.xyz;


	if (edr.x)
	{
		if (edr_left.x && edr_up.x)
		{
			E3 = mix(E3 , P[0], 0.833333);
			E2 = mix(E2 , P[0], 0.25);
			E1 = mix(E1 , P[0], 0.25);
		}
		else if (edr_left.x)
		{
			E3 = mix(E3 , P[0], 0.75);
			E2 = mix(E2 , P[0], 0.25);
		}
		else if (edr_up.x)
		{
			E3 = mix(E3 , P[0], 0.75);
			E1 = mix(E1 , P[0], 0.25);
		}
		else
		{
			E3 = mix(E3 , P[0], 0.5);
		}
	}

	if (edr.y)
	{
		if (edr_left.y && edr_up.y)
		{
			E1 = mix(E1 , P[1], 0.833333);
			E3 = mix(E3 , P[1], 0.25);
			E0 = mix(E0 , P[1], 0.25);
		}
		else if (edr_left.y)
		{
			E1 = mix(E1 , P[1], 0.75);
			E3 = mix(E3 , P[1], 0.25);
		}
		else if (edr_up.y)
		{
			E1 = mix(E1 , P[1], 0.75);
			E0 = mix(E0 , P[1], 0.25);
		}
		else
		{
			E1 = mix(E1 , P[1], 0.5);
		}
	}

	if (edr.z)
	{
		if (edr_left.z && edr_up.z)
		{
			E0 = mix(E0 , P[2], 0.833333);
			E1 = mix(E1 , P[2], 0.25);
			E2 = mix(E2 , P[2], 0.25);
		}
		else if (edr_left.z)
		{
			E0 = mix(E0 , P[2], 0.75);
			E1 = mix(E1 , P[2], 0.25);
		}
		else if (edr_up.z)
		{
			E0 = mix(E0 , P[2], 0.75);
			E2 = mix(E2 , P[2], 0.25);
		}
		else
		{
			E0 = mix(E0 , P[2], 0.5);
		}
	}

	if (edr.w)
	{
		if (edr_left.w && edr_up.w)
		{
			E2 = mix(E2 , P[3], 0.833333);
			E0 = mix(E0 , P[3], 0.25);
			E3 = mix(E3 , P[3], 0.25);
		}
		else if (edr_left.w)
		{
			E2 = mix(E2 , P[3], 0.75);
			E0 = mix(E0 , P[3], 0.25);
		}
		else if (edr_up.w)
		{
			E2 = mix(E2 , P[3], 0.75);
			E3 = mix(E3 , P[3], 0.25);
		}
		else
		{
			E2 = mix(E2 , P[3], 0.5);
		}
	}

	vec3 res = (fp.x < 0.50) ? (fp.y < 0.50 ? E0 : E2) : (fp.y < 0.50 ? E1: E3);
	gl_FragColor = vec4(res, 1.0);
}
      ]]></fragment>
	  </shader>
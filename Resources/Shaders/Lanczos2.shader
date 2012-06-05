<?xml version="1.0" encoding="UTF-8"?>
<shader language="GLSL">
<!-- Taken from http://board.byuu.org/viewtopic.php?f=3&t=1186 -->
<fragment><![CDATA[
/*
Lanczos2 Upsampler for BSNES, v0.1
Copyright (C) 2009 DOLLS

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
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

uniform sampler2D rubyTexture;
uniform vec2 rubyTextureSize;

#define   PI   3.1415926535897932384626433832795

float getWeight(float x)
{   
    if (x == 0.0) return 1.0;
    else if (x <= -2.0 || x >= 2.0) return 0.0;
    else {
      float tmp = x * PI;
      return 2.0 * sin(tmp) * sin(tmp / 2.0) / (tmp * tmp);
   }   
}

void main(void) {   
    vec2 coord = gl_TexCoord[0].xy * rubyTextureSize;   
    ivec2 ic = ivec2(coord - vec2(0.5));   
    vec4 val = vec4(0.0);   
    float contrib = 0.0;
    for (int y = -1; y < 3; y++) {
	for (int x = -1; x < 3; x++) {
	    vec2 d = vec2(ic + ivec2(x, y));
	    vec2 e = abs(coord - d - vec2(0.5));         
	    float weight = getWeight(e.x) * getWeight(e.y);
	    val += texture2D(rubyTexture, (d + 0.5) / rubyTextureSize) * weight;
	    contrib += weight;
	}
    }   
    gl_FragColor = clamp(val / contrib, vec4(0.0), vec4(1.0));
}
]]></fragment>
</shader>

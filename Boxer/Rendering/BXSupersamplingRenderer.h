/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//A renderer variant that renders a video frame to an even multiple of the frame's pixel size
//that is as large or larger than the final viewport, before scaling it down to the final viewport.
//This provides crisper scaling than scaling directly to the final size, but is unavailable on
//hardware that does not support the GL frame buffer extension. (All modern Macs have this though.)

#import "BXBasicRenderer.h"

#define BXDefaultMaxSupersamplingScale 4.0f

@interface BXSupersamplingRenderer : BXBasicRenderer
{
    BXTexture2D *_supersamplingBufferTexture;
	GLuint _supersamplingBuffer;
    GLuint _currentBufferTexture;
    
	CGSize _maxBufferTextureSize;
    CGFloat _maxSupersamplingScale;
    
	BOOL _shouldUseSupersampling;
	BOOL _shouldRecalculateBuffer;
    BOOL _shouldRecalculateBufferAfterViewportChange;
}

//The maximum frame->viewport scale, above which we will just render
//directly to the viewport instead of bothering to resample.
//Defaults to BXDefaultMaxSupersamplingScale.
@property (assign, nonatomic) CGFloat maxSupersamplingScale;

@end

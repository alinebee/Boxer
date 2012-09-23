/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//A shared private API header for BXBasicRenderer subclasses, defining constants and methods
//that are only intended for internal consumption.

#import "BXBasicRenderer.h"
#import "BXSupersamplingRenderer.h"
#import "BXShaderRenderer.h"

#import "BXVideoFrame.h"
#import "BXTexture2D+BXVideoFrameExtensions.h"
#import "BXGeometry.h"

#import <OpenGL/gl.h>
#import <OpenGL/glu.h>
#import <OpenGL/CGLMacro.h>


#pragma mark -
#pragma mark Private constants

//Intended for use by subclasses when drawing.
extern GLfloat viewportVertices[8];
extern GLfloat viewportVerticesFlipped[8];


@interface BXBasicRenderer ()

//Redefined to allow reading and writing.
@property (readwrite, retain) BXVideoFrame *currentFrame;

//The texture into which we draw video frames.
@property (retain) BXTexture2D *frameTexture;

//The texture type we use for frame textures. Either GL_TEXTURE_2D or GL_TEXTURE_RECTANGLE.
@property (readonly, nonatomic) GLenum frameTextureType;

//Called at the start of rendering to do any last-minute setup of the context and textures.
//Should be extended by subclasses to do any additional preparations.
- (void) _prepareForRenderingFrame: (BXVideoFrame *)frame;

//Called after _prepareForRenderingFrame: to actually render the specified frame
//into the renderer's GL context. Should be overridden by subclasses for custom rendering.
- (void) _renderFrame: (BXVideoFrame *)frame;

//Called by _prepareForFrame to create/recreate/populate the frame texture
//with the specified frame as necessary.
//This is also called earlier during updateWithFrame:, to update the texture
//as soon as new frame data is available: this avoids frame-tearing during
//multithreaded rendering.
- (void) _prepareFrameTextureForFrame: (BXVideoFrame *)frame;

//Returns the horizontal and vertical scaling factors we need to apply
//to scale the specified frame to the specified viewport.
- (CGPoint) _scalingFactorFromFrame: (BXVideoFrame *)frame
                         toViewport: (CGRect)viewport;

//Updates the GL viewport to the specified region in screen pixels.
- (void) _setViewportToRegion: (CGRect)viewportRegion;

//Clears the GL viewport with black.
- (void) _clearViewport;

@end



@interface BXSupersamplingRenderer ()

//The texture into which we render for supersampling.
@property (retain) BXTexture2D *supersamplingBufferTexture;

//The texture type we use for buffer textures. Either GL_TEXTURE_2D or GL_TEXTURE_RECTANGLE.
@property (readonly, nonatomic) GLenum bufferTextureType;


//Called during _renderFrame: to check whether to use supersampling
//or fall back on direct rendering.
- (BOOL) _shouldRenderWithSupersampling;

//Prepares a framebuffer and buffer texture for the specified frame if
//a suitable one is not already available.
//This also determines whether a supersampling buffer is even necessary
//(for the specified frame, and flags shouldUseSupersampling accordingly.)
- (void) _prepareSupersamplingBufferForFrame: (BXVideoFrame *)frame;

//Returns the most appropriate supersampling buffer size for the specified frame
//to the specified viewport.
//Normally this returns the nearest even multiple of the frame's pixel size that
//is larger than or equal to the viewport (except in cases where this would exceed
//the supported texture size of the context).
//This returns CGSizeZero if supersampling would be inappropriate, e.g. if the scaling
//factor is too large to bother supersampling for.
- (CGSize) _idealSupersamplingBufferSizeForFrame: (BXVideoFrame *)frame
                                      toViewport: (CGRect)viewportRegion;

- (void) _bindTextureToSupersamplingBuffer: (BXTexture2D *)texture;

@end


@interface BXShaderRenderer ()

//The shader programs we are currently rendering with.
@property (retain, nonatomic) NSArray *shaders;

//The secondary buffer texture we shall use when rendering with shaders.
//(When rendering with a series of shaders, we bounce back and forth between
//our two buffer textures.)
@property (retain, nonatomic) BXTexture2D *auxiliaryBufferTexture;

//Called during _renderFrame: to check whether to render with shaders
//or fall back on supersampled/direct rendering.
- (BOOL) _shouldRenderWithShaders;

//The ideal size at which to render shaders before scaling them down to fit the viewport.
//This may be equal to the final viewport, in which case shader output will be rendered
//straight to the screen instead of upscaled.
- (CGSize) _idealShaderRenderingSizeForFrame: (BXVideoFrame *)frame
                                  toViewport: (CGRect)viewport;

@end

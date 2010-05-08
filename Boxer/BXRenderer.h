/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXRenderer displays the OpenGL 'scene' that renders the DOS output. The OpenGL rendering context
//itself is controlled by BXWindowController.

#import <Cocoa/Cocoa.h>


//Don't bilinear-filter when scaling up beyond 2x
//Used by _shouldUseFiltering
static const CGFloat BXBilinearFilteringScaleCutoff = 2;


@class BXFrameBuffer;

@interface BXRenderer : NSObject
{
	GLuint texture;
	GLuint displayList;
	
	NSSize textureSize;
	GLenum textureTarget;
	
	NSRect viewport;
	NSRect canvas;
	
	BOOL maintainAspectRatio;
	BOOL needsDisplay;
	
	BXFrameBuffer *lastFrame;
}

//The OpenGL viewport into which we are rendering. When maintainAspectRatio is true,
//this is letterboxed within the canvas to match the same ratio as the frame being rendered.
@property (readonly) NSRect viewport;

//If YES, the viewport is letterboxed to match the aspect ratio of the output size;
//otherwise, the viewport fills the entire entire canvas.
@property (assign) BOOL maintainAspectRatio;

//If YES, the render context is 'dirty' and needs redrawing.
//This is set to YES by the drawFrame functions, then back to NO once render has been called.
//Analogous to needsDisplay on NSViews.
@property (assign) BOOL needsDisplay;

//The last framebuffer we rendered.
@property (retain) BXFrameBuffer *lastFrame;


//The maximum size that the renderer can produce. This is equivalent to GL_MAX_TEXTURE_SIZE.
- (NSSize) maxFrameSize;

//Sets the initial OpenGL render parameters, turning off unnecessary OpenGL features.
//Analogous to NSOpenGLView prepareOpenGL.
- (void) prepareOpenGL;

//Returns a frame buffer suitable for the specified resolution, to be displayed at the specified scale.
//(This may return an existing frame buffer rather than a new one.)
- (BXFrameBuffer *) bufferForOutputSize: (NSSize)resolution atScale: (NSSize)scale;

//Resizes the OpenGL viewport in response to a change in the available canvas.
- (void) setCanvas: (NSRect)canvas;

//Draws the DOS output into the OpenGL context.
- (void) render;

//Draw the specified frame into the OpenGL output, and marks the renderer as needing to be displayed.
- (void) drawFrame: (BXFrameBuffer *)frame;

//Draw the specified frame into the OpenGL output, drawing only those regions that are listed in dirtyRegions.
//dirtyRegions should be an array describing the pixel heights of alternating dirty/clean regions:
//e.g. (1, 5, 2, 4) means one clean line, then 5 dirty lines, then 2 clean lines, then 4 dirty lines.
- (void) drawFrame: (BXFrameBuffer *)frame dirtyRegions: (const uint16_t *)dirtyRegions;

@end


//The methods in this category should not be called from outside BXRenderer.
@interface BXRenderer (BXRendererInternals)

- (void) _prepareForFrame: (BXFrameBuffer *)frame;
- (BOOL) _shouldUseFilteringForFrame: (BXFrameBuffer *)frame;
- (void) _setupDisplayListForFrame: (BXFrameBuffer *)frame;
- (void) _setupFilteringForFrame: (BXFrameBuffer *)frame;
- (void) _setupViewportForFrame: (BXFrameBuffer *)frame;
- (void) _setupTextureForFrame: (BXFrameBuffer *)frame;

@end
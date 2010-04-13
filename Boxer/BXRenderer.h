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

//Don't apply scaler effects for resolutions 400 pixels high or larger
//Used by BXRendering _maxFilterSizeForResolution
static const CGFloat BXScalingResolutionCutoff = 400.0;


@interface BXRenderer : NSObject
{
	GLuint texture;
	GLuint displayList;
	
	NSSize outputSize;
	NSSize textureSize;
	GLenum textureTarget;
	NSSize outputScale;
	
	NSRect viewport;
	NSRect canvas;
	
	BOOL maintainAspectRatio;
	BOOL needsDisplay;
	BOOL rendererIsInvalid;
}

//The OpenGL viewport into which we are rendering. When maintainAspectRatio is true,
//this is letterboxed within the canvas to match the same ratio as outputSize.
@property (readonly) NSRect viewport;

//If YES, the viewport is letterboxed to match the aspect ratio of the output size;
//otherwise, the viewport fills the entire entire canvas.
@property (assign) BOOL maintainAspectRatio;

//If YES, the render context is 'dirty' and needs redrawing.
//This is set to YES by the drawPixelData functions, then back to NO once render has been called.
//Analogous to needsDisplay on NSViews.
@property (assign) BOOL needsDisplay;



//The maximum size that the renderer can produce. This is equivalent to GL_MAX_TEXTURE_SIZE.
- (NSSize) maxOutputSize;

//Sets the initial OpenGL render parameters, turning off unnecessary OpenGL features.
//Analogous to NSOpenGLView prepareOpenGL.
- (void) prepareOpenGL;

//Prepares the renderer to draw an output region of the specified pixel dimensions at the specified scale.
//This creates the necessary framebuffer texture and sets up a display list to draw the buffer.
- (void) prepareForOutputSize: (NSSize)size atScale: (NSSize)scale;

//Resizes the OpenGL viewport in response to a change in the available canvas.
- (void) setCanvas: (NSRect)canvas;

//Draws the DOS output into the OpenGL context.
- (void) render;

//Returns the number of bytes per line of output: this is equal to output width * colourdepth.
- (NSUInteger) pitch;

//Copy the specified buffer of pixel data into our texture.
- (void) drawPixelData: (void *)pixelData;

//Copy the specified buffer of pixel data into our texture, copying only those blocks that are listed in dirtyBlocks.
//dirtyBlocks should bean array describing the heights of alternating blocks of dirty/clean lines in the buffer:
//e.g. (1, 5, 2, 4) means one clean line, then 5 dirty lines, then 2 clean lines, then 4 dirty lines.
- (void) drawPixelData: (void *)pixelData dirtyBlocks: (const uint16_t *)dirtyBlocks;

@end


//The methods in this category should not be called from outside BXRenderer.
@interface BXRenderer (BXRendererInternals)

- (void) _updateRenderer;
- (void) _createTexture;
- (void) _createDisplayList;
- (void) _updateViewport;
- (void) _updateFiltering;
- (BOOL) _shouldUseFiltering;

@end
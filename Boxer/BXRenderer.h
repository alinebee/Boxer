/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXRenderer displays the OpenGL 'scene' that renders the DOS output. The OpenGL rendering context
//itself is controlled by BXWindowController.

#import <Cocoa/Cocoa.h>

@interface BXRenderer : NSObject
{
	GLuint texture;
	GLuint displayList;
	
	NSSize outputSize;
	NSSize textureSize;
	NSSize viewportSize;
	NSSize outputScale;
	
	BOOL maintainAspectRatio;
	BOOL needsDisplay;
}
@property (readonly) NSSize viewportSize;

@property (readonly) NSSize outputSize;
//If YES, scales the viewport to match the dimensions of the output size; otherwise, fills the entire viewport with the output 
@property (assign) BOOL maintainAspectRatio;

//The render context is 'dirty' and needs redrawing. Analogous to needsDisplay on NSViews.
@property (assign) BOOL needsDisplay;


//The maximum size that the renderer can produce. This is equivalent to GL_MAX_TEXTURE_SIZE.
- (NSSize) maxOutputSize;

//Sets the initial OpenGL render parameters, turning off unnecessary OpenGL features.
//Analogous to NSOpenGLView prepareOpenGL.
- (void) prepareOpenGL;

//Prepares the renderer to draw an output region of the specified pixel dimensions at the specified scale.
//This creates the necessary framebuffer texture and sets up a display list to draw the buffer.
- (void) prepareForOutputSize: (NSSize)size atScale: (NSSize)scale;

//Resizes the OpenGL viewport in response to a change in the available canvas area.
- (void) setViewportForRect: (NSRect)canvas;

//Redraws the DOS output.
- (void) render;

//Fills the OpenGL viewport with black.
- (void) clear;

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

- (void) _createTexture;
- (void) _createDisplayList;
- (void) _updateFiltering;
- (BOOL) _shouldUseFiltering;

@end
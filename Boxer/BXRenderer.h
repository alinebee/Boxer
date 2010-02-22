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
}
@property (readonly) NSSize outputSize;

@property (assign) BOOL maintainAspectRatio;

- (NSOpenGLContext *) context;

- (void) prepareForOutputSize: (NSSize)size atScale: (NSSize)scale;
- (void) setViewportRect: (NSRect)viewport;
- (void) render;
- (void) clear;

- (void) _prepareOpenGL;
- (void) _createTexture;
- (void) _createDisplayList;
- (void) _updateFiltering;
- (BOOL) _shouldUseFiltering;

- (NSUInteger) _pitch;
- (void) _drawPixelData: (void *)pixelData;
- (void) _drawPixelData: (void *)pixelData dirtyLines: (const uint16_t *)dirtyLines;

@end
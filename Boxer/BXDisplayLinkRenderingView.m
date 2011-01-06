/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDisplayLinkRenderingView.h"
#import "BXRenderer.h"

static CVReturn BXDisplayLinkCallback(CVDisplayLinkRef displayLink,
									  const CVTimeStamp* now,
									  const CVTimeStamp* outputTime,
									  CVOptionFlags flagsIn,
									  CVOptionFlags* flagsOut,
									  void* displayLinkContext)
{
    [(BXGLRenderingView *)displayLinkContext displayIfNeededIgnoringOpacity];
	return kCVReturnSuccess;
}


@implementation BXDisplayLinkRenderingView

#pragma mark -
#pragma mark Rendering methods

- (void) updateWithFrame: (BXFrameBuffer *)frame
{
	[[self renderer] updateWithFrame: frame];
	[self setHidden: frame == nil];
	[self setNeedsDisplay: YES];
	[self display];
}

- (void) prepareOpenGL
{
	// Synchronize buffer swaps with vertical refresh rate
    //GLint swapInt = 1;
    //[[self openGLContext] setValues: &swapInt forParameter: NSOpenGLCPSwapInterval];
	
    // Create a display link capable of being used with all active displays
    CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
	
    // Set the renderer output callback function
    CVDisplayLinkSetOutputCallback(displayLink, &BXDisplayLinkCallback, self);
	
    // Set the display link for the current renderer
    CGLContextObj cglContext = [[self openGLContext] CGLContextObj];
    CGLPixelFormatObj cglPixelFormat = [[self pixelFormat] CGLPixelFormatObj];
    CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(displayLink, cglContext, cglPixelFormat);
	
    // Activate the display link
    CVDisplayLinkStart(displayLink);
	
	[super prepareOpenGL];
}

- (void) clearGLContext
{
	CVDisplayLinkRelease(displayLink);
	[super clearGLContext];
}

@end

/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDisplayLinkRenderingView.h"
#import "BXRenderer.h"
#import "BXAppController.h"

#pragma mark -
#pragma mark Private interface declaration

@interface BXDisplayLinkRenderingView ()
@end
	 
	 
@implementation BXDisplayLinkRenderingView

#pragma mark -
#pragma mark Rendering methods

static CVReturn BXDisplayLinkCallback(CVDisplayLinkRef displayLink,
									  const CVTimeStamp* now,
									  const CVTimeStamp* outputTime,
									  CVOptionFlags flagsIn,
									  CVOptionFlags* flagsOut,
									  void* displayLinkContext)
{
	//Needed because we're operating in a different thread
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	BXGLRenderingView *view = (BXGLRenderingView *)displayLinkContext;
	[view displayIfNeededIgnoringOpacity];
	 
	[pool drain];
	return kCVReturnSuccess;
}

- (id) initWithCoder: (NSCoder *)decoder
{
	if ((self = [super initWithCoder: decoder]))
	{
		//Don't use this class on Leopard, as the DisplayLink approach has rubbish performance on it.
		//Instead, quietly replace ourselves with an instance of our superclass.
		if ([BXAppController isRunningOnLeopard])
		{
			[self release];
			return [(id)[BXGLRenderingView alloc] initWithCoder: decoder];
		}
	}
	return self;
}

- (void) updateWithFrame: (BXFrameBuffer *)frame
{
	[[self renderer] updateWithFrame: frame];
	[self setHidden: frame == nil];
	
	[self setNeedsDisplay: YES];
}

- (void) prepareOpenGL
{
	//Synchronize buffer swaps with vertical refresh rate
	//Disabled for now as this will block emulation at inopportune times
	//while we wait for the next vertical refresh.
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
	if (displayLink)
	{
		CVDisplayLinkRelease(displayLink);
		displayLink = NULL;
	}
	[super clearGLContext];
}

@end

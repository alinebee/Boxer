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

//The display link callback that renders the next frame in sync with the screen refresh.
CVReturn BXDisplayLinkCallback(CVDisplayLinkRef displayLink,
                               const CVTimeStamp* now,  
                               const CVTimeStamp* outputTime,
                               CVOptionFlags flagsIn,
                               CVOptionFlags* flagsOut,
                               void* displayLinkContext);

@end
	 
	 
@implementation BXDisplayLinkRenderingView

- (id) initWithCoder: (NSCoder *)decoder
{
    //Don't use this class on Leopard, as the DisplayLink approach has rubbish performance on it.
    //Instead, quietly replace ourselves with an instance of our superclass.
    if ([BXAppController isRunningOnLeopard])
    {
        [self release];
        return [(id)[BXGLRenderingView alloc] initWithCoder: decoder];
    }
    else
    {
        return [super initWithCoder: decoder];
    }
}


#pragma mark -
#pragma mark Rendering methods

- (void) updateWithFrame: (BXFrameBuffer *)frame
{
    //Pre-render the frame, but don't flush it or tell Cocoa that we need redrawing.
    //Instead, we'll flush in the display link.
    [[self renderer] updateWithFrame: frame];
    [self renderFrame];
}

- (void) prepareOpenGL
{   
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

CVReturn BXDisplayLinkCallback(CVDisplayLinkRef displayLink,
                               const CVTimeStamp* now,  
                               const CVTimeStamp* outputTime,
                               CVOptionFlags flagsIn,
                               CVOptionFlags* flagsOut,
                               void* displayLinkContext)
{
	//Needed because we're operating in a different thread
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	BXDisplayLinkRenderingView *view = (BXDisplayLinkRenderingView *)displayLinkContext;
    
    [view flushIfNeeded];
    
	[pool drain];
	return kCVReturnSuccess;
}

@end

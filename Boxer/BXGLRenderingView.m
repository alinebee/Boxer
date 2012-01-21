/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXGLRenderingView.h"
#import "BXRenderer.h"
#import "BXDOSWindowController.h" //For notifications

#pragma mark -
#pragma mark Private interface declaration

@interface BXGLRenderingView ()

//Whether we should redraw in the next display-link cycle.
//Set to YES upon receiving a new frame, then back to NO after rendering it.
@property (assign) BOOL needsCVLinkDisplay;

//The display link callback that renders the next frame in sync with the screen refresh.
CVReturn BXDisplayLinkCallback(CVDisplayLinkRef displayLink,
                               const CVTimeStamp* now,  
                               const CVTimeStamp* outputTime,
                               CVOptionFlags flagsIn,
                               CVOptionFlags* flagsOut,
                               void* displayLinkContext);

@end


@implementation BXGLRenderingView
@synthesize renderer;
@synthesize needsCVLinkDisplay;

- (id) initWithCoder: (NSCoder *)aDecoder
{
    if ((self = [super initWithCoder: aDecoder]))
    {
        [self setRenderer: [[[BXRenderer alloc] init] autorelease]];
    }
    return self;
}

- (void) dealloc
{
	[self setRenderer: nil], [renderer release];
	[super dealloc];
}


//Pass on various events that would otherwise be eaten by the default NSView implementation
- (void) rightMouseDown: (NSEvent *)theEvent
{
	[[self nextResponder] rightMouseDown: theEvent];
}

#pragma mark -
#pragma mark Rendering methods

- (void) setManagesAspectRatio: (BOOL)manage
{
	[[self renderer] setMaintainsAspectRatio: manage];
}

- (BOOL) managesAspectRatio
{
	return [[self renderer] maintainsAspectRatio];	
}

- (void) updateWithFrame: (BXFrameBuffer *)frame
{
    //Update the frame but don't tell Cocoa that we need redrawing:
    //Instead, we'll render and flush in the display link. This prevents
    //Cocoa from drawing the dirty view at the 'wrong' time.
    [[self renderer] updateWithFrame: frame inGLContext: [[self openGLContext] CGLContextObj]];
    [self setNeedsCVLinkDisplay: YES];
}

- (BXFrameBuffer *) currentFrame
{
    return [[self renderer] currentFrame];
}

- (NSSize) viewportSize
{
	return NSSizeFromCGSize([renderer viewportForFrame: [self currentFrame]].size);
}

- (NSSize) maxFrameSize
{
	return NSSizeFromCGSize([renderer maxFrameSize]);
}


- (void) prepareOpenGL
{
	CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
	
	//Enable multithreaded OpenGL execution (if available)
	CGLEnable(cgl_ctx, kCGLCEMPEngine);
    
    //Synchronize buffer swaps with vertical refresh rate
    GLint useVSync = [[NSUserDefaults standardUserDefaults] boolForKey: @"useVSync"];
    [[self openGLContext] setValues: &useVSync forParameter: NSOpenGLCPSwapInterval];
	
    //Let the renderer do its own preparations
	[[self renderer] prepareForGLContext: cgl_ctx];
    
    
	//Create a display link capable of being used with all active displays
	CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
	
	//Set the renderer output callback function
	CVDisplayLinkSetOutputCallback(displayLink, &BXDisplayLinkCallback, self);
	
	// Set the display link for the current renderer
	CGLPixelFormatObj cglPixelFormat = [[self pixelFormat] CGLPixelFormatObj];
	CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(displayLink, cgl_ctx, cglPixelFormat);
	
	//Activate the display link
	CVDisplayLinkStart(displayLink);
}

- (void) clearGLContext
{
	if (displayLink)
	{
		CVDisplayLinkRelease(displayLink);
		displayLink = NULL;
	}
    
	[[self renderer] tearDownGLContext: [[self openGLContext] CGLContextObj]];	
	[super clearGLContext];
}

- (void) reshape
{
    [super reshape];
	[[self renderer] setCanvas: NSRectToCGRect([self bounds])];
}

- (void) drawRect: (NSRect)dirtyRect
{
    [self setNeedsCVLinkDisplay: NO];
    
    CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
    if ([[self renderer] canRenderToGLContext: cgl_ctx])
	{
		CGLLockContext(cgl_ctx);
            [[self renderer] renderToGLContext: cgl_ctx];
            [[self renderer] flushToGLContext: cgl_ctx];
        CGLUnlockContext(cgl_ctx);
	}
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
	
	BXGLRenderingView *view = (BXGLRenderingView *)displayLinkContext;
    
    if ([view needsCVLinkDisplay])
        [view display];
    
	[pool drain];
	return kCVReturnSuccess;
}


//Silly notifications to let the window controller know when a live resize operation is starting/stopping,
//so that it can clean up afterwards.
- (void) viewWillStartLiveResize
{	
	[super viewWillStartLiveResize];
	[[NSNotificationCenter defaultCenter] postNotificationName: BXViewWillLiveResizeNotification object: self];
}

- (void) viewDidEndLiveResize
{
	[super viewDidEndLiveResize];
	[[NSNotificationCenter defaultCenter] postNotificationName: BXViewDidLiveResizeNotification object: self];
}

@end

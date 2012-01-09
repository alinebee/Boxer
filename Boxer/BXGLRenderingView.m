/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXGLRenderingView.h"
#import "BXRenderer.h"
#import "BXDOSWindowController.h" //For notifications

@implementation BXGLRenderingView
@synthesize renderer;

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
	[[self renderer] updateWithFrame: frame inGLContext: [[self openGLContext] CGLContextObj]];
	[self setNeedsDisplay: YES];
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
	
	[[self renderer] prepareForGLContext: cgl_ctx];
}

- (void) clearGLContext
{
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
    CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
    if ([[self renderer] canRenderToGLContext: cgl_ctx])
	{
		CGLLockContext(cgl_ctx);
            [[self renderer] renderToGLContext: cgl_ctx];
            [[self renderer] flushToGLContext: cgl_ctx];
        CGLUnlockContext(cgl_ctx);
	}
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

- (BOOL) needsDisplayCaptureSuppression
{
	return [[self renderer] needsDisplayCaptureSuppression];
}

@end

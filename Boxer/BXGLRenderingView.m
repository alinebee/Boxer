/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXGLRenderingView.h"
#import "BXRenderer.h"

@implementation BXGLRenderingView
@synthesize renderer;

- (void) awakeFromNib
{
	[self setRenderer: [[BXRenderer new] autorelease]];
	//Hide the view until we receive our first frame
	[self setHidden: YES];
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
	[self setNeedsDisplay: YES];
}

- (BOOL) managesAspectRatio
{
	return [[self renderer] maintainsAspectRatio];	
}

- (void) updateWithFrame: (BXFrameBuffer *)frame
{
	[[self renderer] updateWithFrame: frame];
	[self setHidden: NO];
	[self setNeedsDisplay: YES];
}

- (BXFrameBuffer *)currentFrame
{
	return [[self renderer] currentFrame];
}

- (NSSize) viewportSize
{
	return NSSizeFromCGSize([renderer viewportForFrame: [renderer currentFrame]].size);
}

- (NSSize) maxFrameSize
{
	return NSSizeFromCGSize([renderer maxFrameSize]);
}


- (void) prepareOpenGL
{
	[[self renderer] prepareForGLContext: [[self openGLContext] CGLContextObj]];
}

- (void) clearGLContext
{
	[[self renderer] tearDownGLContext: [[self openGLContext] CGLContextObj]];	
	[super clearGLContext];
}

- (void) reshape
{
	[[self renderer] setCanvas: NSRectToCGRect([self bounds])];
}

- (void) drawRect: (NSRect)dirtyRect
{
	CGLContextObj glContext = [[self openGLContext] CGLContextObj];
	if ([[self renderer] canRenderToGLContext: glContext])
	{
		[[self renderer] renderToGLContext: glContext];
		[[self openGLContext] flushBuffer];
	}
}

@end

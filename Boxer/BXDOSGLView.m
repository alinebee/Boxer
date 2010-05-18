/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDOSGLView.h"
#import "BXRenderer.h"
#import "BXGeometry.h"

@implementation BXDOSGLView
@synthesize renderer;

- (void) awakeFromNib
{
	[self setRenderer: [[BXRenderer new] autorelease]];
}

- (void) dealloc
{
	[self setRenderer: nil], [renderer release];
	[super dealloc];
}

- (BOOL) acceptsFirstResponder
{
	return YES;
}

//Pass on various events that would otherwise be eaten by the view
- (void) rightMouseDown: (NSEvent *)theEvent
{
	[[self nextResponder] rightMouseDown: theEvent];
}


- (void) drawBackgroundInRect: (NSRect)dirtyRect
{
	//Cache the background gradient so we don't have to generate it each time
	static NSGradient *background = nil;
	if (background == nil)
	{
		NSColor *backgroundColor = [NSColor darkGrayColor];
		background = [[NSGradient alloc] initWithColorsAndLocations:
					  [backgroundColor shadowWithLevel: 0.5],	0.00,
					  backgroundColor,							0.98,
					  [backgroundColor shadowWithLevel: 0.4],	1.00,
					  nil];	
	}
	
	[background drawInRect: [self bounds] angle: 90];
	
	NSImage *brand = [NSImage imageNamed: @"Brand.png"];
	NSRect brandRegion;
	brandRegion.size = [brand size];
	brandRegion = centerInRect(brandRegion, [self bounds]);
	
	if (NSIntersectsRect(dirtyRect, brandRegion))
	{
		[brand drawInRect: brandRegion
				 fromRect: NSZeroRect
				operation: NSCompositeSourceOver
				 fraction: 1.0];	
	}		
}


#pragma -
#pragma mark Rendering methods

- (void) updateWithFrame: (BXFrameBuffer *)frame
{
	[[self renderer] updateWithFrame: frame];
	[self setNeedsDisplay: YES];
}

- (void) prepareOpenGL
{
	[[self renderer] prepareForGLContext: [[self openGLContext] CGLContextObj]];	
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
	else
	{
		[NSBezierPath clipRect: dirtyRect];
		[self drawBackgroundInRect: dirtyRect];
	}
}



//Silly notifications to let the window controller know when a live resize operation is starting/stopping,
//so that it can clean up afterwards.
- (void) viewWillStartLiveResize
{	
	[super viewWillStartLiveResize];
	[[NSNotificationCenter defaultCenter] postNotificationName: @"BXDOSViewWillLiveResizeNotification" object: self];
}

- (void) viewDidEndLiveResize
{
	[super viewDidEndLiveResize];
	[[NSNotificationCenter defaultCenter] postNotificationName: @"BXDOSViewDidLiveResizeNotification" object: self];
}

@end
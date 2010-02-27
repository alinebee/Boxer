/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXRenderView.h"
#import "BXGeometry.h"
#import "BXRenderer.h"

@implementation BXRenderView
@synthesize renderer;

//This helps optimize OS X's rendering decisions, hopefully
- (BOOL) isOpaque	{ return YES; }

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

- (void) drawRect: (NSRect)dirtyRect
{
	[NSBezierPath clipRect: dirtyRect];
	if ([self renderer])
	{
		//[[self openGLContext] makeCurrentContext];
		[[self renderer] render];
		[[self openGLContext] flushBuffer];
	}
	else
	{
		return [self drawBackgroundInRect: dirtyRect];
	}
}

//OpenGL methods
//--------------

//Whenever we get assigned a new renderer, reinitialise the OpenGL context
- (void) setRenderer: (BXRenderer *)newRenderer
{
	[self willChangeValueForKey: @"renderer"];
	if (![[self renderer] isEqualTo: newRenderer])
	{
		[self unbind: @"needsDisplay"];
		[[self renderer] autorelease];
		renderer = [newRenderer retain];
		
		if ([self renderer])
		{
			//Tell the new renderer to get the OpenGL context ready
			[self prepareOpenGL];
			[self reshape];
			
			//Bind ourselves to the renderer so that we redraw when the renderer marks itself as dirty
			[self bind: @"needsDisplay" toObject: renderer withKeyPath: @"needsDisplay" options: nil];
		}
	}
	[self didChangeValueForKey: @"renderer"];
}

- (void) reshape
{
	[[self renderer] setCanvas: [self bounds]];
}

- (void) prepareOpenGL
{
	[[self renderer] prepareOpenGL];
}

//Silly notifications to let the window controller know when a live resize operation is starting/stopping,
//so that it can clean up afterwards.
- (void) viewWillStartLiveResize
{	
	[[NSNotificationCenter defaultCenter] postNotificationName: @"BXRenderViewWillLiveResizeNotification" object: self];
}

- (void) viewDidEndLiveResize
{
	[[NSNotificationCenter defaultCenter] postNotificationName: @"BXRenderViewDidLiveResizeNotification" object: self];
}
@end
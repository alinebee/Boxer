/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXRenderView.h"
#import "BXGeometry.h"

@implementation BXRenderView

//This helps optimize OS X's rendering decisions, hopefully
- (BOOL) isOpaque	{ return YES; }

- (void) drawBackgroundInRect: (NSRect)dirtyRect
{
	//Cache the background gradient so we don't have to generate it each time
	static NSGradient *background = nil;
	if (background == nil)
	{
		background = [[NSGradient alloc] initWithColorsAndLocations:
					  [NSColor colorWithCalibratedWhite: 0.15 alpha: 1.0],	0.0,
					  [NSColor colorWithCalibratedWhite: 0.25 alpha: 1.0],	0.98,
					  [NSColor colorWithCalibratedWhite: 0.15 alpha: 1.0],	1.0,
					  nil];	
	}
	
	[background drawInRect: [self bounds] angle: 90];
	
	NSImage *brand = [NSImage imageNamed: @"Brand.png"];
	NSRect brandRegion;
	brandRegion.size = [brand size];
	brandRegion =  centerInRect(brandRegion, [self bounds]);
	
	if (NSIntersectsRect(dirtyRect, brandRegion))
	{
		[brand drawInRect: brandRegion
				 fromRect: NSZeroRect
				operation: NSCompositeSourceOver
				 fraction: 1.0];	
	}		
}

- (void) drawCachedImageInRect: (NSRect)dirtyRect
{
	NSRect bounds = [self bounds];

	//Fill the view with black
	//This will show at the edges of the image if the aspect ratio changes
	//TODO: let the SDLView handle this
	[[NSColor blackColor] setFill];
	[NSBezierPath fillRect: dirtyRect];
}

- (void) drawRect: (NSRect)dirtyRect
{
	[NSBezierPath clipRect: dirtyRect];
	if ([self inLiveResize])
	{
		//While resizing, just fill the view with black
		[[NSColor blackColor] setFill];
		[NSBezierPath fillRect: dirtyRect];
	}
	else
	{
		//The rest of the time, draw our grey background and badge underneath
		return [self drawBackgroundInRect: dirtyRect];
	}
}

//Silly notifications to let the window controller know when a live resize operation is starting/stopping,
//so that it can clean up afterwards. These should go on BXSessionWindow now instead.
- (void)viewWillStartLiveResize
{	
	[[NSNotificationCenter defaultCenter] postNotificationName: @"BXRenderViewWillLiveResizeNotification" object: self];
}

- (void)viewDidEndLiveResize
{
	[[NSNotificationCenter defaultCenter] postNotificationName: @"BXRenderViewDidLiveResizeNotification" object: self];
}
@end
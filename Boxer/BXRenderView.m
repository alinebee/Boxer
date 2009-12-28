/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXRenderView.h"
#import "BXGeometry.h"

@implementation BXRenderView
@synthesize cachedImage;

//This helps optimize OS X's rendering decisions, hopefully
- (BOOL) isOpaque	{ return YES; }

//When doing a live resize, make sure our subviews are hidden so that our cached image shows through
//We do this here at the last minute rather than in viewWillStartLiveResize, to avoid a momentary flicker
//before the drawing begins
- (void) viewWillDraw
{
	if (!subviewsHidden && [self inLiveResize] && [self cachedImage])
	{
		for (NSView *subview in [self subviews]) [subview setHidden: YES];
		subviewsHidden = YES;
	}
	[super viewWillDraw];
}

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

	//First, fill the view with black
	//This will show at the edges of the image if the aspect ratio changes
	[[NSColor blackColor] setFill];
	[NSBezierPath fillRect: dirtyRect];
	
	//Center the cached image within the view, retaining its original aspect ratio
	//This isn't needed for normal resizes because we keep the aspect ratio locked,
	//but it is needed when scaling to fill the screen.
	NSRect drawRect;
	drawRect.size	= sizeToFitSize([cachedImage size], bounds.size);
	drawRect		= centerInRect(drawRect, bounds);
	
	if (NSIntersectsRect(dirtyRect, drawRect))
	{
		[cachedImage drawInRect: NSIntegralRect(drawRect)];	
	}
}

- (void) drawRect: (NSRect)dirtyRect
{
	[NSBezierPath clipRect: dirtyRect];
	if ([self inLiveResize] && [self cachedImage])
	{
		//While resizing, draw our cached fake image at the appropriate scale
		return [self drawCachedImageInRect: dirtyRect];
	}
	else
	{
		//The rest of the time, draw our grey background and badge underneath
		return [self drawBackgroundInRect: dirtyRect];
	}
}

//Cache an image of our current content to display while we resize
- (void)viewWillStartLiveResize
{
	NSView *SDLView = [[self subviews] lastObject];
	if (SDLView)
	{
		NSRect captureRegion = [SDLView visibleRect];
		NSBitmapImageRep *capturedImage = [SDLView bitmapImageRepForCachingDisplayInRect:captureRegion];
		[SDLView cacheDisplayInRect: captureRegion toBitmapImageRep: capturedImage];

		[self setCachedImage: capturedImage];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName: @"BXRenderViewWillLiveResizeNotification" object: self];
}

- (void)viewDidEndLiveResize
{
	//Clear the image cache and unhide our views
	for (NSView *subview in [self subviews]) [subview setHidden: NO];
	subviewsHidden = NO;
	[self setCachedImage: nil];
	
	[[NSNotificationCenter defaultCenter] postNotificationName: @"BXRenderViewDidLiveResizeNotification" object: self];
}

- (void) dealloc
{
	[self setCachedImage: nil], [cachedImage release];
	[super dealloc];
}
@end
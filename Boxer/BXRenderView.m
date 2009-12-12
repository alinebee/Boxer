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

- (void) drawRect: (NSRect)dirtyRect
{
	//First draw a flat black background
	[[NSColor blackColor] set];
	[NSBezierPath fillRect:dirtyRect];
	
	//While resizing, draw our cached fake image at the appropriate scale
	if ([self inLiveResize] && cachedImage)
	{
		NSRect bounds = [self bounds];
		NSRect drawRect;
		
		//Center the cached image within the view, retaining its original aspect ratio
		//This isn't needed for normal resizes because we keep the aspect ratio locked, but it's needed when scaling to fill the screen
		//Could we do this by modifying the view bounds instead?
		drawRect.size	= sizeToFitSize([cachedImage size], bounds.size);
		drawRect.origin	= NSMakePoint(
			(NSMaxX(bounds) - drawRect.size.width)	/ 2,
			(NSMaxY(bounds) - drawRect.size.height)	/ 2
		);
		
		//An integral rect may result in faster draws?? or may not??
		drawRect = NSIntegralRect(drawRect);
		[cachedImage drawInRect: drawRect];
		
		/*
		//Quick and dirty fade effect if we want it, which we currently don't
		NSColor *black = [NSColor colorWithDeviceWhite: 0.0 alpha: 0.5];
		[black set];
		[NSBezierPath fillRect:drawRect];
		*/
	}
	
	//Draw a focus ring if appropriate
	//Currently unusable because it will be covered by SDL's opaque (literally and figuratively) NSOpenGLView
	/*
	if (YES)
	{
	    NSRect frameRect = NSInsetRect([self bounds],4,4);
		[NSGraphicsContext saveGraphicsState];
		[self setKeyboardFocusRingNeedsDisplayInRect: frameRect];
		NSSetFocusRingStyle(NSFocusRingOnly);
		[[NSBezierPath bezierPathWithRect: frameRect] fill];
		[self setKeyboardFocusRingNeedsDisplayInRect: frameRect];
		[NSGraphicsContext restoreGraphicsState];
    }
	*/
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
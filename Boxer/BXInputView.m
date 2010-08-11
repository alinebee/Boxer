/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXInputView.h"
#import "BXGeometry.h"
#import "BXDOSWindowController.h"


NSString * const BXViewWillLiveResizeNotification	= @"BXViewWillLiveResizeNotification";
NSString * const BXViewDidLiveResizeNotification	= @"BXViewDidLiveResizeNotification";

@implementation BXInputView
@synthesize appearance;

- (BOOL) acceptsFirstResponder
{
	return YES;
}

//Use flipped coordinates to make input handling easier
- (BOOL) isFlipped
{
	return YES;
}

//Pass on various events that would otherwise be eaten by the default NSView implementation
- (void) rightMouseDown: (NSEvent *)theEvent
{
	[[self nextResponder] rightMouseDown: theEvent];
}


- (void) drawBackgroundInRect: (NSRect)dirtyRect
{
	//Cache the background gradient so we don't have to generate it each time
	static NSGradient *background = nil;
	if (!background)
	{
		NSColor *backgroundColor = [NSColor darkGrayColor];
		background = [[NSGradient alloc] initWithColorsAndLocations:
					  [backgroundColor shadowWithLevel: 0.5f],	0.00f,
					  backgroundColor,							0.98f,
					  [backgroundColor shadowWithLevel: 0.4f],	1.00f,
					  nil];	
	}
	
	[background drawInRect: [self bounds] angle: 270.0f];
}

- (void) drawBlueprintBackgroundInRect: (NSRect)dirtyRect
{
	static NSGradient *lighting = nil;
	static NSColor *pattern = nil;
	if (!lighting)
	{
		lighting = [[NSGradient alloc] initWithColorsAndLocations:
					[NSColor colorWithCalibratedWhite: 0.0f alpha: 0.3f], 0.00f,
					[NSColor colorWithCalibratedWhite: 1.0f alpha: 0.2f], 0.98f,
					[NSColor colorWithCalibratedWhite: 0.0f alpha: 0.3f], 1.00f,
					nil];	
		pattern = [[NSColor colorWithPatternImage: [NSImage imageNamed: @"Blueprint.jpg"]] retain];
	}
	
	NSSize patternSize		= [[pattern patternImage] size];
	NSRect viewFrame		= [self frame];
	NSPoint patternPhase	= NSMakePoint(viewFrame.origin.x + ((viewFrame.size.width - patternSize.width) / 2),
										  viewFrame.origin.y + ((viewFrame.size.height - patternSize.height) / 2));
	
	[NSGraphicsContext saveGraphicsState];
		[[NSGraphicsContext currentContext] setPatternPhase: patternPhase];
		[pattern set];
		[NSBezierPath fillRect: dirtyRect];
		[lighting drawInRect: [self bounds] angle: 270.0f];	
	[NSGraphicsContext restoreGraphicsState];
}

- (void) drawBrandInRect: (NSRect)dirtyRect
{
	NSImage *brand = [NSImage imageNamed: @"Brand.png"];
	[brand setFlipped: YES];
	NSRect brandRegion;
	brandRegion.size = [brand size];
	brandRegion = NSIntegralRect(centerInRect(brandRegion, [self bounds]));
	
	if (NSIntersectsRect(dirtyRect, brandRegion))
	{
		[brand drawInRect: brandRegion
				 fromRect: NSZeroRect
				operation: NSCompositeSourceOver
				 fraction: 1.0f];	
	}
}


- (void) drawBlueprintBrandInRect: (NSRect)dirtyRect
{
	NSImage *brand = [NSImage imageNamed: @"BrandWatermark.png"];
	[brand setFlipped: YES];
	NSRect brandRegion;
	brandRegion.size = [brand size];
	brandRegion = NSIntegralRect(centerInRect(brandRegion, [self bounds]));
	
	if (NSIntersectsRect(dirtyRect, brandRegion))
	{
		[brand drawInRect: brandRegion
				 fromRect: NSZeroRect
				operation: NSCompositeSourceOver
				 fraction: 1.0f];	
	}
}

- (void) drawRect: (NSRect)dirtyRect
{
	[NSBezierPath clipRect: dirtyRect];
	
	if (appearance == BXInputViewBlueprintAppearance)
	{
		[self drawBlueprintBackgroundInRect: dirtyRect];
		[self drawBlueprintBrandInRect: dirtyRect];		
	}
	else
	{
		[self drawBackgroundInRect: dirtyRect];
		[self drawBrandInRect: dirtyRect];			
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

@end

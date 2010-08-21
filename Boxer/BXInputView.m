/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXInputView.h"
#import "BXGeometry.h"
#import "NSView+BXDrawing.h"

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


- (void) _drawBackgroundInRect: (NSRect)dirtyRect
{
	NSColor *backgroundColor = [NSColor darkGrayColor];
	NSGradient *background = [[NSGradient alloc] initWithColorsAndLocations:
							  [backgroundColor shadowWithLevel: 0.5f],	0.00f,
							  backgroundColor,							0.98f,
							  [backgroundColor shadowWithLevel: 0.4f],	1.00f,
							  nil];
	
	[background drawInRect: [self bounds] angle: 270.0f];
	[background release];
}

- (void) _drawBlueprintInRect: (NSRect)dirtyRect
{	
	NSColor *blueprintColor = [NSColor colorWithPatternImage: [NSImage imageNamed: @"Blueprint.jpg"]];
	NSSize patternSize		= [[blueprintColor patternImage] size];
	NSSize viewSize			= [self bounds].size;
	NSPoint patternOffset	= [self offsetFromWindowOrigin];
	NSPoint patternPhase	= NSMakePoint(patternOffset.x + ((viewSize.width - patternSize.width) / 2),
										  patternOffset.y + ((viewSize.height - patternSize.height) / 2));
	
	[NSGraphicsContext saveGraphicsState];
		[[NSGraphicsContext currentContext] setPatternPhase: patternPhase];
		[blueprintColor set];
		[NSBezierPath fillRect: [self bounds]];
	[NSGraphicsContext restoreGraphicsState];
}

- (void) _drawLightingInRect: (NSRect)dirtyRect
{
	NSGradient *lighting = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.2f]
														 endingColor: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.4f]];
	
	NSRect backgroundRect = [self bounds];
	NSPoint startPoint	= NSMakePoint(NSMidX(backgroundRect), NSMinY(backgroundRect));
	NSPoint endPoint	= NSMakePoint(NSMidX(backgroundRect), NSMidY(backgroundRect));
	CGFloat startRadius = NSWidth(backgroundRect) * 0.1f;
	CGFloat endRadius	= NSWidth(backgroundRect) * 0.75f;
	
	[lighting drawFromCenter: startPoint radius: startRadius
					toCenter: endPoint radius: endRadius
					 options: NSGradientDrawsBeforeStartingLocation | NSGradientDrawsAfterEndingLocation];
	
	[lighting release];	
}


- (void) _drawShadowInRect: (NSRect)dirtyRect
{
	NSRect shadowRect = [self bounds];
	shadowRect.size.height = 6.0f;
	
	if (NSIntersectsRect(dirtyRect, shadowRect))
	{
		NSGradient *topShadow = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.2f]
															  endingColor: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.0f]];
		
		[topShadow drawInRect: shadowRect angle: 90.0f];
		[topShadow release];
	}
}

- (void) _drawBrandInRect: (NSRect)dirtyRect
{
	NSImage *brand = [NSImage imageNamed: @"Brand"];
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


- (void) _drawBlueprintBrandInRect: (NSRect)dirtyRect
{
	NSImage *brand = [NSImage imageNamed: @"BrandWatermark"];
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
		[self _drawBlueprintInRect: dirtyRect];
		[self _drawBlueprintBrandInRect: dirtyRect];
		[self _drawLightingInRect: dirtyRect];
		[self _drawShadowInRect: dirtyRect];
	}
	else
	{
		[self _drawBackgroundInRect: dirtyRect];
		[self _drawBrandInRect: dirtyRect];
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

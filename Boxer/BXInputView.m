/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXInputView.h"
#import "BXGeometry.h"
#import "NSView+BXDrawing.h"
#import "NSShadow+BXShadowExtensions.h"


@implementation BXInputView

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
	NSColor *backgroundColor = [NSColor colorWithCalibratedRed: 0.22f green: 0.235f blue: 0.24f alpha: 1.0f];
	NSGradient *background = [[NSGradient alloc] initWithColorsAndLocations:
							  [backgroundColor shadowWithLevel: 0.5f],	0.00f,
							  backgroundColor,							0.985f,
							  [backgroundColor shadowWithLevel: 0.3f],	1.00f,
							  nil];
	
	[background drawInRect: [self bounds] angle: 270.0f];
	[background release];
}

- (void) _drawBrandInRect: (NSRect)dirtyRect
{
	NSImage *brand = [NSImage imageNamed: @"Brand"];
	[brand setFlipped: YES];
	NSRect brandRegion;
	brandRegion.size = [brand size];
    
	brandRegion = NSIntegralRect(centerInRect(brandRegion, [self bounds]));
	
	if ([self needsToDrawRect: brandRegion])
	{
        NSShadow *brandShadow = [NSShadow shadowWithBlurRadius: 5.0f
                                                        offset: NSZeroSize
                                                         color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.25f]];
        [brandShadow set];
		[brand drawInRect: brandRegion
				 fromRect: NSZeroRect
				operation: NSCompositeSourceOver
				 fraction: 0.5f];	
	}
}

- (void) drawRect: (NSRect)dirtyRect
{
	[NSBezierPath clipRect: dirtyRect];
	
	[self _drawBackgroundInRect: dirtyRect];
	[self _drawBrandInRect: dirtyRect];
}

@end

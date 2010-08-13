/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXBlueprintPanel.h"


@implementation BXBlueprintPanel

- (NSPoint) _phaseForPattern: (NSImage *)pattern
{
	//Ensure the pattern is always centered horizontally in the view,
	//by adjusting its phase relative to the bottom-left window origin.
	NSRect panelFrame = [self frame];
	return NSMakePoint(panelFrame.origin.x + ((panelFrame.size.width - [pattern size].width) / 2),
					   panelFrame.origin.y);
}

- (void) _drawBlueprintInRect: (NSRect)dirtyRect
{
	NSColor *blueprintColor = [NSColor colorWithPatternImage: [NSImage imageNamed: @"Blueprint.jpg"]];
	NSPoint patternPhase	= [self _phaseForPattern: [blueprintColor patternImage]];
	
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
	NSPoint startPoint	= NSMakePoint(NSMidX(backgroundRect), NSMaxY(backgroundRect));
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
	//Draw a soft shadow beneath the titlebar
	NSRect shadowRect = [self bounds];
	shadowRect.origin.y += shadowRect.size.height - 6.0f;
	shadowRect.size.height = 6.0f;
	
	//Draw a 1-pixel groove at the bottom of the view
	NSRect grooveRect = [self bounds];
	grooveRect.size.height = 1.0f;
	
	if (NSIntersectsRect(dirtyRect, shadowRect))
	{
		NSGradient *topShadow = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.2f]
														   endingColor: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.0f]];
		
		[topShadow drawInRect: shadowRect angle: 270.0f];
		[topShadow release];
	}
	
	if (NSIntersectsRect(dirtyRect, grooveRect))
	{
		NSColor *grooveColor = [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.33f];
		[NSGraphicsContext saveGraphicsState];
			[grooveColor set];
			[NSBezierPath fillRect: grooveRect];
		[NSGraphicsContext restoreGraphicsState];
	}
}

- (void) drawRect: (NSRect)dirtyRect
{
	[NSBezierPath clipRect: dirtyRect];
	
	//First, fill the background with our pattern
	[self _drawBlueprintInRect: dirtyRect];

	//Then, draw the lighting onto the background
	[self _drawLightingInRect: dirtyRect];
	
	//Finally, draw the top and bottom shadows
	[self _drawShadowInRect: dirtyRect];
}

@end


@implementation BXBlueprintProgramPanel

- (NSPoint) _phaseForPattern: (NSImage *)pattern
{
	//Compensate for the program panels being nested in an offset superview
	NSRect panelFrame = [[self superview] frame];
	return NSMakePoint(panelFrame.origin.x + ((panelFrame.size.width - [pattern size].width) / 2),
					   panelFrame.origin.y);
}


- (void) _drawLightingInRect: (NSRect)dirtyRect
{
	NSGradient *lighting = [[NSGradient alloc] initWithColorsAndLocations:
							  [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.2f],	0.0f,
							  [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.1f],	0.9f,
							  [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.4f],	1.0f,
							  nil];
	
	[lighting drawInRect: [self bounds] angle: 90.0f];
	[lighting release];
}

- (void) drawRect: (NSRect)dirtyRect
{
	[NSBezierPath clipRect: dirtyRect];
	
	//First, fill the background with our pattern
	[self _drawBlueprintInRect: dirtyRect];
	
	//Then, draw the lighting onto the background
	[self _drawLightingInRect: dirtyRect];
}

@end

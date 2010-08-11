/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImportPanel.h"


@implementation BXImportPanel

- (void) _drawBlueprintInRect: (NSRect)dirtyRect
{
	NSColor *blueprintColor = [NSColor colorWithPatternImage: [NSImage imageNamed: @"Blueprint.jpg"]];

	//Ensure the pattern is always centered horizontally in the view by adjusting its phase relative to the bottom-left window origin.
	NSSize patternSize		= [[blueprintColor patternImage] size];
	NSRect panelFrame		= [self frame];
	NSPoint patternPhase	= NSMakePoint(panelFrame.origin.x + ((panelFrame.size.width - patternSize.width) / 2), 0.0f);
	
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

- (void) _drawGrooveInRect: (NSRect)dirtyRect
{
	NSRect highlightRect = [self bounds];
	highlightRect.size.height = 1.0f;
	
	NSRect shadowRect = highlightRect;
	shadowRect.origin.y += 1.0f;
		
	//Don't bother drawing the bevel if it's not dirty
	if (NSIntersectsRect(dirtyRect, highlightRect))
	{
		NSColor *bevelShadow	= [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.33f];
		NSColor *bevelHighlight	= [NSColor whiteColor];
	
		[NSGraphicsContext saveGraphicsState];
			[bevelHighlight set];
			[NSBezierPath fillRect: highlightRect];
			[bevelShadow set];
			[NSBezierPath fillRect: shadowRect];
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
	
	//Draw a bevel at the bottom of the view also
	[self _drawGrooveInRect: dirtyRect];
}

@end


@implementation BXImportProgramPanel

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

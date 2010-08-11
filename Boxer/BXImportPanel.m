/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImportPanel.h"


@implementation BXImportPanel

- (void) drawRect: (NSRect)dirtyRect
{
	[NSBezierPath clipRect: dirtyRect];
	
	NSGradient *lighting = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.2f]
														 endingColor: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.4f]];
	
	NSColor *blueprintColor = [NSColor colorWithPatternImage: [NSImage imageNamed: @"Blueprint.jpg"]];
	
	
	//Ensure the pattern is always centered horizontally in the view by adjusting its phase relative to the bottom-left window origin.
	NSSize patternSize		= [[blueprintColor patternImage] size];
	NSRect panelFrame		= [self frame];
	NSPoint patternPhase	= NSMakePoint(panelFrame.origin.x + ((panelFrame.size.width - patternSize.width) / 2), 0.0f);
	
	
	NSRect backgroundRect = [self bounds];
	NSRect highlightRect = [self bounds];
	highlightRect.size.height = 1.0f;
	
	NSRect shadowRect = highlightRect;
	shadowRect.origin.y += 1.0f;
	
	
	//First, fill the background with our pattern
	[NSGraphicsContext saveGraphicsState];
		[blueprintColor set];
		[[NSGraphicsContext currentContext] setPatternPhase: patternPhase];
		[NSBezierPath fillRect: backgroundRect];
	[NSGraphicsContext restoreGraphicsState];
	
	//Then, draw the lighting onto the background
	NSPoint startPoint	= NSMakePoint(NSMidX(backgroundRect), NSMaxY(backgroundRect));
	NSPoint endPoint	= NSMakePoint(NSMidX(backgroundRect), NSMidY(backgroundRect));
	CGFloat startRadius = NSWidth(backgroundRect) * 0.1f;
	CGFloat endRadius	= NSWidth(backgroundRect) * 0.75f;
	
	[lighting drawFromCenter: startPoint radius: startRadius
					toCenter: endPoint radius: endRadius
					 options: NSGradientDrawsBeforeStartingLocation | NSGradientDrawsAfterEndingLocation];
	
	[lighting release];
	
	//Draw a bevel at the bottom of the view also
	NSColor *bevelShadow	= [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.33f];
	NSColor *bevelHighlight	= [NSColor whiteColor];
	
	//Don't bother drawing the bevel if it's not dirty
	if (NSIntersectsRect(dirtyRect, highlightRect))
	{
		[NSGraphicsContext saveGraphicsState];
			[bevelHighlight set];
			[NSBezierPath fillRect: highlightRect];
			[bevelShadow set];
			[NSBezierPath fillRect: shadowRect];
		[NSGraphicsContext restoreGraphicsState];
	}
}

@end

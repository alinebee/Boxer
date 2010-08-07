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
	[blueprintColor set];
	
	NSRect backgroundRect = [self bounds];
	
	NSRect highlightRect = [self bounds];
	highlightRect.size.height = 1.0f;
	
	NSRect shadowRect = highlightRect;
	shadowRect.origin.y += 1.0f;
	
	//First, fill the background with our pattern
	[NSBezierPath fillRect: backgroundRect];
	
	//Then, draw the lighting onto the background
	NSPoint startPoint	= NSMakePoint(NSMidX(backgroundRect), NSMaxY(backgroundRect));
	NSPoint endPoint	= NSMakePoint(NSMidX(backgroundRect), NSMidY(backgroundRect));
	CGFloat startRadius = 40.0f;
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
		[bevelHighlight set];
		[NSBezierPath fillRect: highlightRect];
		[bevelShadow set];
		[NSBezierPath fillRect: shadowRect];
	}
}

@end

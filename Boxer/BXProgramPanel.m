/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXProgramPanel.h"
#import "NSView+BXDrawing.h"

@implementation BXProgramPanel

- (BOOL) isOpaque { return YES; }
- (BOOL) mouseDownCanMoveWindow { return YES; }

- (void) _drawGradientInRect: (NSRect)dirtyRect
{
	NSColor *backgroundColor = [NSColor grayColor]; 
	NSGradient *background = [[NSGradient alloc] initWithColorsAndLocations:
							  backgroundColor,							0.0f,
							  [backgroundColor shadowWithLevel: 0.25f],	0.9f,
							  [backgroundColor shadowWithLevel: 0.5f],	1.0f,
							  nil];
	
	[background drawInRect: [self bounds] angle: 90.0f];
	[background release];
}

- (void) _drawGrilleInRect: (NSRect)dirtyRect
{
	NSImage *grille		= [NSImage imageNamed: @"Grille.png"];
	NSSize patternSize	= [grille size];
	NSRect panelRegion	= [self bounds];
	
	//Next, calculate our top and bottom grille strips
	NSRect grilleStrip		= panelRegion;
	grilleStrip.size.height	= patternSize.height * 0.83f;	//Cut off the top of the grille slightly
	grilleStrip.origin.y	= panelRegion.size.height - grilleStrip.size.height;	//Align the grille along the top of the panel
	
	//Only bother drawing the grille if it intersects with the region being drawn
	if (NSIntersectsRect(grilleStrip, dirtyRect))
	{
		NSPoint patternOffset	= [self offsetFromWindowOrigin];
		NSPoint grillePhase		= NSMakePoint(patternOffset.x + ((panelRegion.size.width - patternSize.width) / 2),																patternOffset.y + grilleStrip.origin.y);
		
		NSBezierPath *grillePath	= [NSBezierPath bezierPathWithRect: grilleStrip];
		NSView *title				= [self viewWithTag: BXProgramPanelTitle];
		
		//If the panel has a visible title, then clip out a portion of the grille pattern to accommodate it.
		if (title && ![title isHidden])
		{
			NSRect titleMask		= [title frame];
			
			//Round the mask's width to increments of the pattern, so that we don't cut off half a hole in the grille.
			titleMask.size.width	= ceilf(titleMask.size.width / patternSize.width) * patternSize.width;
			titleMask.origin.x		= (panelRegion.size.width - titleMask.size.width) / 2;
			
			//Also reduce the mask's height so that it only masks areas within the strip.
			titleMask.size.height	= NSMaxY(titleMask) - grilleStrip.origin.y;
			titleMask.origin.y		= grilleStrip.origin.y;
			
			[grillePath appendBezierPathWithRect: titleMask];
			//The winding rules are a cheap way of subtracting the rect from our path, which only works in the simplest of cases.
			[grillePath setWindingRule: NSEvenOddWindingRule]; 
		}
		
		NSColor *grillePattern	= [NSColor colorWithPatternImage: grille];
		
		//Finally, draw the grille strip.
		[NSGraphicsContext saveGraphicsState];
		[grillePattern set];
		[[NSGraphicsContext currentContext] setPatternPhase: grillePhase];
		[grillePath fill];
		[NSGraphicsContext restoreGraphicsState];
	}	
}

- (void) drawRect: (NSRect)dirtyRect
{
	[NSBezierPath clipRect: dirtyRect];
	
	[self _drawGradientInRect: dirtyRect];
	[self _drawGrilleInRect: dirtyRect];
}
@end


@implementation BXProgramItemButton
@synthesize delegate;

- (id) representedObject
{
	return [[self delegate] representedObject];
}

- (void) viewWillDraw
{
	//If this item is enabled and the default, style the button differently.
	//TODO: move this into an initializer? Buttons are recreated whenever the default
	//program changes anyway.
	BOOL isDefault = [[[self representedObject] objectForKey: @"isDefault"] boolValue];
	[self setShowsBorderOnlyWhileMouseInside: !isDefault || ![self isEnabled]];
	
	[super viewWillDraw];
}
@end

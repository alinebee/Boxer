/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXProgramPanel.h"

//Interface Builder tags
enum {
	BXProgramPanelTitle			= 1,
	BXProgramPanelDefaultToggle	= 2,
	BXProgramPanelHide			= 3,
};


@implementation BXProgramPanel

- (BOOL) isOpaque { return YES; }
- (BOOL) mouseDownCanMoveWindow { return YES; }


- (void) drawRect: (NSRect)dirtyRect
{
	NSImage *grille			= [NSImage imageNamed: @"Grille.png"];
	NSSize patternSize		= [grille size];
	NSColor *grillePattern	= [NSColor colorWithPatternImage: grille];
	
	NSGradient *background = [[NSGradient alloc] initWithColorsAndLocations:
		[NSColor grayColor],		0.0,
		[NSColor darkGrayColor],	0.9,
		[NSColor colorWithCalibratedWhite: 0.25 alpha: 1.0],	0.97,
		[NSColor blackColor],		1.0,
	nil];

	NSRect panelRegion	= [self bounds];

	//NSColor pattern phase is relative to the bottom left corner of the *window*, not the bottom left corner
	//of the view's bounds, so we need to track our window-relative origin and add it to the pattern phase
	NSPoint panelOrigin	= [[self superview] frame].origin;
	
	//First, draw the background gradient
	[background drawInRect: panelRegion angle: 90];
	[background release];
	
	
	//Next, calculate our top and bottom grille strips
	NSRect bottomStrip		= panelRegion;
	bottomStrip.size.height	= patternSize.height * 0.75;	//Cut off the bottom of the grille slightly
	NSPoint bottomPhase		= NSMakePoint(
		((panelRegion.size.width - patternSize.width) / 2)	+ panelOrigin.x,	//Center the pattern horizontally
		(patternSize.height - bottomStrip.size.height)		+ panelOrigin.y		//Lock the pattern to the top of the grille strip
	);

	NSRect topStrip			= bottomStrip;
	NSPoint topPhase		= bottomPhase;
	topStrip.size.height	= patternSize.height * 0.85;	//Make this strip slightly taller than the bottom one
	topStrip.origin.y		= panelRegion.size.height - topStrip.size.height;
	topPhase.y				= topStrip.origin.y + panelOrigin.y;
	
	NSBezierPath *bottomPath	= [NSBezierPath bezierPathWithRect: bottomStrip];
	NSBezierPath *topPath		= [NSBezierPath bezierPathWithRect: topStrip];
	NSView *title				= [self viewWithTag: BXProgramPanelTitle];

	//If the panel has a visible title, then clip out a portion of the grille pattern to accommodate it.
	if (title && ![title isHidden])
	{
		NSRect titleMask		= [title frame];
		
		//Round the mask's width to increments of the pattern, so that we don't cut off half a hole in the grille.
		titleMask.size.width	= ceil(titleMask.size.width / patternSize.width) * patternSize.width;
		titleMask.origin.x		= (panelRegion.size.width - titleMask.size.width) / 2;
		
		//Also reduce the mask's height so that it only masks areas within the strip.
		titleMask.size.height	= NSMaxY(titleMask) - topStrip.origin.y;
		titleMask.origin.y		= topStrip.origin.y;
		
		[topPath appendBezierPathWithRect: titleMask];
		//The winding rules are a cheap way of subtracting the rect from our path, which only works in the simplest of cases.
		[topPath setWindingRule: NSEvenOddWindingRule]; 
	}
	
	//Finally, draw the grille strips.
	[NSGraphicsContext saveGraphicsState];
		[grillePattern set];

		//[[NSGraphicsContext currentContext] setPatternPhase: bottomPhase];
		//[bottomPath fill];
		
		[[NSGraphicsContext currentContext] setPatternPhase: topPhase];
		[topPath fill];
	[NSGraphicsContext restoreGraphicsState];
}
@end

@implementation BXProgramItemView
@synthesize delegate;

- (id) contents	{ return [[self subviews] lastObject]; }

//Customise how we want to align our contents within the collection view
- (void) viewWillDraw
{
	NSArray *siblings		= [[self superview] subviews];
	NSUInteger numSiblings	= [siblings count];
	NSUInteger ourIndex		= [siblings indexOfObject: self];
	//Todo: flip the index check when using 10.5, wherein NSCollectionViews populate themselves in reverse order.

	[[self contents] sizeToFit];
	
	//Decide how we should lay ourselves out:
	//Normally we'll center the button...
	CGFloat alignment = 0.5;	//centered
	
	//but if there's 2 or 3 programs then we want to align it left or right
	//depending on whether we're the first or last program...
	if (NO && (numSiblings == 2 || numSiblings == 3))
	{
		if		(ourIndex == 0)					alignment = 0.95;	//we're first: right-align
		else if	(ourIndex == numSiblings - 1)	alignment = 0.05;	//we're last; left-align
	}
	//...and if there's lots of programs then we want to left-align them all 
	else if (numSiblings > 5) alignment = 0.05;
	
	[self alignContentsToPosition: alignment];
	
	[super viewWillDraw];
}

- (void) alignContentsToPosition: (CGFloat)position
{
	NSRect frame	= [[self contents] frame];
	frame.origin.x	= ([self bounds].size.width - frame.size.width) * position;
	[[self contents] setFrame: NSIntegralRect(frame)];
}
@end


@implementation BXProgramButton
//- (BOOL) showsBorderOnlyWhileMouseInside { return YES; }
@end



@implementation BXProgramScroller
- (BOOL) isOpaque	{ return NO; }
- (void) drawRect: (NSRect)dirtyRect { [self drawKnob]; }

- (void) drawKnob
{
	NSRect regionRect = [self rectForPart: NSScrollerKnob];
	if (NSEqualRects(regionRect, NSZeroRect)) return;
	
	NSGradient *knobGradient = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 0.2 alpha: 1.0]
															 endingColor: [NSColor colorWithCalibratedWhite: 0.15 alpha: 1.0]
								];

	NSRect knobRect		= NSInsetRect(regionRect, 0.0, 3.0);
	CGFloat knobRadius	= knobRect.size.height / 2;
	NSBezierPath *knobPath = [NSBezierPath bezierPathWithRoundedRect: knobRect
															 xRadius: knobRadius
															 yRadius: knobRadius];
	
	[knobGradient drawInBezierPath: knobPath angle: 90];
}
@end
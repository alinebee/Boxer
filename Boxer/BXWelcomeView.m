/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXWelcomeView.h"
#import "BXGeometry.h"

@implementation BXWelcomeView

- (BOOL) isOpaque
{
	return YES;
}

- (void) drawRect: (NSRect)dirtyRect
{
	NSColor *blue	= [NSColor colorWithCalibratedRed: 0.22f green: 0.37f blue: 0.55f alpha: 1.0f];
	NSColor *black	= [NSColor blackColor];
	
	NSGradient *background = [[NSGradient alloc] initWithStartingColor: blue endingColor: black];
	
	//We set a particularly huge radius and offset to give a subtle curvature to the gradient
	CGFloat innerRadius = [self bounds].size.width * 1.5f;
	CGFloat outerRadius = innerRadius + ([self bounds].size.height * 0.55f);
	NSPoint center = NSMakePoint(NSMidX([self bounds]), ([self bounds].size.height * 0.05f) - innerRadius);
	
	[background drawFromCenter: center radius: innerRadius
					  toCenter: center radius: outerRadius
					   options: NSGradientDrawsBeforeStartingLocation | NSGradientDrawsAfterEndingLocation];
}

@end


@implementation BXWelcomeButton
@end

@implementation BXWelcomeButtonCell

- (BXWelcomeButton *) controlView
{
	return (BXWelcomeButton *)[super controlView];
}

- (void) awakeFromNib
{
	[self setShowsBorderOnlyWhileMouseInside: YES];
	[super awakeFromNib];
}

- (void) mouseEntered: (NSEvent *)event
{
	[self setHighlighted: YES];
}

- (void) mouseExited: (NSEvent *)event
{
	[self setHighlighted: NO];
}

- (void) setHighlighted: (BOOL)flag
{
	[[[self controlView] animator] setIllumination: (flag ? 1.0f : 0.0f)];
	[super setHighlighted: flag];
}

- (NSRect) titleRectForBounds: (NSRect)theRect
{
	//Position the title to occupy the bottom quarter of the button.
	theRect.origin.y = 72;
	return theRect;
}

- (NSFont *) _labelFont
{
	return [NSFont boldSystemFontOfSize: 0];
}

- (NSColor *) _textColor
{
	//Render the text in white if this button is highlighted; otherwise in translucent white
	if ([self isHighlighted])
		return [NSColor whiteColor];
	else
		[NSColor colorWithCalibratedWhite: 1.0f alpha: 0.75f];
}


- (void) _drawSpotlightWithFrame: (NSRect)frame inView: (NSView *)controlView withAlpha: (CGFloat)alpha
{
	NSImage *spotlight = [NSImage imageNamed: @"WelcomeSpotlight"];
	[spotlight setFlipped: [controlView isFlipped]];
	
	NSRect spotlightFrame;
	spotlightFrame.size = [spotlight size];
	spotlightFrame.origin.y = 32;
	
	[spotlight drawInRect: spotlightFrame
				 fromRect: NSZeroRect
				operation: NSCompositePlusLighter
				 fraction: alpha];
}

@end

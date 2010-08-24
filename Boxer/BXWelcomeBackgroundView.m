/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXWelcomeBackgroundView.h"


@implementation BXWelcomeBackgroundView

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
	CGFloat innerRadius = [self bounds].size.width * 3.0f;
	CGFloat outerRadius = innerRadius + ([self bounds].size.height * 0.55f);
	NSPoint center = NSMakePoint(NSMidX([self bounds]), ([self bounds].size.height * 0.05f) - innerRadius);
	
	[background drawFromCenter: center radius: innerRadius
					  toCenter: center radius: outerRadius
					   options: NSGradientDrawsBeforeStartingLocation | NSGradientDrawsAfterEndingLocation];
}

@end
/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXScroller.h"
#import "NSBezierPath+MCAdditions.h"

@implementation BXScroller
//Todo: is there an easier way to determine this?
- (BOOL) isVertical
{
	NSSize size = [self frame].size;
	return size.height > size.width;
}

- (BOOL) isOpaque	{ return NO; }

- (NSColor *)slotFill
{
	return [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.2];
}

- (NSShadow *)slotShadow
{
	NSShadow *slotShadow	= [[NSShadow new] autorelease];
	[slotShadow setShadowOffset: NSMakeSize(0, -1)];
	[slotShadow setShadowBlurRadius: 3];
	[slotShadow setShadowColor: [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.5]];

	return slotShadow; 
}

- (NSGradient *)knobGradient
{
	NSGradient *knobGradient = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 0.2 alpha: 1.0]
															 endingColor: [NSColor colorWithCalibratedWhite: 0.15 alpha: 1.0]
								];
	return [knobGradient autorelease];
}

- (void) drawRect: (NSRect)dirtyRect
{
	[self drawKnobSlotInRect: [self bounds] highlight: NO];
	[self drawKnob];
}

- (void) drawKnob
{
	NSRect regionRect = [self rectForPart: NSScrollerKnob];
	if (NSEqualRects(regionRect, NSZeroRect)) return;	
	
	NSRect knobRect;
	CGFloat knobRadius;
	CGFloat knobGradientAngle;
	NSGradient *knobGradient = [self knobGradient];
	
	if ([self isVertical])
	{
		knobRect			= NSInsetRect(regionRect, 3.0, 0.0);
		knobRadius			= knobRect.size.width / 2;
		knobGradientAngle	= 0;
	}
	else
	{
		knobRect			= NSInsetRect(regionRect, 0.0, 3.0);
		knobRadius			= knobRect.size.height / 2;
		knobGradientAngle	= 90;
	}

	NSBezierPath *knobPath = [NSBezierPath bezierPathWithRoundedRect: knobRect
															 xRadius: knobRadius
															 yRadius: knobRadius];
	
	[knobGradient drawInBezierPath: knobPath angle: knobGradientAngle];
}

- (void) drawKnobSlotInRect: (NSRect)regionRect highlight:(BOOL)flag
{
	if (NSEqualRects(regionRect, NSZeroRect)) return;
	
	NSColor *slotFill		= [self slotFill];
	NSShadow *slotShadow	= [self slotShadow];
	
	NSRect slotRect;
	CGFloat slotRadius;
	
	if ([self isVertical])
	{
		slotRect		= NSInsetRect(regionRect, 3.0, 4.0);
		slotRadius		= slotRect.size.width / 2;
	}
	else
	{
		slotRect		= NSInsetRect(regionRect, 4.0, 3.0);
		slotRadius		= slotRect.size.height / 2;
	}
	NSBezierPath *slotPath	= [NSBezierPath	bezierPathWithRoundedRect: slotRect
															 xRadius: slotRadius
															 yRadius: slotRadius];
	
	[slotFill set];
	[slotPath fill];
	[slotPath fillWithInnerShadow: slotShadow];
}
@end

@implementation BXHUDScroller

- (NSGradient *)knobGradient
{
	NSGradient *knobGradient = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 0.4 alpha: 1.0]
															 endingColor: [NSColor colorWithCalibratedWhite: 0.3 alpha: 1.0]
								];
	return [knobGradient autorelease];
}
@end
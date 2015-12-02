/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXScroller.h"
#import "NSBezierPath+MCAdditions.h"
#import "ADBForwardCompatibility.h"

@implementation BXScroller

+ (BOOL) isCompatibleWithOverlayScrollers
{
    return YES;
}

//Appearance properties
//---------------------

//Todo: is there an easier way to determine this?
- (BOOL) isVertical
{
	NSSize size = [self frame].size;
	return size.height > size.width;
}

- (NSSize) knobMargin
{
    if ([self respondsToSelector: @selector(scrollerStyle)] && [self scrollerStyle] == NSScrollerStyleOverlay)
    {
        return NSMakeSize(2.0f, 3.0f);
    }
    else
    {
        return NSMakeSize(4.0f, 3.0f);
    }
}

- (NSSize) slotMargin
{
    if ([self respondsToSelector: @selector(scrollerStyle)] && [self scrollerStyle] == NSScrollerStyleOverlay)
    {
        return NSMakeSize(1.0f, 2.0f);
    }
    else
    {
        return NSMakeSize(3.0f, 2.0f);
    }
}

- (NSColor *) slotFill
{
	return [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.1f];
}

- (NSShadow *) slotShadow
{
	NSShadow *slotShadow = [[NSShadow alloc] init];
	[slotShadow setShadowOffset: NSMakeSize(0.0f, -1.0f)];
	[slotShadow setShadowBlurRadius: 3];
	[slotShadow setShadowColor: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.5f]];
    
	return slotShadow;
}

- (NSColor *) knobStroke
{
    return [NSColor colorWithCalibratedWhite: 0.4f alpha: 1.0f];
}

- (NSGradient *) knobGradient
{
	NSGradient *knobGradient = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 0.6f alpha: 1.0f]
															 endingColor: [NSColor colorWithCalibratedWhite: 0.5f alpha: 1.0f]
								];
	return knobGradient;
}


//Draw methods
//------------

- (BOOL) isOpaque { return NO; }

- (void) drawRect: (NSRect)dirtyRect
{
    //On 10.7 and above, the regular NSScroller class should handle drawing
    if ([self respondsToSelector: @selector(scrollerStyle)])
    {
        [super drawRect: dirtyRect];
    }
    //On 10.6 and below, we wish to override drawing to avoid drawing the 'caps'
    //on the end of the standard scroller.
    else
    {
        [self drawKnobSlotInRect: [self rectForPart: NSScrollerKnobSlot] highlight: NO];
        [self drawKnob];
    }
}

- (void) drawKnob
{
	NSRect regionRect = [self rectForPart: NSScrollerKnob];
	if (NSEqualRects(regionRect, NSZeroRect)) return;	
	
	NSRect	knobRect;
	CGFloat	knobRadius;
	CGFloat	knobGradientAngle;
	NSGradient *knobGradient	= self.knobGradient;
    NSColor *knobStroke         = self.knobStroke;
	NSSize	knobMargin			= self.knobMargin;
	
	if ([self isVertical])
	{
		knobRect			= NSInsetRect(regionRect, knobMargin.width, knobMargin.height);
		knobRadius			= knobRect.size.width / 2;
		knobGradientAngle	= 0.0f;
	}
	else
	{
		knobRect			= NSInsetRect(regionRect, knobMargin.height, knobMargin.width);
		knobRadius			= knobRect.size.height / 2;
		knobGradientAngle	= 90.0f;
	}

	NSBezierPath *knobPath = [NSBezierPath bezierPathWithRoundedRect: knobRect
															 xRadius: knobRadius
															 yRadius: knobRadius];
    
    [[NSGraphicsContext currentContext] saveGraphicsState];
    [knobGradient drawInBezierPath: knobPath angle: knobGradientAngle];
    
    if (knobStroke)
    {
        NSBezierPath *strokePath = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(knobRect, -0.5f, -0.5f)
                                                                   xRadius: knobRadius + 0.5f
                                                                   yRadius: knobRadius + 0.5f];
        [knobStroke set];
        [strokePath stroke];
    }
    [[NSGraphicsContext currentContext] restoreGraphicsState];
    
}

- (void) drawKnobSlotInRect: (NSRect)regionRect highlight:(BOOL)flag
{
	if (NSEqualRects(regionRect, NSZeroRect)) return;
	
    NSColor *slotFill		= self.slotFill;
	NSShadow *slotShadow	= self.slotShadow;
	
	
	NSRect slotRect;
	CGFloat slotRadius;
	NSSize slotMargin = self.slotMargin;
	
	if (self.vertical)
	{	
		slotRect = NSInsetRect(regionRect, slotMargin.width, slotMargin.height);
		slotRadius = slotRect.size.width / 2;
	}
	else
	{
		slotRect = NSInsetRect(regionRect, slotMargin.height, slotMargin.width);
		slotRadius = slotRect.size.height / 2;
	}
	
	NSBezierPath *slotPath = [NSBezierPath bezierPathWithRoundedRect: slotRect
                                                             xRadius: slotRadius
                                                             yRadius: slotRadius];
	
    
    [[NSGraphicsContext currentContext] saveGraphicsState];
        [slotFill set];
        [slotPath fill];
        [slotPath fillWithInnerShadow: slotShadow];
    [[NSGraphicsContext currentContext] restoreGraphicsState];
}
@end


@implementation BXHUDScroller

- (NSSize) knobMargin
{
    if ([self respondsToSelector: @selector(scrollerStyle)] && [self scrollerStyle] == NSScrollerStyleOverlay)
    {
        return NSMakeSize(2.0f, 2.0f);
    }
    else
    {
        return NSMakeSize(5.0f, 1.0f);
    }
}

- (NSSize) slotMargin
{
    if ([self respondsToSelector: @selector(scrollerStyle)] && [self scrollerStyle] == NSScrollerStyleOverlay)
    {
        return NSMakeSize(1.0f, 1.0f);
    }
    else
    {
        return NSMakeSize(4.0f, 0.0f);
    }
}

- (NSColor *) knobStroke
{
    return [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.5f];
}

- (NSGradient *)knobGradient
{
	NSGradient *knobGradient = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 0.5f alpha: 1.0f]
															 endingColor: [NSColor colorWithCalibratedWhite: 0.4f alpha: 1.0f]
								];
	return knobGradient;
}

@end

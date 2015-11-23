/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXThemedSliderCell.h"
#import "NSBezierPath+MCAdditions.h"
#import "BXThemes.h"
#import "NSView+ADBDrawingHelpers.h"

@implementation BXThemedSliderCell

#pragma mark - Default theme handling

- (id) initWithCoder: (NSCoder *)coder
{
    self = [super initWithCoder: coder];
    if (self)
    {
        if (![coder containsValueForKey: @"themeKey"])
            self.themeKey = [self.class defaultThemeKey];
    }
    return self;
}



- (NSRect) roundKnobRectInBounds: (NSRect)theRect
{
    NSRect knobRect = theRect;
    switch (self.controlSize)
    {
		case NSRegularControlSize:
            knobRect.origin.x += 3;
            knobRect.origin.y += 3;
            knobRect.size.height = 15;
            knobRect.size.width = 15;
			break;
			
		case NSSmallControlSize:
            knobRect.origin.x += 1;
            knobRect.origin.y += 1;
            knobRect.size.height = 13;
            knobRect.size.width = 13;
			break;
			
		case NSMiniControlSize:
            knobRect.origin.x += 2;
            knobRect.origin.y += 1;
            knobRect.size.height = 9;
            knobRect.size.width = 9;
			break;
	}
    return knobRect;
}

- (NSRect) horizontalKnobRectInBounds: (NSRect)theRect
                     tickMarkPosition: (NSTickMarkPosition)tickPosition
{
    NSRect knobRect = theRect;
	switch (self.controlSize)
    {
		case NSRegularControlSize:
            if (tickPosition == NSTickMarkAbove)
                knobRect.origin.y += 2;
            
            knobRect.origin.x += 2;
            knobRect.size.height = 19;
            knobRect.size.width = 15;
			break;
			
		case NSSmallControlSize:
            if (tickPosition == NSTickMarkAbove)
                knobRect.origin.y += 1;
            
            knobRect.origin.x += 1;
            knobRect.size.height = 13;
            knobRect.size.width = 11;
			break;
			
		case NSMiniControlSize:
            knobRect.origin.x += 1;
            knobRect.size.height = 11;
            knobRect.size.width = 9;
			break;
	}
    return knobRect;
}

- (NSBezierPath *) horizontalKnobForRect: (NSRect)theRect
                        tickMarkPosition: (NSTickMarkPosition)tickPosition
{
    NSBezierPath *knob = [[NSBezierPath alloc] init];
    
    CGFloat minX = NSMinX(theRect), midX = NSMidX(theRect), maxX = NSMaxX(theRect);
    CGFloat minY = NSMinY(theRect), midY = NSMidY(theRect), maxY = NSMaxY(theRect);
    
    NSPoint points[7] = {
        NSMakePoint(minX + 2,    minY),
        NSMakePoint(maxX - 2,    minY),
        NSMakePoint(maxX,        minY + 2),
        NSMakePoint(maxX,        midY + 2),
        NSMakePoint(midX,        maxY),
        NSMakePoint(minX,        midY + 2),
        NSMakePoint(minX,        minY + 2)
    };
	
    [knob appendBezierPathWithPoints: points count: 7];
    [knob closePath];
    
    //Flip the knob
    if (tickPosition == NSTickMarkAbove)
    {
        NSAffineTransform *transform = [NSAffineTransform transform];
        [transform scaleXBy: 1 yBy: -1];
        //The path will be flipped along its topmost edge:
        //move it back down to where it should be
        [transform translateXBy: 0 yBy: -maxY - minY];
        [knob transformUsingAffineTransform: transform];
    }
    
    return knob;
}

- (NSBezierPath *) roundKnobForRect: (NSRect)theRect
{
    return [NSBezierPath bezierPathWithOvalInRect: theRect];
}

- (void) drawHorizontalKnobInFrame: (NSRect)frame
{
    BGTheme *theme = [[BGThemeManager keyedManager] themeForKey: self.themeKey];
    
	NSRect knobRect;
    NSBezierPath *knob;
    if ([self numberOfTickMarks] > 0)
    {
        knobRect = [self horizontalKnobRectInBounds: frame
                                   tickMarkPosition: self.tickMarkPosition];
        
        knob = [self horizontalKnobForRect: knobRect
                          tickMarkPosition: self.tickMarkPosition];
    }
    else
    {
        knobRect = [self roundKnobRectInBounds: frame];
        knob = [self roundKnobForRect: knobRect];
    }
	
    NSGradient *knobFill;
    NSColor *knobStroke;
    NSShadow *knobShadow;
    
    if (self.isHighlighted)
    {
        if (self.focusRingType != NSFocusRingTypeNone && theme.focusRing) 
            knobShadow = theme.focusRing;
        else
            knobShadow = theme.sliderKnobShadow;
        
        knobStroke = theme.sliderKnobStrokeColor;
        knobFill = theme.highlightKnobColor;
    }
	else if (self.isEnabled && self.controlView.windowIsActive)
    {
        knobShadow = theme.sliderKnobShadow;
        knobStroke = theme.sliderKnobStrokeColor;
        knobFill = theme.knobColor;
    }
    else
    {
        knobFill = theme.disabledKnobColor;
        knobStroke = theme.disabledSliderKnobStrokeColor;
        knobShadow = nil;
    }
    
    [NSGraphicsContext saveGraphicsState];
        [knobShadow set];
        [knobStroke set];
        [knob fill];
    [NSGraphicsContext restoreGraphicsState];
    
    [knobFill drawInBezierPath: knob angle: theme.gradientAngle];
    
    [NSGraphicsContext saveGraphicsState];
        [knobStroke set];
        [knob strokeInside];
    [NSGraphicsContext restoreGraphicsState];
}

- (NSRect) rectOfHorizontalBarInBounds: (NSRect)theRect
{
    NSRect barRect = theRect;
    switch (self.controlSize)
    {
		case NSRegularControlSize:
			if (self.numberOfTickMarks > 0)
            {	
				if (self.tickMarkPosition == NSTickMarkBelow)
					barRect.origin.y += 4;
                else
					barRect.origin.y += barRect.size.height - 10;
			}
            else
            {
				barRect.origin.y += ((barRect.origin.y + barRect.size.height) / 2) - 2.5f;
			}
			
            barRect.origin.x += 2;
            barRect.size.width -= 4;
			barRect.size.height = 5;
			break;
			
		case NSSmallControlSize:
			if (self.numberOfTickMarks > 0)
            {
				if (self.tickMarkPosition == NSTickMarkBelow)
					barRect.origin.y += 2;
                else
					barRect.origin.y += barRect.size.height - 8;
			}
            else
            {
				barRect.origin.y += ((barRect.origin.y + barRect.size.height) / 2) - 2.5f;
			}
			
            barRect.origin.x += 1;
            barRect.size.width -= 2;
			barRect.size.height = 5;
			break;
			
		case NSMiniControlSize:
			if (self.numberOfTickMarks > 0)
            {
				if (self.tickMarkPosition == NSTickMarkBelow)
					barRect.origin.y += 2;
                else
					barRect.origin.y += barRect.size.height - 6;
			} else {
				
				barRect.origin.y += ((barRect.origin.y + barRect.size.height) / 2) - 2;
			}
			
			barRect.size.height = 3;
			break;
	}
    return barRect;
}

- (NSBezierPath *) horizontalBarForRect: (NSRect)rect
{
	return [NSBezierPath bezierPathWithRoundedRect: rect xRadius: 2 yRadius: 2];
}

- (void) drawHorizontalBarInFrame: (NSRect)frame
{
    BGTheme *theme = [[BGThemeManager keyedManager] themeForKey: self.themeKey];
    
    NSRect fillRect = [self rectOfHorizontalBarInBounds: frame];
    NSRect strokeRect = NSInsetRect(fillRect, 0.5f, 0.5f);
    NSBezierPath *fillPath = [self horizontalBarForRect: fillRect];
    NSBezierPath *strokePath = [self horizontalBarForRect: strokeRect];
    
    NSColor *strokeColor, *fillColor;
	if (self.isEnabled && self.controlView.windowIsActive)
    {
        fillColor = theme.sliderTrackColor;
        strokeColor = theme.sliderTrackStrokeColor;
	}
    else
    {
        fillColor = theme.disabledSliderTrackColor;
        strokeColor = theme.disabledStrokeColor;
	}
    
    [[NSGraphicsContext currentContext] saveGraphicsState];
        [fillColor set];
        [theme.sliderTrackShadow set];
        [fillPath fill];
    [[NSGraphicsContext currentContext] restoreGraphicsState];
    
    NSShadow *innerShadow = theme.sliderTrackInnerShadow;
    if (innerShadow)
        [fillPath fillWithInnerShadow: innerShadow];
    
    [strokeColor set];
    [strokePath stroke];
}

@end
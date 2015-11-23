/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXHUDLevelIndicatorCell.h"
#import "NSShadow+ADBShadowExtensions.h"


@implementation BXHUDLevelIndicatorCell
@synthesize indicatorShadow, indicatorColor;

+ (CGFloat) heightForControlSize: (NSControlSize)size
{
    switch (size)
    {
        case NSMiniControlSize:
            return 10.0f;
            
        case NSSmallControlSize:
            return 12.0f;
            
        case NSRegularControlSize:
        default:
            return 14.0f;
    }
}

- (void) awakeFromNib
{
	if (!self.indicatorColor)
	{
		self.indicatorColor = [NSColor whiteColor];
	}
	
	if (!self.indicatorShadow)
	{
		NSShadow *theShadow = [NSShadow shadowWithBlurRadius: 3.0f
                                                      offset: NSMakeSize(0.0f, -1.0f)];
		self.indicatorShadow = theShadow;
	}
}

- (NSRect) drawingRectForBounds: (NSRect)theRect
{
    NSRect drawingRect = [super drawingRectForBounds: theRect];
    if (self.indicatorShadow)
    {
        //If we have a shadow set, then constrain the draw region to accomodate the shadow
        drawingRect = [self.indicatorShadow insetRectForShadow: drawingRect
                                                       flipped: self.controlView.isFlipped];
    }
    return drawingRect;
}

- (void) drawWithFrame: (NSRect)cellFrame
                inView: (NSView *)controlView
{
    NSRect indicatorFrame = NSIntegralRect([self drawingRectForBounds: cellFrame]);
    CGFloat maxHeight = indicatorFrame.size.height;
    CGFloat height = MIN(maxHeight, [[self class] heightForControlSize: self.controlSize]);
    
    //Center the indicator vertically in the available space
    indicatorFrame.origin.y += (maxHeight - height) / 2.0f;
    indicatorFrame.size.height = height;
    
    NSRect borderRect       = NSInsetRect(indicatorFrame, 1.0f, 1.0f);
    NSRect levelRect        = NSInsetRect(indicatorFrame, 4.0f, 4.0f);
    
    CGFloat borderRadius    = borderRect.size.height / 2.0f;
    CGFloat levelRadius     = levelRect.size.height / 2.0f;
    
    NSBezierPath *borderPath = [NSBezierPath bezierPathWithRoundedRect: borderRect
                                                               xRadius: borderRadius
                                                               yRadius: borderRadius];
    [borderPath setLineWidth: 2.0f];
    
    
    NSBezierPath *levelPath = [NSBezierPath bezierPathWithRoundedRect: levelRect
                                                              xRadius: levelRadius
                                                              yRadius: levelRadius];
    
    //Work out how full the meter should be, and calculate from that how much of the path to draw
    double level = (self.doubleValue - self.minValue) / (self.maxValue - self.minValue);
    NSRect levelClip = levelRect;
    levelClip.size.width *= (float)level;
    levelClip = NSIntegralRect(levelClip);
    
    
    [NSGraphicsContext saveGraphicsState];
        [self.indicatorColor set];
        [self.indicatorShadow set];
        
        NSUInteger i, numTicks = self.numberOfTickMarks;
        if (numTicks > 0)
        {
            for (i = 1; i < numTicks - 1; i++)
            {
                CGFloat tickPosition = (i / (CGFloat)(numTicks - 1));
                CGFloat xOffset = (levelRect.size.width * tickPosition);
                
                NSRect tickRect = NSMakeRect(levelRect.origin.x + xOffset,
                                             levelRect.origin.y,
                                             1.0f,
                                             levelRect.size.height);
                tickRect = NSIntegralRect(tickRect);
                tickRect.size.width = 1.0f;
                
                [NSBezierPath fillRect: tickRect];
            }
        }
        [borderPath stroke];
        
        [NSBezierPath clipRect: levelClip];
        [levelPath fill];
    [NSGraphicsContext restoreGraphicsState];
}

@end
/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXHUDControls.h"
#import "BXGeometry.h"
#import "NSShadow+BXShadowExtensions.h"
#import "NSBezierPath+MCAdditions.h"


#define BXBezelBorderRadius 20.0f


@implementation BXHUDLabel

- (NSString *)themeKey { return @"BXBlueTheme"; }

//Fixes a BGHUDLabel/NSTextField bug where toggling enabledness
//won't cause a redraw.
- (void) setEnabled: (BOOL)flag
{
    [super setEnabled: flag];
    //NOTE: calling setNeedsDisplay: doesn't help; only actually
    //touching the value seems to force a redraw.
    [self setStringValue: [self stringValue]];
}
@end


@implementation BXHUDProgressIndicator

- (BOOL) isOpaque
{
    return NO;
}

- (BOOL) isBezeled
{
    return NO;
}

- (NSBezierPath *) stripePathForFrame: (NSRect)frame
                        animationTime: (NSTimeInterval)timeInterval
{
    CGFloat stripeWidth = frame.size.height;
    
    //Expand the frame so that our stripe will be unbroken.
    frame.size.width += (stripeWidth * 4);
    frame.origin.x -= (stripeWidth * 2);
    
    NSPoint offset = frame.origin;
    
    //Choose the starting offset based on our animation time: we complete
    //one full cycle of the stripes in a second.
    //TODO: abstract this calculation and allow it to have arbitrary timing.
    double ms = (long long)(timeInterval * 1000) % 1000;
    float animationProgress = (float)(ms / 1000);
    offset.x += (stripeWidth * 2 * animationProgress);
    
    //Now, walk across the frame drawing parallelograms!
    NSBezierPath *stripePath = [[NSBezierPath alloc] init];
    
    while(offset.x <= NSMaxX(frame))
    {
        [stripePath moveToPoint: offset];
        [stripePath lineToPoint: NSMakePoint(offset.x + stripeWidth,          offset.y)];
        [stripePath lineToPoint: NSMakePoint(offset.x + (stripeWidth * 2),    offset.y + stripeWidth)];
        [stripePath lineToPoint: NSMakePoint(offset.x + stripeWidth,          offset.y + stripeWidth)];
        [stripePath closePath];
        
        offset.x += (stripeWidth * 2);
    }
    
    return [stripePath autorelease];
}

- (void) drawRect: (NSRect)dirtyRect
{
    NSColor *strokeColor = [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.5f];
    NSColor *fillColor = [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.25f];
    
    NSShadow *fillShadow = [NSShadow shadowWithBlurRadius: 2.0f offset: NSMakeSize(0.0f, -1.0f)];
    
    NSRect canvas           = NSIntegralRect([self bounds]);
    NSRect fillRegion       = NSInsetRect(canvas, 1.0f, 1.0f);
    NSRect strokeRegion     = NSInsetRect(canvas, 0.5f, 0.5f);
    
    NSBezierPath *fillPath = [NSBezierPath bezierPathWithRoundedRect: fillRegion
                                                             xRadius: fillRegion.size.height / 2
                                                             yRadius: fillRegion.size.height / 2];
    
    NSBezierPath *strokePath = [NSBezierPath bezierPathWithRoundedRect: strokeRegion
                                                               xRadius: strokeRegion.size.height / 2
                                                               yRadius: strokeRegion.size.height / 2];
    
    NSRect progressRegion = NSInsetRect(canvas, 2.0f, 2.0f);
    NSBezierPath *progressPath = [NSBezierPath bezierPathWithRoundedRect: progressRegion
                                                                 xRadius: progressRegion.size.height / 2
                                                                 yRadius: progressRegion.size.height / 2];
    
    [NSGraphicsContext saveGraphicsState];
        [strokeColor setStroke];
        [fillColor setFill];
    
        [fillPath fill];
        [fillPath fillWithInnerShadow: fillShadow];
        [strokePath stroke];
    [NSGraphicsContext restoreGraphicsState];
    
    
    if ([self isIndeterminate])
    {
        NSColor *stripeColor = [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.25f];
		NSGradient *progressGradient = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.5f]
                                                                     endingColor: [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.25f]];
        
        NSBezierPath *stripePath = [self stripePathForFrame: progressRegion
                                              animationTime: [NSDate timeIntervalSinceReferenceDate]];
        
        [NSGraphicsContext saveGraphicsState];
            [progressGradient drawInBezierPath: progressPath
                                         angle: 90.0f];
        
            [progressPath addClip];
            [stripeColor setFill];
            [stripePath fill];
        [NSGraphicsContext restoreGraphicsState];
    }
    else
    {
        NSGradient *progressGradient = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 1.0f alpha: 1.0f]
                                                                     endingColor: [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.66f]];
        
        //Work out how full the progress bar should be, and calculate from that how much of the path to draw
		double progress = ([self doubleValue] - [self minValue]) / ([self maxValue] - [self minValue]);
        
        NSRect progressClip = progressRegion;
        progressClip.size.width *= (float)progress;
        progressClip = NSIntegralRect(progressClip);
        
        [NSGraphicsContext saveGraphicsState];
            [NSBezierPath clipRect: progressClip];
            
            [progressGradient drawInBezierPath: progressPath
                                         angle: 90.0f];
            
            //[progressPath fillWithInnerShadow: progressGlow];
        [NSGraphicsContext restoreGraphicsState];
        
        [progressGradient release];
    }
}

- (void) performAnimation: (NSTimer*)timer
{
    [self setNeedsDisplay: YES];
}

- (void) startAnimation: (id)sender
{
    if (!animationTimer)
    {
        animationTimer = [NSTimer scheduledTimerWithTimeInterval: 5.0/60.0
                                                          target: self
                                                        selector: @selector(performAnimation:)
                                                        userInfo: nil
                                                         repeats: YES];
        [animationTimer retain];
    }
}

- (void) stopAnimation: (id)sender
{
    if (animationTimer)
    {
        [animationTimer invalidate];
        [animationTimer release];
        animationTimer = nil;
    }
}

- (void) viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    
    if (![self window])
        [self stopAnimation: self];
}

- (void) dealloc
{
    if (animationTimer)
        [self stopAnimation: self];
    
    [super dealloc];
}

@end



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

- (void) dealloc
{
	[self setIndicatorColor: nil], [indicatorColor release];
	[self setIndicatorShadow: nil], [indicatorShadow release];
	
	[super dealloc];
}

- (void) awakeFromNib
{
	if (![self indicatorColor])
	{
		[self setIndicatorColor: [NSColor whiteColor]];
	}
	
	if (![self indicatorShadow])
	{
		NSShadow *theShadow = [NSShadow shadowWithBlurRadius: 3.0f
                                                      offset: NSMakeSize(0.0f, -1.0f)];
		[self setIndicatorShadow: theShadow];
	}
}

- (NSRect) drawingRectForBounds: (NSRect)theRect
{
    NSRect drawingRect = [super drawingRectForBounds: theRect];
    if ([self indicatorShadow])
    {
        //If we have a shadow set, then constrain the draw region to accomodate the shadow
        drawingRect = [[self indicatorShadow] insetRectForShadow: drawingRect];
    }
    return drawingRect;
}

- (void) drawWithFrame: (NSRect)cellFrame
                inView: (NSView *)controlView
{
    NSRect indicatorFrame = NSIntegralRect([self drawingRectForBounds: cellFrame]);
    CGFloat maxHeight = indicatorFrame.size.height;
    CGFloat height = MIN(maxHeight, [[self class] heightForControlSize: [self controlSize]]);
    
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
    double level = ([self doubleValue] - [self minValue]) / ([self maxValue] - [self minValue]);
    NSRect levelClip = levelRect;
    levelClip.size.width *= (float)level;
    levelClip = NSIntegralRect(levelClip);
    
    
    [NSGraphicsContext saveGraphicsState];
        [[self indicatorColor] set];
        [[self indicatorShadow] set];
    
        NSUInteger i, numTicks = [self numberOfTickMarks];
        for (i = 1; i < numTicks - 1; i++)
        {
            CGFloat tickPosition = (i / (CGFloat)(numTicks - 1));
            CGFloat xOffset = (levelRect.size.width * tickPosition);
            
            NSRect tickRect = NSMakeRect(levelRect.origin.x + xOffset, levelRect.origin.y, 1.0f, levelRect.size.height);
            tickRect = NSIntegralRect(tickRect);
            tickRect.size.width = 1.0f;
            
            [NSBezierPath fillRect: tickRect];
        }
        
        [borderPath stroke];
        
        [NSBezierPath clipRect: levelClip];
        [levelPath fill];
    [NSGraphicsContext restoreGraphicsState];
}

@end


@implementation BXBezelView

- (void) drawRect: (NSRect)dirtyRect
{
    NSBezierPath *background = [NSBezierPath bezierPathWithRoundedRect: [self bounds]
                                                               xRadius: BXBezelBorderRadius
                                                               yRadius: BXBezelBorderRadius];
    
    NSColor *backgroundColor = [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.5f];
    
    [NSGraphicsContext saveGraphicsState];
        [backgroundColor set];
        [background fill];
    [NSGraphicsContext restoreGraphicsState];
}
@end

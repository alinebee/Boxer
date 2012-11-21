/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXThemedSegmentedCell.h"
#import "NSImage+BXImageEffects.h"
#import "NSShadow+BXShadowExtensions.h"
#import "BXGeometry.h"

//Most of this is copypasta from BGHUDSegmentedCell, because of its monolithic draw functions.

@interface NSSegmentedCell ()
- (NSRect) rectForSegment: (NSInteger)segment inFrame: (NSRect)frame;
@end

@implementation BXThemedSegmentedCell

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


- (BOOL) isHighlightedForSegment: (NSInteger)segment
{
	BOOL isHighlighted;
	//In momentary tracking, we should only look at the currently-reported selected segment...
	if ([self trackingMode] == NSSegmentSwitchTrackingMomentary)
        isHighlighted = ([self selectedSegment] == segment);
	//...for other tracking modes, check if the segment is reported as selected.
	else
        isHighlighted = [self isSelectedForSegment: segment];
    
    return isHighlighted;
}


- (NSRect) drawingRectForBounds: (NSRect)theRect
{
    NSShadow *theShadow = [[[BGThemeManager keyedManager] themeForKey: self.themeKey] dropShadow];
    if (theShadow)
    {
        return [theShadow insetRectForShadow: theRect
                                     flipped: [[self controlView] isFlipped]];
    }
    else return theRect;
}

- (NSRect) rectForSegment: (NSInteger)segment
                  inFrame: (NSRect)frame
{
    NSRect segmentRect = [super rectForSegment: segment inFrame: frame];
    
	//rectForSegment will return too wide a value for the final segment
    //for some reason, so we need to crop it to the actual view frame.
    return NSIntersectionRect(segmentRect, frame);
}

- (NSRect) interiorRectForSegment: (NSInteger)segment inFrame: (NSRect)frame
{
    //Give the interior a suitable margin, allowing a little extra for the rounded corners
    NSRect interiorRect = NSInsetRect(frame, 3.0f, 3.0f);
    if (segment == 0)
    {
        interiorRect.origin.x += 2;
        interiorRect.size.width -= 2;
    }
    else if (segment == [self segmentCount] - 1)
    {
        interiorRect.size.width -= 2;
    }
    return interiorRect;
}

- (NSBezierPath *) bezelForFrame: (NSRect)frame
{
    NSBezierPath *bezel = [[NSBezierPath alloc] init];
    [bezel setLineWidth: 1.0f];
    //So that lines are drawn as sharp pixels
    NSRect insetFrame = NSInsetRect(NSIntegralRect(frame), 0.5f, 0.5f);
	
	switch ([self segmentStyle])
    {
		case NSSegmentStyleRounded:
            {
                CGFloat cornerRadius = insetFrame.size.height / 2;
                [bezel appendBezierPathWithRoundedRect: insetFrame
                                               xRadius: cornerRadius
                                               yRadius: cornerRadius];
            }
			break;
            
		case NSSegmentStyleSmallSquare:
        default:
			[bezel appendBezierPathWithRect: insetFrame];
			break;
	}
    return [bezel autorelease];
}

- (NSBezierPath *) bezelForSegment: (NSInteger)segment inFrame: (NSRect)frame
{
    NSBezierPath *bezel = [[NSBezierPath alloc] init];
	
	switch ([self segmentStyle])
    {
		case NSSegmentStyleRounded:
            //If this is the first or last segment, draw rounded corners
            if (segment == 0 || segment == [self segmentCount] - 1)
            {
                CGFloat cornerRadius = frame.size.height / 2;
                [bezel appendBezierPathWithRoundedRect: frame
                                               xRadius: cornerRadius
                                               yRadius: cornerRadius];
                
                //Fill in the inner rounded edges so they're square again 
                NSRect cornerFill = frame;
                cornerFill.size.width = cornerRadius;
                if (segment == 0)
                    cornerFill.origin.x = NSMaxX(frame) - cornerRadius;
                
                [bezel appendBezierPathWithRect: cornerFill];
            }
            else
            {
                [bezel appendBezierPathWithRect: frame];
            }
			break;
            
        case NSSegmentStyleSmallSquare:
		default:
			[bezel appendBezierPathWithRect: frame];
			
			break;
	}
    
    return [bezel autorelease];
}

- (void) drawWithFrame: (NSRect)frame
                inView: (NSView *)view
{
    NSRect drawingRect = [self drawingRectForBounds: frame];
    
	NSBezierPath *bezel = [self bezelForFrame: drawingRect];
	BGTheme *theme = [[BGThemeManager keyedManager] themeForKey: self.themeKey];
    
    //First draw the bezel shadow
	[NSGraphicsContext saveGraphicsState];
        [[theme dropShadow] set];
        [[theme darkStrokeColor] set];
        [bezel stroke];
	[NSGraphicsContext restoreGraphicsState];
	
    //Then draw the individual segments
	NSInteger i;
    for (i = 0; i < [self segmentCount]; i++)
    	[self drawSegment: i inFrame: drawingRect withView: view];
    
    //Then finally draw the border on top
	[NSGraphicsContext saveGraphicsState];
        [[theme strokeColor] set];
        [bezel stroke];
	[NSGraphicsContext restoreGraphicsState];
}

- (void) drawSegment: (NSInteger)segment
             inFrame: (NSRect)frame
            withView: (NSView *)view
{
	BGTheme *theme = [[BGThemeManager keyedManager] themeForKey: self.themeKey];
    
    BOOL isHighlighted = [self isHighlightedForSegment: segment];
    BOOL precedesHighlighted = (segment != [self segmentCount] - 1) && [self isHighlightedForSegment: segment + 1];
    
	NSRect segmentRect = [self rectForSegment: segment inFrame: frame];
    NSRect fillRect = segmentRect;
    
    //Make the highlighted segment overlap its neighbours, and the segment
    //before it stop short by one pixel, so that the highlighted segment
    //dividers can be drawn over the top.
    if (isHighlighted && segment > 0)
    {
        fillRect.origin.x -= 1;
        fillRect.size.width += 1;
    }
    else if (precedesHighlighted)
    {
        fillRect.size.width -= 1;
    }
    
    NSBezierPath *bezel = [self bezelForSegment: segment inFrame: fillRect];
	
	//Fill the segment.
    NSGradient *bezelGradient = (isHighlighted) ? [theme highlightGradient] : [theme normalGradient];
    [bezelGradient drawInBezierPath: bezel angle: [theme gradientAngle]];
	
	//Draw segment divider(s).
	[NSGraphicsContext saveGraphicsState];
		[[theme strokeColor] set];
        
        NSRect dividerRect = fillRect;
        dividerRect.size.width = 1;
    
        //Draw a partial-height divider, unless this is a highlighted cell.
        if (!isHighlighted)
        {
            dividerRect = NSInsetRect(dividerRect, 0, 3.0f);
        }
        
        //If this cell is highlighted and not the leftmost cell,
        //draw a divider to the left.
        if (isHighlighted && segment > 0)
            [NSBezierPath fillRect: dividerRect];
        
        //If this cell isn't followed by a highlighted cell,
        //and is not the rightmost cell, draw a divider to the right.
        if ((segment != [self segmentCount] - 1) && !precedesHighlighted)
        {
            dividerRect.origin.x = NSMaxX(fillRect) - 1;
            [NSBezierPath fillRect: dividerRect];
        }
	[NSGraphicsContext restoreGraphicsState];
	
	[self drawInteriorForSegment: segment inFrame: segmentRect withView: view];
}

- (void) drawInteriorForSegment: (NSInteger)segment
                        inFrame: (NSRect)frame
                       withView: (NSView *)view
{
	NSRect innerRect = [self interiorRectForSegment: segment inFrame: frame];
	
    //First, draw the image
    NSRect imageRect = [self drawImageForSegment: segment
                                         inFrame: innerRect
                                        withView: view];
    
    //Shorten the region we use for drawing text to account for the image
    if (!NSIsEmptyRect(imageRect))
    {
        CGFloat margin = NSMaxX(imageRect) + 3;
        innerRect.origin.x += margin;
        innerRect.size.width -= margin;
    }

    [self drawTitleForSegment: segment inFrame: innerRect withView: view];
}

- (NSRect) drawImageForSegment: (NSInteger)segment
                       inFrame: (NSRect)frame
                      withView: (NSView *)view
{
    BGTheme *theme = [[BGThemeManager keyedManager] themeForKey: self.themeKey];
    BOOL isEnabled = [self isEnabledForSegment: segment];
    
    NSImage *image = [self imageForSegment: segment];
    NSRect imageRect = NSZeroRect;
    
    if (image)
    {
        BOOL hasLabel = [[self labelForSegment: segment] length] > 0;
        NSImageAlignment alignment = hasLabel ? NSImageAlignLeft : NSImageAlignCenter;
        
		imageRect = [image imageRectAlignedInRect: frame
                                        alignment: alignment
                                          scaling: [self imageScalingForSegment: segment]];
		
        //TWEAK: round the image origin to fixed units, to prevent blurring.
        imageRect.origin.x = floorf(imageRect.origin.x);
        imageRect.origin.y = ceilf(imageRect.origin.y);
        
        
		CGFloat imageAlpha = 1.0f;
        NSShadow *imageShadow = nil;
        
		if ([image isTemplate])
		{
            NSColor *imageColor = (isEnabled) ? [theme textColor] : [theme disabledTextColor];
            
            //TODO: add disabledShadow and highlightedShadow to theme,
            //instead of just turning off the shadow altogether
            if (isEnabled) imageShadow = [theme textShadow];
            
            image = [image imageFilledWithColor: imageColor atSize: imageRect.size];
		}
        else
        {
            imageAlpha = isEnabled ? [theme alphaValue] : [theme disabledAlphaValue];
        }
		
		[NSGraphicsContext saveGraphicsState];
            if (imageShadow) [imageShadow set];
            
            [image drawInRect: imageRect
                     fromRect: NSZeroRect
                    operation: NSCompositeSourceAtop
                     fraction: imageAlpha
               respectFlipped: YES];
		[NSGraphicsContext restoreGraphicsState];
	}
    return imageRect;
}

- (void) drawTitleForSegment: (NSInteger)segment
                     inFrame: (NSRect)frame
                    withView: (NSView *)view
{
    BGTheme *theme = [[BGThemeManager keyedManager] themeForKey: self.themeKey];
    BOOL isEnabled = [self isEnabledForSegment: segment];
    
    NSString *label = [self labelForSegment: segment];
    if ([label length])
    {
        NSRect labelRect = NSZeroRect;
        
        CGFloat fontSize = [NSFont systemFontSizeForControlSize: [self controlSize]];
        NSFont *labelFont = [NSFont controlContentFontOfSize: fontSize];
        NSColor *labelColor = isEnabled ? [theme textColor] : [theme disabledTextColor];
        
        //TODO: add disabledShadow and highlightedShadow instead
        //of just turning off the shadow altogether
        NSShadow *labelShadow = isEnabled ? [theme textShadow] : nil;
        
        
        NSMutableDictionary *labelAttrs = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                           labelFont, NSFontAttributeName,
                                           labelColor, NSForegroundColorAttributeName,
                                           nil];
        
        
        if (labelShadow) [labelAttrs setObject: labelShadow
                                        forKey: NSShadowAttributeName];
        
        //Center the label within the segment, then pad it to accommodate the image if present
        labelRect.size = [label sizeWithAttributes: labelAttrs];
        labelRect = centerInRect(labelRect, frame);
        
        //Crop the label horizontally to ensure it fits inside the bounds
        NSRect croppedRect = NSIntersectionRect(labelRect, frame);
        croppedRect.size.height = labelRect.size.height;
        croppedRect.origin.y = labelRect.origin.y;
        
        [label drawInRect: croppedRect withAttributes: labelAttrs];
        
        [labelAttrs release];
    }
}

@end
/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXThemedControls.h"
#import "NSBezierPath+MCAdditions.h"
#import "NSImage+BXImageEffects.h"
#import "NSShadow+BXShadowExtensions.h"
#import "BXGeometry.h"

#pragma mark -
#pragma mark Base classes

@implementation BXThemedLabel

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

@implementation BXThemedButtonCell

- (NSRect) checkboxRectForBounds: (NSRect)frame
{
    NSRect checkboxFrame = frame;
    
	//Adjust by 0.5 so lines draw true
	checkboxFrame.origin.x += 0.5f;
	checkboxFrame.origin.y += 0.5f;
    
    switch ([self controlSize])
    {
        case NSSmallControlSize:
            checkboxFrame.size.height = 10;
            checkboxFrame.size.width = 11;
            checkboxFrame.origin.y += 3;
            break;
            
        case NSMiniControlSize:
            checkboxFrame.size.height = 8;
            checkboxFrame.size.width = 9;
            checkboxFrame.origin.y += 5;
            break;
            
        case NSRegularControlSize:
        default:
            checkboxFrame.size.height = 12;
            checkboxFrame.size.width = 13;
            checkboxFrame.origin.y += 2;
            break;   
    }
    
    //Adjust for image placement
    switch ([self imagePosition])
    {
        case NSImageLeft:
            switch ([self controlSize])
        {
            case NSSmallControlSize:
                checkboxFrame.origin.x += 3;
                break;
            case NSMiniControlSize:
                checkboxFrame.origin.x += 4;
                break;
            case NSRegularControlSize:
            default:
                checkboxFrame.origin.x += 2;
                break;
        }
			break;
			
		case NSImageRight:
            checkboxFrame.origin.x = NSWidth(frame) - NSWidth(checkboxFrame) - 1.5f;
            break;
            
		case NSImageOnly:
			if ([self controlSize] == NSRegularControlSize)
            {
				checkboxFrame.origin.x -= .5f;
			}
            else if([self controlSize] == NSMiniControlSize)
            {
				checkboxFrame.origin.x += .5f;
			}
			
			checkboxFrame.origin.x += (frame.size.width - checkboxFrame.size.width) / 2;
			break;
			
        default:
            break;
    }
    
    return checkboxFrame;
}

- (NSRect) radioButtonRectForBounds: (NSRect)frame
{
    NSRect radioFrame = [self checkboxRectForBounds: frame];
    radioFrame.size.height = radioFrame.size.width;
    return radioFrame;
}

- (NSRect) titleRectForBounds: (NSRect)frame
             withCheckboxRect: (NSRect)checkboxFrame
{
    NSRect textFrame = frame;
    
    switch ([self imagePosition])
    {
		case NSImageLeft:
            switch ([self controlSize])
        {
            case NSSmallControlSize:
                textFrame.size.width -= (NSMaxX(checkboxFrame) + 6);
                textFrame.origin.x = (NSMaxX(checkboxFrame) + 6);
                textFrame.origin.y -= 1;
                break;
            case NSMiniControlSize:
                textFrame.size.width -= (NSMaxX(checkboxFrame) + 4);
                textFrame.origin.x = (NSMaxX(checkboxFrame) + 4);
                break;
            case NSRegularControlSize:
            default:
                textFrame.size.width -= (NSMaxX(checkboxFrame) + 5);
                textFrame.origin.x = (NSMaxX(checkboxFrame) + 5);
                textFrame.origin.y -= 2;
                break;
        }
			break;
            
		case NSImageRight:
			switch ([self controlSize])
        {
            case NSSmallControlSize:
                textFrame.origin.x += 2;
                textFrame.size.width = (NSMinX(checkboxFrame) - NSMinX(textFrame) - 5);
                textFrame.origin.y -= 1;
                break;
            case NSMiniControlSize:
                textFrame.origin.x += 2;
                textFrame.size.width = (NSMinX(checkboxFrame) - NSMinX(textFrame) - 5);
                break;
            case NSRegularControlSize:
            default:
                textFrame.origin.x += 2;
                textFrame.size.width = (NSMinX(checkboxFrame) - NSMinX(textFrame) - 5);
                textFrame.origin.y -= 2;
                break;
        }
			break;
            
        default:
            break;
	}
    
    return textFrame;
}

- (NSBezierPath *) checkboxBezelForRect: (NSRect)rect
{
    return [NSBezierPath bezierPathWithRoundedRect: rect xRadius: 2 yRadius: 2];
}

- (NSBezierPath *) radioButtonBezelForRect: (NSRect)rect
{
    return [NSBezierPath bezierPathWithOvalInRect: rect];
}

- (NSBezierPath *) radioButtonGlyphForRect: (NSRect)frame
{
    NSBezierPath *path = nil;
    if ([self state] == NSOnState)
    {
        NSRect dotFrame;
        switch ([self controlSize])
        {
            case NSSmallControlSize:
                dotFrame = NSInsetRect(frame, 3.5f, 3.5f);
                break;
                
            case NSMiniControlSize:
                dotFrame = NSInsetRect(frame, 3.0f, 3.0f);
                break;
                
            case NSRegularControlSize:
            default:
                dotFrame = NSInsetRect(frame, 4.0f, 4.0f);
                break;
        }
        
        path = [[[NSBezierPath alloc] init] autorelease];
        [path appendBezierPathWithOvalInRect: dotFrame];
        
        //Indicates to the drawing context that this must be filled,
        //not stroked
        [path setLineWidth: 0.0f];
    }
    return path;
}

- (NSBezierPath *) checkboxGlyphForRect: (NSRect)frame
{
    NSBezierPath *path;
    
    switch ([self state])
    {
		case NSMixedState:
        {
            path = [[[NSBezierPath alloc] init] autorelease];
            NSPoint pointsMixed[2];
            
            pointsMixed[0] = NSMakePoint(NSMinX(frame) + 3, NSMidY(frame));
            pointsMixed[1] = NSMakePoint(NSMaxX(frame) - 3, NSMidY(frame));
            
            [path appendBezierPathWithPoints: pointsMixed count: 2];
            [path setLineWidth: 2.0f];
        }
            break;
			
		case NSOnState:
        {
            path = [[[NSBezierPath alloc] init] autorelease];
            NSPoint pointsOn[4];
            
            pointsOn[0] = NSMakePoint(NSMinX(frame) + 3, NSMidY(frame) - 2);
            pointsOn[1] = NSMakePoint(NSMidX(frame), NSMidY(frame) + 2);
            pointsOn[2] = NSMakePoint(NSMidX(frame), NSMidY(frame) + 2);
            pointsOn[3] = NSMakePoint(NSMinX(frame) + NSWidth(frame) - 1, NSMinY(frame) - 2);
            
            [path appendBezierPathWithPoints: pointsOn count: 4];
            
            CGFloat lineWidth = ([self controlSize] == NSMiniControlSize) ? 1.5f : 2.0f;
            [path setLineWidth: lineWidth];
        }
            break;
            
        default:
            path = nil;
            break;
    }
    
    return path;
}

//Adapted from BGHUDButtonCell in its entirety, just so that we could change
//the damn tick color.
- (void) drawCheckInFrame: (NSRect)frame isRadio: (BOOL)radio
{
    BGTheme *theme = [[BGThemeManager keyedManager] themeForKey: self.themeKey];
    
	NSRect bezelRect;
	NSBezierPath *bezelPath;
    NSBezierPath *glyphPath;
    
	if (radio) 
    {
        bezelRect = [self radioButtonRectForBounds: frame];
        bezelPath = [self radioButtonBezelForRect: bezelRect];
        glyphPath = [self radioButtonGlyphForRect: bezelRect];
    }
    else
    {
        bezelRect = [self checkboxRectForBounds: frame];
        bezelPath = [self checkboxBezelForRect: bezelRect];
        glyphPath = [self checkboxGlyphForRect: bezelRect];
    }
    [bezelPath setLineWidth: 1.0f];
	
    //First draw the shadow
    [NSGraphicsContext saveGraphicsState];
        [[theme dropShadow] set];
        [[theme darkStrokeColor] set];
        [bezelPath stroke];
	[NSGraphicsContext restoreGraphicsState];
    
    //Then fill the bezel
    NSGradient *fillGradient;
    if (![self isEnabled])          fillGradient = [theme disabledNormalGradient];
    else if ([self isHighlighted])  fillGradient = [theme highlightGradient];
    else                            fillGradient = [theme normalGradient];
    
    [fillGradient drawInBezierPath: bezelPath
                             angle: [theme gradientAngle]];
    
    //Then stroke the outside of the bezel
	[NSGraphicsContext saveGraphicsState];
        [[theme strokeColor] set];
        [bezelPath stroke];
	[NSGraphicsContext restoreGraphicsState];
	
    //Now finally draw the glyph
	[NSGraphicsContext saveGraphicsState];
        if ([self isEnabled])
            [[theme textColor] set];
        else
            [[theme disabledTextColor] set];
        
        if ([glyphPath lineWidth])
            [glyphPath stroke];
        else
            [glyphPath fill];
    [NSGraphicsContext restoreGraphicsState];
    
    
    //Finally, draw the text label (if we need to)
	if ([self imagePosition] != NSImageOnly && [self attributedTitle])
    {
        NSRect titleRect = [self titleRectForBounds: frame
                                   withCheckboxRect: bezelRect];
        
        [self drawTitle: [self attributedTitle]
              withFrame: titleRect
                 inView: [self controlView]];
	}
}

@end

@implementation BXThemedCheckboxCell

//Fix for setButtonType: no longer getting called for checkboxes in XIBs (jesus christ)
- (id) initWithCoder: (NSCoder *)aDecoder
{
    if ((self = [super initWithCoder: aDecoder]))
    {
        [self setButtonType: NSSwitchButton];
    }
    return self;
}

@end


@implementation BXThemedRadioCell

//See note above for BXThemedCheckboxCell.
- (id) initWithCoder: (NSCoder *)aDecoder
{
    if ((self = [super initWithCoder: aDecoder]))
    {
        [self setButtonType: NSRadioButton];
    }
    return self;
}

@end

@implementation BXThemedPopUpButtonCell

- (NSRect) drawingRectForBounds: (NSRect)theRect
{
    NSRect suggestedRect = [super drawingRectForBounds: theRect];

    suggestedRect.size.height += 3;
    if ([[self controlView] isFlipped]) suggestedRect.origin.y -= 3;
    
    return suggestedRect;
}

- (void) drawWithFrame: (NSRect)cellFrame inView: (NSView *)controlView
{
    BGTheme *theme = [[BGThemeManager keyedManager] themeForKey: self.themeKey];
	
    NSRect bezelFrame = [self drawingRectForBounds: cellFrame];
	
	if ([self isBordered])
    {
		NSBezierPath *bezel = [NSBezierPath bezierPathWithRoundedRect: bezelFrame
                                                              xRadius: 4
                                                              yRadius: 4];
        
		NSBezierPath *strokeBezel = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(bezelFrame, 0.5f, 0.5f)
                                                                    xRadius: 4
                                                                    yRadius: 4];
		
        //First, draw the bezel's shadow.
		[NSGraphicsContext saveGraphicsState];
            [[theme dropShadow] set];
            [[theme darkStrokeColor] set];
            [strokeBezel stroke];
		[NSGraphicsContext restoreGraphicsState];
		
        //Then, fill the bezel and draw the border on top.
        NSGradient *bezelGradient;
        NSColor *strokeColor;
		if ([self isEnabled])
        {
			bezelGradient = [theme normalGradient];
            strokeColor = [theme strokeColor];
        }
        else
        {
			bezelGradient = [theme disabledNormalGradient];
            strokeColor = [theme disabledStrokeColor];
        }
    
        [NSGraphicsContext saveGraphicsState];
            [bezelGradient drawInBezierPath: bezel angle: [theme gradientAngle]];
            [strokeColor set];
            [strokeBezel setLineWidth: 1.0f];
            [strokeBezel stroke];
        [NSGraphicsContext restoreGraphicsState];
	}
    
    [self drawInteriorWithFrame: cellFrame inView: controlView];
}

- (void) drawInteriorWithFrame: (NSRect)frame inView: (NSView *)controlView
{
    //Draw the arrows
	[self drawArrowsWithFrame: frame inView: controlView];
	
	[self drawTitle: [self attributedTitle] withFrame: frame inView: controlView];
	[self drawImage: [self image] withFrame: frame inView: controlView];
}

- (NSRect) drawTitle: (NSAttributedString *)title
           withFrame: (NSRect)frame
              inView: (NSView *)controlView
{
    if (![title length]) return NSZeroRect;
    
    BGTheme *theme = [[BGThemeManager keyedManager] themeForKey: self.themeKey];
    
    NSMutableAttributedString *formattedTitle = [title mutableCopy];
    NSRange range = NSMakeRange(0, [formattedTitle length]);
    
    
    NSColor *textColor;
    NSShadow *textShadow = [theme textShadow];
    
    if ([self isEnabled])
    {
        if ([self isHighlighted])
        {
            if ([[controlView window] isKeyWindow])
                textColor = [theme selectionTextActiveColor];
            else
                textColor = [theme selectionTextInActiveColor];
        }
        else
        {
            textColor = [theme textColor];
        }
    }
    else
    {
        textColor = [theme disabledTextColor];
        textShadow = nil;
    }
    
    [formattedTitle beginEditing];
        [formattedTitle addAttribute: NSForegroundColorAttributeName
                               value: textColor
                               range: range];
        
        [formattedTitle addAttribute: NSShadowAttributeName
                               value: textShadow
                               range: range];
    [formattedTitle endEditing];
    
    NSRect titleFrame = [self titleRectForBounds: frame];
    
    [super drawTitle: formattedTitle withFrame: titleFrame inView: controlView];
    
    [formattedTitle release];
    
    return titleFrame;
}

- (void) drawImage: (NSImage *)image withFrame: (NSRect)frame inView: (NSView *)controlView
{
    if (![self image] && ![self alternateImage]) return;
    
    BGTheme *theme = [[BGThemeManager keyedManager] themeForKey: self.themeKey];
    BOOL useAlternateImage = NO;
    
	if (([self highlightsBy] == NSContentsCellMask && [self isHighlighted]) ||
        ([self showsStateBy] == NSContentsCellMask && [self state]))
        useAlternateImage = YES;
    
    if (useAlternateImage && [self alternateImage])
        image = [self alternateImage];
    
    
    NSRect imageRect = [self imageRectForBounds: frame];
    
    CGFloat imageAlpha = 1.0f;
    NSShadow *imageShadow = nil;
    if ([image isTemplate])
    {
        NSColor *imageColor = [self isEnabled] ? [theme textColor] : [theme disabledTextColor];
        
        //TODO: add disabledShadow and highlightedShadow to theme,
        //instead of just turning off the shadow altogether
        if ([self isEnabled]) imageShadow = [theme textShadow];
        
        image = [image imageFilledWithColor: imageColor atSize: imageRect.size];
    }
    else
    {
        imageAlpha = [self isEnabled] ? [theme alphaValue] : [theme disabledAlphaValue];
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

- (NSBezierPath *) popUpArrowsForFrame: (NSRect)frame
{
    NSSize arrowSize;
    NSPoint arrowPosition = NSMakePoint(NSMaxX(frame), NSMidY(frame));
    
    switch ([self controlSize])
    {
        case NSRegularControlSize:
			arrowSize = NSMakeSize(5, 4);
            arrowPosition.x -= 11.5;
			break;
			
		case NSSmallControlSize:
			arrowSize = NSMakeSize(5, 4);
            arrowPosition.x -= 9.5;
			break;
			
		case NSMiniControlSize:
			arrowSize = NSMakeSize(4, 3);
            arrowPosition.x -= 7.5;
			break;
    }
    
    NSPoint topPoints[3], bottomPoints[3];
    
    CGFloat bottomOffset = 3, topOffset = -3;
    
    
    topPoints[0] = NSMakePoint(arrowPosition.x - (arrowSize.width / 2),
                               arrowPosition.y + (arrowSize.height / 2) + topOffset);
    topPoints[1] = NSMakePoint(arrowPosition.x + (arrowSize.width / 2),
                               arrowPosition.y + (arrowSize.height / 2) + topOffset);
    topPoints[2] = NSMakePoint(arrowPosition.x,
                               arrowPosition.y - (arrowSize.height / 2) + topOffset);
    
    bottomPoints[0] = NSMakePoint(arrowPosition.x - (arrowSize.width / 2),
                                  arrowPosition.y - (arrowSize.height / 2) + bottomOffset);
    bottomPoints[1] = NSMakePoint(arrowPosition.x + (arrowSize.width / 2),
                                  arrowPosition.y - (arrowSize.height / 2) + bottomOffset);
    bottomPoints[2] = NSMakePoint(arrowPosition.x,
                                  arrowPosition.y + (arrowSize.height / 2) + bottomOffset);
    
    NSBezierPath *topArrow = [[NSBezierPath alloc] init];
    [topArrow appendBezierPathWithPoints: topPoints count: 3];
    [topArrow closePath];
    
    NSBezierPath *bottomArrow = [[NSBezierPath alloc] init];
    [bottomArrow appendBezierPathWithPoints: bottomPoints count: 3];
    [bottomArrow closePath];
    
    [topArrow appendBezierPath: bottomArrow];
    [bottomArrow release];
    
    return [topArrow autorelease]; 
}

- (NSBezierPath *) pullDownArrowForFrame: (NSRect)frame
{
    NSBezierPath *arrow = [[NSBezierPath alloc] init];
    
    NSSize arrowSize;
    NSPoint arrowPosition = NSMakePoint(NSMaxX(frame), NSMidY(frame));
    
    switch ([self controlSize])
    {
        case NSRegularControlSize:
			arrowSize = NSMakeSize(7, 5);
            arrowPosition.x -= 11.5;
			break;
			
		case NSSmallControlSize:
			arrowSize = NSMakeSize(7, 5);
            arrowPosition.x -= 9.5;
			break;
			
		case NSMiniControlSize:
			arrowSize = NSMakeSize(5, 3);
            arrowPosition.x -= 7.5;
			break;
    }
                                      
    NSPoint points[3];
    
    points[0] = NSMakePoint(arrowPosition.x - (arrowSize.width / 2),
                            arrowPosition.y - (arrowSize.height / 2));
    points[1] = NSMakePoint(arrowPosition.x + (arrowSize.width / 2),
                            arrowPosition.y - (arrowSize.height / 2));
    points[2] = NSMakePoint(arrowPosition.x,
                            arrowPosition.y + (arrowSize.height / 2));
    
    [arrow appendBezierPathWithPoints: points count: 3];
    [arrow closePath];
    
    return [arrow autorelease];
}

- (void) drawArrowsWithFrame: (NSRect)frame inView: (NSView *)controlView
{
    BGTheme *theme = [[BGThemeManager keyedManager] themeForKey: self.themeKey];
    
    NSBezierPath *arrows;
    if ([self pullsDown])
        arrows = [self pullDownArrowForFrame: frame];
    else
        arrows = [self popUpArrowsForFrame: frame];
    
    [NSGraphicsContext saveGraphicsState];
        [[theme textShadow] set];
        [[theme textColor] set];
        [arrows fill];
    [NSGraphicsContext restoreGraphicsState];
}

@end

@implementation BXThemedSliderCell
@end


#pragma mark -
#pragma mark Themed versions

@implementation BXHUDLabel

- (NSString *)themeKey { return @"BXHUDTheme"; }

@end

@implementation BXHUDButtonCell

- (NSString *)themeKey { return @"BXHUDTheme"; }

@end

@implementation BXHUDCheckboxCell

- (NSString *)themeKey { return @"BXHUDTheme"; }

@end

@implementation BXHUDSliderCell

- (NSString *)themeKey { return @"BXHUDTheme"; }

@end

@implementation BXHUDPopUpButtonCell

- (NSString *)themeKey { return @"BXHUDTheme"; }

@end

@implementation BXHUDSegmentedCell

- (NSString *)themeKey { return @"BXHUDTheme"; }

@end


@implementation BXBlueprintLabel

- (NSString *)themeKey { return @"BXBlueprintTheme"; }

@end

@implementation BXBlueprintHelpTextLabel

- (NSString *)themeKey { return @"BXBlueprintHelpTextTheme"; }

@end


@implementation BXIndentedLabel

- (NSString *)themeKey { return @"BXIndentedTheme"; }

@end

@implementation BXIndentedHelpTextLabel

- (NSString *)themeKey { return @"BXIndentedHelpTextTheme"; }

@end

@implementation BXIndentedCheckboxCell

- (NSString *)themeKey { return @"BXIndentedTheme"; }

@end

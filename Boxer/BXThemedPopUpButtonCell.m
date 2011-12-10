/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXThemedPopUpButtonCell.h"
#import "NSBezierPath+MCAdditions.h"
#import "NSImage+BXImageEffects.h"
#import "NSShadow+BXShadowExtensions.h"
#import "BXGeometry.h"

@implementation BXThemedPopUpButtonCell

- (NSRect) drawingRectForBounds: (NSRect)theRect
{
    NSRect suggestedRect = [super drawingRectForBounds: theRect];
    
    suggestedRect.size.height += 4;
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
    
    if (textShadow)
    {
        [formattedTitle addAttribute: NSShadowAttributeName
                               value: textShadow
                               range: range];
    }
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
    NSSize arrowSize = NSZeroSize;
    NSPoint arrowPosition = NSMakePoint(NSMaxX(frame), NSMidY(frame));
    
    CGFloat bottomOffset, topOffset;
    
    switch ([self controlSize])
    {		
		case NSSmallControlSize:
			arrowSize = NSMakeSize(5, 4);
            arrowPosition.x -= 9.5f;
            bottomOffset = 3;
            topOffset = -3;
			break;
			
		case NSMiniControlSize:
			arrowSize = NSMakeSize(4, 3);
            arrowPosition.x -= 7.5f;
            bottomOffset = 2;
            topOffset = -2;
			break;
            
        case NSRegularControlSize:
        default:
			arrowSize = NSMakeSize(5, 4);
            arrowPosition.x -= 11.5f;
            bottomOffset = 4;
            topOffset = -4;
			break;
    }
    
    NSPoint topPoints[3], bottomPoints[3];
    
    
    
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
    
    NSSize arrowSize = NSZeroSize;
    NSPoint arrowPosition = NSMakePoint(NSMaxX(frame), NSMidY(frame));
    
    switch ([self controlSize])
    {
		case NSSmallControlSize:
			arrowSize = NSMakeSize(7, 5);
            arrowPosition.x -= 9.5f;
			break;
			
		case NSMiniControlSize:
			arrowSize = NSMakeSize(5, 3);
            arrowPosition.x -= 7.5f;
			break;
            
        case NSRegularControlSize:
        default:
			arrowSize = NSMakeSize(7, 5);
            arrowPosition.x -= 11.5f;
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

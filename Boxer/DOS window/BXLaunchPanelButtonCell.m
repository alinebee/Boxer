/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXLaunchPanelButtonCell.h"
#import "NSShadow+BXShadowExtensions.h"
#import "NSBezierPath+MCAdditions.h"
#import "NSImage+BXImageEffects.h"
#import "BXGeometry.h"

@implementation BXLaunchPanelButton

- (void) updateTrackingAreas
{
    [super updateTrackingAreas];
    
    //IMPLEMENTATION NOTE: NSTrackingAreas don't send mouseEntered: and
    //mouseExited: signals when a view is scrolled away from under the mouse.
    //However, updateTrackingAreas *does* get called when scrolling: so we check
    //mouse location by hand and synthesize mouseEntered/exited events to our
    //button cell here instead.
    NSPoint location = self.window.mouseLocationOutsideOfEventStream;
    NSPoint locationInView = [self convertPoint: location fromView: nil];
    if ([self hitTest: locationInView] != nil)
    {
        [self.cell mouseEntered: nil];
    }
    else
    {
        [self.cell mouseExited: nil];
    }
}

@end


@interface BXLaunchPanelButtonCell ()

//Whether the button is currently being hovered.
@property (assign, nonatomic) BOOL mouseIsInside;

@end


@implementation BXLaunchPanelButtonCell
@synthesize mouseIsInside = _mouseIsInside;

+ (NSString *) defaultThemeKey { return @"BXIndentedTheme"; }

//This has been overridden solely so that we will actually receive mouseEntered:
//and mouseExited: events, since AppKit only sends those messages for buttons that
//claim this. We do actually draw the button border regardless.
- (BOOL) showsBorderOnlyWhileMouseInside
{
    return YES;
}

- (id) initWithCoder: (NSCoder *)aDecoder
{
    self = [super initWithCoder: aDecoder];
    if (self)
    {
        //Expand the control view to compensate for regular recessed
        //buttons being so damn teeny. TODO: find some other more AppKitty
        //way to do this.
        NSRect expandedRect = NSInsetRect(self.controlView.frame, 0, -1.0f);
        [self.controlView setFrame: expandedRect];
    }
    return self;
}

- (void) setMouseIsInside: (BOOL)flag
{
    if (flag != _mouseIsInside)
    {
        _mouseIsInside = flag;
        [self.controlView setNeedsDisplay: YES];
    }
}

- (void) mouseEntered: (NSEvent *)event
{
    self.mouseIsInside = YES;
}

- (void) mouseExited: (NSEvent *)event
{
    self.mouseIsInside = NO;
}

- (NSRect) drawTitle: (NSAttributedString *)title
           withFrame: (NSRect)frame
              inView: (NSView *)controlView
{   
	NSRect textRect = NSInsetRect(frame, 16.0f, 0.0f);
	
	if (title.length)
    {
        NSMutableAttributedString *newTitle = [title mutableCopy];
        
        NSColor *textColor;
        NSColor *shadowColor = [NSColor colorWithCalibratedWhite: 0 alpha: 0.75f];
        NSShadow *textShadow = [NSShadow shadowWithBlurRadius: 1.0
                                                       offset: NSMakeSize(0, 1.0f)
                                                        color: shadowColor];
        
        if (!self.isEnabled)
        {
            textColor = [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.25f];
        }
        
        //Brighten text when pushed in
        else if (self.isHighlighted)
        {
            textColor = [NSColor colorWithCalibratedWhite: 1.0f alpha: 1.0f];
        }
        else if (self.mouseIsInside)
        {
            textColor = [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.9f];
        }
        else
        {
            textColor = [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.75f];
        }
		
        NSRange range = NSMakeRange(0, newTitle.length);
        
        [newTitle beginEditing];
        [newTitle addAttribute: NSForegroundColorAttributeName
                         value: textColor
                         range: range];
        
        if (textShadow)
        {
            [newTitle addAttribute: NSShadowAttributeName
                             value: textShadow
                             range: range];
        }
		[newTitle endEditing];
        
        //Adjust the rect so that the text is vertically centered
        NSSize textSize = newTitle.size;
        textRect.origin.y = (textRect.size.height - textSize.height) * 0.5f;
        textRect.size = textSize;
        
        [newTitle drawInRect: textRect];
        
        [newTitle release];
	}
	
	return textRect;
}

- (void) drawWithFrame: (NSRect)frame inView: (NSView *)controlView
{
    [self drawBezelWithFrame: frame inView: controlView];
    
    if (self.image && self.isEnabled && (self.isHighlighted || self.mouseIsInside))
        [self drawImage: self.image withFrame: frame inView: controlView];
    
    [self drawTitle: self.attributedTitle withFrame: frame inView: self.controlView];
}

- (void) drawBezelWithFrame: (NSRect)frame inView: (NSView *)controlView
{
    NSColor *borderColor = [NSColor colorWithCalibratedWhite: 0 alpha: 0.25f];
    
    NSColor *outerBevelColor = [NSColor colorWithCalibratedWhite: 0
                                                           alpha: 0.75f];
    
    NSShadow *outerBevel = [NSShadow shadowWithBlurRadius: 3.0f
                                                   offset: NSMakeSize(0, -1.0f)
                                                    color: outerBevelColor];
    
    NSRect borderFrame = [outerBevel insetRectForShadow: frame
                                                flipped: controlView.isFlipped];
    
    NSBezierPath *border = [NSBezierPath bezierPathWithRoundedRect: borderFrame
                                                           xRadius: 8.0f
                                                           yRadius: 8.0f];
    
    NSRect bezelFrame   = NSInsetRect(borderFrame, 1.0f, 1.0f);
    NSBezierPath *bezel = [NSBezierPath bezierPathWithRoundedRect: bezelFrame
                                                          xRadius: 7.0f
                                                          yRadius: 7.0f];
    
    NSGradient *bezelGradient;
    NSColor *bezelColor;
    NSShadow *innerBevel;
    NSShadow *innerGlow;
    
    //Pressed-in state
    if (self.isHighlighted)
    {
        bezelColor = [NSColor alternateSelectedControlColor];
        bezelGradient = [[NSGradient alloc] initWithColorsAndLocations:
                         [NSColor colorWithCalibratedWhite: 1 alpha: 0.10f], 0.0f,
                         [NSColor colorWithCalibratedWhite: 0 alpha: 0.25f], 1.0f,
                         nil];
        
        NSColor *innerBevelColor = [NSColor colorWithCalibratedWhite: 0 alpha: 0.5f];
        innerBevel = [NSShadow shadowWithBlurRadius: 3.0f
                                             offset: NSMakeSize(0, -1.0f)
                                              color: innerBevelColor];
        
        //Use a different bevel when we're in our pressed-in state.
        outerBevelColor = [NSColor colorWithCalibratedWhite: 1 alpha: 0.1f];
        
        outerBevel = [NSShadow shadowWithBlurRadius: 1.0f
                                             offset: NSMakeSize(0, -1.0f)
                                              color: outerBevelColor];
        
        innerGlow = nil;
    }
    //Hovered state
    else if (self.mouseIsInside && self.isEnabled)
    {
        bezelColor = [NSColor alternateSelectedControlColor];
        bezelGradient = [[NSGradient alloc] initWithColorsAndLocations:
                         [NSColor colorWithCalibratedWhite: 0 alpha: 0.25f], 0.0f,
                         [NSColor colorWithCalibratedWhite: 1 alpha: 0.25f], 1.0f,
                         nil];
        
        NSColor *innerBevelColor = [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.2f];
        innerBevel = [NSShadow shadowWithBlurRadius: 1.0f
                                             offset: NSMakeSize(0, -1.0f)
                                              color: innerBevelColor];
        
        NSColor *glowColor = [NSColor colorWithCalibratedWhite: 1.0 alpha: 0.1f];
        innerGlow = [NSShadow shadowWithBlurRadius: 3.0f
                                            offset: NSZeroSize
                                             color: glowColor];
    }
    //Regular state
    else
    {
        bezelColor  = [NSColor colorWithCalibratedRed: 0.21f
                                                green: 0.21f
                                                 blue: 0.23f
                                                alpha: 1.0f];
        
        bezelGradient = [[NSGradient alloc] initWithColorsAndLocations:
                         [NSColor colorWithCalibratedWhite: 0 alpha: 0.1f], 0.0f,
                         [NSColor colorWithCalibratedWhite: 1 alpha: 0.1f], 1.0f,
                         nil];
        
        NSColor *innerBevelColor = [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.2f];
        innerBevel = [NSShadow shadowWithBlurRadius: 1.0f
                                             offset: NSMakeSize(0, -1.0f)
                                              color: innerBevelColor];
        
        NSColor *glowColor = [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.1f];
        innerGlow = [NSShadow shadowWithBlurRadius: 3.0f
                                            offset: NSZeroSize
                                             color: glowColor];
    }
    
    //First fill the border and render the outer bevel.
    [NSGraphicsContext saveGraphicsState];
        [outerBevel set];
        [borderColor set];
        [border fill];
    [NSGraphicsContext restoreGraphicsState];
    
    //After this, render the bezel itself.
    [NSGraphicsContext saveGraphicsState];
        [bezelColor set];
        [bezel fill];
        [bezelGradient drawInBezierPath: bezel angle: 270];
    
        if (innerGlow)
            [bezel fillWithInnerShadow: innerGlow];
        [bezel fillWithInnerShadow: innerBevel];
    [NSGraphicsContext restoreGraphicsState];
    
    [bezelGradient release];
}

- (NSRect) imageRectForBounds: (NSRect)theRect
{
    return NSInsetRect(theRect, 12.0f, 12.0f);
}

- (void) drawImage: (NSImage *)image withFrame: (NSRect)frame inView: (NSView *)controlView
{
    NSRect imageRect = [self imageRectForImage: image
                                     forBounds: frame];
    
    NSColor *tint;
    
    if (self.isHighlighted)
    {
        tint = [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.7];
    }
    else
    {
        tint = [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.6];
    }
    
    NSColor *indentColor = [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.33f];
    NSShadow *indent = [NSShadow shadowWithBlurRadius: 1.0
                                               offset: NSMakeSize(0, -1.0f)
                                                color: indentColor];
    
    NSImage *tintedImage = [image imageFilledWithColor: tint atSize: imageRect.size];
        
    [NSGraphicsContext saveGraphicsState];
        [indent set];
        [tintedImage drawInRect: imageRect
                       fromRect: NSZeroRect
                      operation: NSCompositeSourceOver
                       fraction: 1.0f
                 respectFlipped: YES];
    [NSGraphicsContext restoreGraphicsState];
}

@end


@implementation BXLaunchPanelLogoCell

- (void) awakeFromNib
{
    self.showsStateBy = NSNoCellMask;
    self.highlightsBy = NSNoCellMask;
}

@end

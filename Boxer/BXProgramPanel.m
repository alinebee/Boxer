/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXProgramPanel.h"
#import "NSView+BXDrawing.h"
#import "BXAppController.h"
#import "NSShadow+BXShadowExtensions.h"
#import "NSBezierPath+MCAdditions.h"


@implementation BXProgramPanel

- (BOOL) isOpaque { return YES; }
- (BOOL) mouseDownCanMoveWindow { return YES; }

- (void) _drawGradientInRect: (NSRect)dirtyRect
{
	NSColor *backgroundColor = [NSColor colorWithCalibratedRed: 0.86f green: 0.87f blue: 0.88f alpha: 1.0f];
	NSGradient *background = [[NSGradient alloc] initWithColorsAndLocations:
							  backgroundColor,							0.0f,
							  [backgroundColor shadowWithLevel: 0.25f],	0.9f,
							  [backgroundColor shadowWithLevel: 0.75f],	1.0f,
							  nil];
	
    [NSBezierPath clipRect: dirtyRect];
	[background drawInRect: [self bounds] angle: 90.0f];
	[background release];
}

- (void) _drawGrilleInRect: (NSRect)dirtyRect
{
	NSImage *grille		= [NSImage imageNamed: @"Grille"];
	NSSize patternSize	= [grille size];
	NSRect panelRegion	= [self bounds];
	
	//Next, calculate our top and bottom grille strips
	NSRect grilleStrip		= panelRegion;
	grilleStrip.size.height	= patternSize.height * 0.83f;	//Cut off the top of the grille slightly
	grilleStrip.origin.y	= panelRegion.size.height - grilleStrip.size.height;	//Align the grille along the top of the panel
	
	//Only bother drawing the grille if it intersects with the region being drawn
	if ([self needsToDrawRect: grilleStrip])
	{
		NSPoint patternOffset	= [self offsetFromWindowOrigin];
        
        NSPoint grillePhase		= NSMakePoint(patternOffset.x + ((panelRegion.size.width - patternSize.width) / 2),																patternOffset.y + grilleStrip.origin.y);
		
		NSBezierPath *grillePath	= [NSBezierPath bezierPathWithRect: grilleStrip];
		NSColor *grillePattern      = [NSColor colorWithPatternImage: grille];
		
		//Finally, draw the grille strip.
		[NSGraphicsContext saveGraphicsState];
            [[NSGraphicsContext currentContext] setPatternPhase: grillePhase];
            [grillePattern set];
            [grillePath fill];
		[NSGraphicsContext restoreGraphicsState];
	}	
}

- (void) _drawBevelInRect: (NSRect)dirtyRect
{
    NSRect bevelRect = [self bounds];
    bevelRect.size.height = 1.0f;
    
    if ([self needsToDrawRect: bevelRect])
    {
        NSColor * bevelColor = [NSColor colorWithCalibratedWhite: 0 alpha: 0.2f];
        [bevelColor set];
        [NSBezierPath fillRect: bevelRect];
    }
}

- (void) drawRect: (NSRect)dirtyRect
{
	[self _drawGradientInRect: dirtyRect];
	[self _drawGrilleInRect: dirtyRect];
    [self _drawBevelInRect: dirtyRect];
    
    //If we contain a title then redraw the gradient behind the title
    //and over the grille, to create a knockout effect
    NSView *title = [self viewWithTag: BXProgramPanelTitle];
    if (title && ![title isHiddenOrHasHiddenAncestor])
    {
        NSRect titleMask = [title frame];
        
        if ([self needsToDrawRect: titleMask])
            [self _drawGradientInRect: titleMask];
    }
}
@end


@implementation BXProgramItem
@synthesize programButton;

- (void) viewDidLoad
{
    [self setProgramButton: [[self view] viewWithTag: BXProgramPanelButtons]];
    
    [[[self programButton] cell] bind: @"programIsDefault"
                             toObject: self
                          withKeyPath: @"representedObject.isDefault"
                              options: nil];
}

- (void) dealloc
{
    [[[self programButton] cell] unbind: @"programIsDefault"];
    [self setProgramButton: nil], [programButton release];
    [super dealloc];
}
@end


@implementation BXProgramItemButtonCell
@synthesize programIsDefault, mouseIsInside;

- (NSString *) themeKey { return @"BXIndentedTheme"; }

- (id) initWithCoder: (NSCoder *)aDecoder
{
    if ((self = [super initWithCoder: aDecoder]))
    {
        //Expand the control view to compensate for regular recessed buttons being so damn teeny
        [[self controlView] setFrame: NSInsetRect([[self controlView] frame], 0, -1.0f)];
    }
    return self;
}


- (void) setMouseIsInside: (BOOL)flag
{
    mouseIsInside = flag;
    [[self controlView] setNeedsDisplay: YES];
}

- (void) setProgramIsDefault: (BOOL)flag
{
    programIsDefault = flag;
    [[self controlView] setNeedsDisplay: YES];
}

- (void) mouseEntered: (NSEvent *)event
{
    [self setMouseIsInside: YES];
}

- (void) mouseExited: (NSEvent *)event
{
    [self setMouseIsInside: NO];
}

-(NSRect) drawTitle: (NSAttributedString *)title
          withFrame: (NSRect)frame
             inView: (NSView *)controlView
{
	BGTheme *theme = [[BGThemeManager keyedManager] themeForKey: self.themeKey];

	NSRect textRect = NSInsetRect(frame, 5.0f, 2.0f);
	
	if ([title length])
    {
        NSMutableAttributedString *newTitle = [title mutableCopy];
        
        NSColor *textColor;
        NSShadow *textShadow;
        
        if (![self isEnabled])
        {
            textColor = [theme disabledTextColor];
            textShadow = [theme textShadow];
        }
        //Use white text to stand out against blue background
        else if ([self programIsDefault])
        {
            textColor = [NSColor whiteColor];
            textShadow = [NSShadow shadowWithBlurRadius: 2.0f
                                                 offset: NSMakeSize(0, -1.0)
                                                  color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.75]];
        }
        //Darken text when pressed in
        else if ([self isHighlighted])
        {
            textColor = [NSColor colorWithCalibratedWhite: 0.15 alpha: 1];
            textShadow = [theme textShadow];
        }
        else
        {
            textColor = [theme textColor];
            textShadow = [theme textShadow];
        }
		
        NSRange range = NSMakeRange(0, [newTitle length]);
        
        [newTitle beginEditing];
            [newTitle addAttribute: NSForegroundColorAttributeName value: textColor range: range];
            [newTitle addAttribute: NSShadowAttributeName value: textShadow range: range];
		[newTitle endEditing];
        
        [newTitle drawInRect: textRect];
        
        [newTitle release];
	}
	
	return textRect;
}

- (void) drawWithFrame: (NSRect)frame inView: (NSView *)controlView
{
    if ([self isEnabled] && ([self isHighlighted] || [self programIsDefault] || [self mouseIsInside]))
    {
        NSShadow *innerShadow = [NSShadow shadowWithBlurRadius: 3.0f
                                                        offset: NSMakeSize(0, -1.0f)
                                                         color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.25]];
        NSShadow *outerBevel = [NSShadow shadowWithBlurRadius: 1.0f
                                                       offset: NSMakeSize(0, -1.0f)
                                                        color: [NSColor colorWithCalibratedWhite: 1 alpha: 0.75]];
        
        NSRect insetFrame = [outerBevel insetRectForShadow: frame flipped: [controlView isFlipped]];
        
        NSBezierPath *bezel = [NSBezierPath bezierPathWithRoundedRect: insetFrame
                                                              xRadius: insetFrame.size.height / 2
                                                              yRadius: insetFrame.size.height / 2];
        
        NSGradient *bezelGradient;
        NSColor *bezelColor;
        NSColor *strokeColor;
        
        if ([self programIsDefault])
        {
            strokeColor = [NSColor colorWithCalibratedWhite: 0 alpha: 0.3];
            bezelColor  = [NSColor alternateSelectedControlColor];
            
            if ([self isHighlighted])
            {
                bezelGradient = [[NSGradient alloc] initWithColorsAndLocations:
                                 [NSColor colorWithCalibratedWhite: 0 alpha: 0.33f], 0.0f,
                                 [NSColor colorWithCalibratedWhite: 0 alpha: 0.0f], 0.8f,
                                 [NSColor colorWithCalibratedWhite: 1 alpha: 0.3f], 1.0f,
                                 nil];
            }
            else if ([self mouseIsInside])
            {
                bezelGradient = [[NSGradient alloc] initWithColorsAndLocations:
                                 [NSColor colorWithCalibratedWhite: 1 alpha: 0.15f], 0.0f,
                                 [NSColor colorWithCalibratedWhite: 0 alpha: 0.1f], 1.0f,
                                 nil];
            }
            else
            {
                bezelGradient = [[NSGradient alloc] initWithColorsAndLocations:
                                 [NSColor colorWithCalibratedWhite: 1 alpha: 0.1f], 0.0f,
                                 [NSColor colorWithCalibratedWhite: 0 alpha: 0.05f], 1.0f,
                                 nil];
            }
        }
        else
        {
            if ([self isHighlighted])
            {
                strokeColor = [NSColor colorWithCalibratedWhite: 0 alpha: 0.2];
                bezelColor  = [NSColor colorWithCalibratedWhite: 0.6 alpha: 1];
                bezelGradient = [[NSGradient alloc] initWithColorsAndLocations:
                                 [NSColor colorWithCalibratedWhite: 0 alpha: 0.33f], 0.0f,
                                 [NSColor colorWithCalibratedWhite: 0 alpha: 0.0f], 0.8f,
                                 [NSColor colorWithCalibratedWhite: 1 alpha: 0.3f], 1.0f,
                                 nil];
            }
            else
            {
                strokeColor = [NSColor colorWithCalibratedWhite: 0 alpha: 0.05];
                bezelColor  = [NSColor colorWithCalibratedWhite: 0.8 alpha: 1];
                bezelGradient = [[NSGradient alloc] initWithColorsAndLocations:
                                 [NSColor colorWithCalibratedWhite: 0 alpha: 0.05f], 0.0f,
                                 [NSColor colorWithCalibratedWhite: 0 alpha: 0.1f], 1.0f,
                                 nil];
            }
        }
        
        [NSGraphicsContext saveGraphicsState];
            if ([self isHighlighted] || [self programIsDefault])
            {
                [outerBevel set];
                [bezelColor set];
                [bezel fill];
            }
            [bezelGradient drawInBezierPath: bezel angle: 90];
        [NSGraphicsContext restoreGraphicsState];
        
        [NSGraphicsContext saveGraphicsState];
            [strokeColor set];
            [bezel strokeInside];
            if ([self isHighlighted]) [bezel fillWithInnerShadow: innerShadow];
        [NSGraphicsContext restoreGraphicsState];
        
        [bezelGradient release];
    }
    
    [self drawTitle: [self attributedTitle] withFrame: frame inView: [self controlView]];
}

@end


//IMPLEMENTATION NOTE:
//On OS X 10.5, NSCollectionView has a bug whereby if its content is changed while the view is hidden,
//it will sometimes try to draw regardless and crash with an assertion error. Because the draw operation
//that causes this does not go through the usual display: channels, we cannot prevent it directly.
//So instead, we override the way content is set: if the view isn't ready to draw, we delay setting
//the content until it is.
//Happily, none of this is necessary on 10.6 and above, and it also doesn't seem to be a problem with
//any collection view other than the program list. (This would still be worth refactoring into a general
//"BXCollectionView" with other fixes however.)
@implementation BXProgramListView

- (void) dealloc
{
    [_pendingContent release], _pendingContent = nil;
    [super dealloc];
}

- (void) _syncPendingContent
{
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector: _cmd object: nil];
	if ([self canDraw])
	{
		[super setContent: _pendingContent];
		[_pendingContent release];
		_pendingContent = nil;
	}
	else
	{
		[self performSelector: _cmd withObject: nil afterDelay: 0.1];
	}
}

- (void) setContent: (NSArray *)content
{
    if ([BXAppController isRunningOnLeopard])
    {
        [_pendingContent release];
        _pendingContent = [content retain];
        [self _syncPendingContent];
    }
    else
    {
        [super setContent: content];
    }
}

@end

/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXProgramPanel.h"
#import "NSView+BXDrawing.h"
#import "BXAppController.h"

@implementation BXProgramPanel

- (BOOL) isOpaque { return YES; }
- (BOOL) mouseDownCanMoveWindow { return YES; }

- (void) _drawGradientInRect: (NSRect)dirtyRect
{
	NSColor *backgroundColor = [NSColor colorWithCalibratedWhite: 0.85f alpha: 1.0f]; 
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


@implementation BXProgramItemButton
@synthesize delegate;
   
- (id) representedObject
{
	return [[self delegate] representedObject];
}

- (void) viewWillDraw
{
	//If this item is enabled and the default, style the button differently.
	//TODO: move this into an initializer? Buttons are recreated whenever the default
	//program changes anyway.
	BOOL isDefault = [[[self representedObject] objectForKey: @"isDefault"] boolValue];
    
	[self setShowsBorderOnlyWhileMouseInside: !isDefault || ![self isEnabled]];
	
    //Cosmetic fix for Lion, which changed the button appearance to remove the indent
    //in the button's unhovered state.
    [[self cell] setBackgroundStyle: NSBackgroundStyleRaised]; 
    
	[super viewWillDraw];
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

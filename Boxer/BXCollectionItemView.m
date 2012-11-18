/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXCollectionItemView.h"
#import "NSBezierPath+MCAdditions.h"
#import "NSShadow+BXShadowExtensions.h"

@implementation BXCollectionItemView
@synthesize delegate;

//Returns the original prototype we were copied from, to access properties that weren't copied.
- (NSView *) prototype
{
	NSView *prototype = [[[[self delegate] collectionView] itemPrototype] view];
	//If we're already a prototype, then return nil instead of a reference to self.
	if (self != prototype) return prototype;
	else return nil;
}

//Overridden so that we always receive click events rather than the first click focusing the window.
- (BOOL) acceptsFirstMouse: (NSEvent *)theEvent { return YES; }

//Overridden so that we indicate that every click has hit us instead of our descendants.
- (NSView *) hitTest: (NSPoint)thePoint
{
	NSView *hitView = [super hitTest: thePoint];
	if (hitView != nil)
	{
		//TWEAK: if the view has an action, let the click go through unless it's disabled
		if (![hitView respondsToSelector: @selector(action)] || ![(id)hitView action] || ![(id)hitView isEnabled]) hitView = self;
	}
	return hitView;
}

- (NSMenu *) menuForEvent: (NSEvent *)theEvent
{
	//Select the item before displaying the menu
	if (![[self delegate] isSelected])
	{
		[[self delegate] setSelected: YES];
	}
	
	//NSCollectionView doesn't copy the menu when duplicating views, so we fall back
	//on the original prototype's menu if we haven't been given one of our own.
	NSMenu *menu = [super menuForEvent: theEvent];
	if (!menu) menu = [[self prototype] menuForEvent: theEvent];
	
	return menu;
}

@end

@implementation BXHUDCollectionItemView

- (void) drawRect: (NSRect)dirtyRect
{
	if (self.delegate.isSelected)
	{
		[NSBezierPath clipRect: dirtyRect];
		
		NSColor *selectionColor	= [NSColor alternateSelectedControlColor];
		NSColor *shadowColor	= [selectionColor shadowWithLevel: 0.4f];
		NSGradient *background	= [[NSGradient alloc] initWithStartingColor: selectionColor
																endingColor: shadowColor];
		
		NSRect backgroundRect = NSInsetRect([self bounds], 5.0f, 3.0f);
		NSBezierPath *backgroundPath = [NSBezierPath bezierPathWithRoundedRect: backgroundRect
																	   xRadius: 3.0f
																	   yRadius: 3.0f];
		
		NSShadow *dropShadow = nil, *innerGlow = nil;
		
		//Only bother with the drop shadow and border glow if the dirty region
		//extends beyond the region inside the glow
		NSRect innerRect = NSInsetRect(backgroundRect, 2.0f, 2.0f);
		if (!NSContainsRect(innerRect, dirtyRect))
		{
			dropShadow = [[NSShadow alloc] init];
			[dropShadow setShadowOffset: NSMakeSize(0.0f, -0.5f)];
			[dropShadow setShadowBlurRadius: 2.0f];
			[dropShadow setShadowColor: [[NSColor blackColor] colorWithAlphaComponent: 0.85f]];
			
			innerGlow = [[NSShadow alloc] init];
			[innerGlow setShadowOffset: NSZeroSize];
			[innerGlow setShadowBlurRadius: 2.0f];
			[innerGlow setShadowColor: [[NSColor whiteColor] colorWithAlphaComponent: 0.5f]];
		}
		
		[NSGraphicsContext saveGraphicsState];
			if (dropShadow) [dropShadow set];
		
			//Necessary only so that drop shadow gets drawn: it won't be by NSGradient drawInBezierPath:angle:
			[selectionColor set];
			[backgroundPath fill];
		
			//Now draw the gradient on top
			[background drawInBezierPath: backgroundPath angle: 270.0f];
		[NSGraphicsContext restoreGraphicsState];
		
		//Draw the glow last on top of everything else
		if (innerGlow) [backgroundPath fillWithInnerShadow: innerGlow];
		
		[background release];
		if (dropShadow)	[dropShadow release];
		if (innerGlow)	[innerGlow release];
	}
}
@end



@implementation BXIndentedCollectionItemView

- (void) viewWillDraw
{
    BOOL isSelected = self.delegate.isSelected;
    NSColor *textColor = (isSelected) ? [NSColor whiteColor] : [NSColor blackColor];
    
    
    for (id view in self.subviews)
    {
        if ([view isKindOfClass: [NSTextField class]])
        {
            ((NSTextField *)view).textColor = textColor;
        }
    }
}

- (void) drawRect: (NSRect)dirtyRect
{
	if (self.delegate.isSelected)
	{
		NSColor *selectionColor	= [NSColor alternateSelectedControlColor];
        
        [selectionColor set];
        NSRectFill(dirtyRect);
	}
}
@end


@implementation BXCollectionItem

- (void) viewDidLoad
{
    //Intended to be overridden in subclasses.
}

- (id) copyWithZone: (NSZone *)zone
{
    id copy = [super copyWithZone: zone];
    [copy viewDidLoad];
    return copy;
}

- (void) setView: (NSView *)view
{
    [super setView: view];
    [self viewDidLoad];
}

//Redraw our view whenever we are selected or deselected
- (void) setSelected: (BOOL)flag
{
	if (flag != [self isSelected])
	{
		[super setSelected: flag];
		[[self view] setNeedsDisplay: YES];
	}
}

@end
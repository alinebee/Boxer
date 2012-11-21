/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXCollectionItemView.h"
#import "NSBezierPath+MCAdditions.h"
#import "NSShadow+BXShadowExtensions.h"
#import "BXThemedImageCell.h"

@implementation BXCollectionItemView
@synthesize delegate;

//Returns the original prototype we were copied from, to access properties that weren't copied.
- (NSView *) prototype
{
	NSView *prototype = self.delegate.collectionView.itemPrototype.view;
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
	if (!self.delegate.isSelected)
		self.delegate.selected = YES;
	
	//NSCollectionView doesn't copy the menu when duplicating views, so we fall back
	//on the original prototype's menu if we haven't been given one of our own.
	NSMenu *menu = [super menuForEvent: theEvent];
	if (!menu)
        menu = [self.prototype menuForEvent: theEvent];
	
	return menu;
}

//Implement in subclasses
- (void) collectionViewItemDidChangeSelection {}

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
		
		NSRect backgroundRect = NSInsetRect(self.bounds, 5.0f, 3.0f);
		NSBezierPath *backgroundPath = [NSBezierPath bezierPathWithRoundedRect: backgroundRect
																	   xRadius: 3.0f
																	   yRadius: 3.0f];
		
		NSShadow *dropShadow = nil, *innerGlow = nil;
		
		//Only bother with the drop shadow and border glow if the dirty region
		//extends beyond the region inside the glow
		NSRect innerRect = NSInsetRect(backgroundRect, 2.0f, 2.0f);
		if (!NSContainsRect(innerRect, dirtyRect))
		{
            dropShadow = [NSShadow shadowWithBlurRadius: 2.0f
                                                 offset: NSMakeSize(0.0f, -0.5f)
                                                  color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.85]];
			
            innerGlow = [NSShadow shadowWithBlurRadius: 2.0f
                                                offset: NSZeroSize
                                                 color: [NSColor colorWithCalibratedWhite: 1 alpha: 0.5]];
		}
		
		[NSGraphicsContext saveGraphicsState];
			[dropShadow set];
		
			//Necessary only so that drop shadow gets drawn: it won't be by NSGradient drawInBezierPath:angle:
			[selectionColor set];
			[backgroundPath fill];
		
			//Now draw the gradient on top
			[background drawInBezierPath: backgroundPath angle: 270.0f];
		[NSGraphicsContext restoreGraphicsState];
		
		//Draw the glow last on top of everything else
		if (innerGlow)
            [backgroundPath fillWithInnerShadow: innerGlow];
		
		[background release];
	}
}

- (void) collectionViewItemDidChangeSelection
{
    [self setNeedsDisplay: YES];
}

@end



@implementation BXIndentedCollectionItemView

- (void) collectionViewItemDidChangeSelection
{
    NSString *themeKey;
    if (self.delegate.isSelected)
    {
        themeKey = @"BXInspectorListSelectionTheme";
    }
    else
    {
        themeKey = @"BXInspectorListTheme";
    }
    
    for (id view in self.subviews)
    {
        if ([view respondsToSelector: @selector(setThemeKey:)])
        {
            [view setThemeKey: themeKey];
            [view setNeedsDisplay: YES];
        }
    }
    
    [self setNeedsDisplay: YES];
    
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
    if ([self.view respondsToSelector: @selector(collectionViewItemDidChangeSelection)])
        [(id)self.view collectionViewItemDidChangeSelection];
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
	if (flag != self.isSelected)
	{
		[super setSelected: flag];
        if ([self.view respondsToSelector: @selector(collectionViewItemDidChangeSelection)])
            [(id)self.view collectionViewItemDidChangeSelection];
	}
}

@end
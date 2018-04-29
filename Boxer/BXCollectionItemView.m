/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXCollectionItemView.h"
#import "NSBezierPath+MCAdditions.h"
#import "NSShadow+ADBShadowExtensions.h"
#import "BXThemedImageCell.h"
#import "NSView+ADBDrawingHelpers.h"

@implementation BXCollectionItemView

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

- (void) dealloc
{
    self.delegate = nil;
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
	}
}

- (void) collectionViewItemDidChangeSelection
{
    [self setNeedsDisplay: YES];
}

@end



@implementation BXInspectorListCollectionItemView

- (void) collectionViewItemDidChangeSelection
{
    [self setNeedsDisplay: YES];
}

- (void) _windowDidChangeActiveStatus
{
    if (self.delegate.isSelected)
        [self setNeedsDisplay: YES];
}

//Redraw whenever the window became the main window so that our selection color correctly matches the status of the window.
- (void) viewWillMoveToWindow: (NSWindow *)newWindow
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    if (self.window)
    {
        [center removeObserver: self name: NSWindowDidBecomeMainNotification object: self.window];
        [center removeObserver: self name: NSWindowDidResignMainNotification object: self.window];
        [center removeObserver: self name: NSApplicationDidBecomeActiveNotification object: NSApp];
        [center removeObserver: self name: NSApplicationDidResignActiveNotification object: NSApp];
    }
    
    if (newWindow)
    {
        [center addObserver: self selector: @selector(_windowDidChangeActiveStatus) name: NSWindowDidBecomeMainNotification object: newWindow];
        [center addObserver: self selector: @selector(_windowDidChangeActiveStatus) name: NSWindowDidResignMainNotification object: newWindow];
        [center addObserver: self selector: @selector(_windowDidChangeActiveStatus) name: NSApplicationDidBecomeActiveNotification object: NSApp];
        [center addObserver: self selector: @selector(_windowDidChangeActiveStatus) name: NSApplicationDidResignActiveNotification object: NSApp];
    }
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) drawRect: (NSRect)dirtyRect
{
	if (self.delegate.isSelected)
	{
		NSColor *selectionColor	= (self.windowIsActive) ? [NSColor alternateSelectedControlColor] : [NSColor secondarySelectedControlColor];
        
		NSColor *fadeColor      = [selectionColor shadowWithLevel: 0.20f];
		NSColor *shadowColor	= [selectionColor shadowWithLevel: 0.33f];
		NSColor *bevelColor     = [selectionColor highlightWithLevel: 0.1f];
		NSGradient *background	= [[NSGradient alloc] initWithStartingColor: selectionColor
                                                                endingColor: fadeColor];
        
        [background drawInRect: self.bounds angle: 270.0f];
        
        NSRect topGroove = NSMakeRect(0, self.bounds.size.height - 1, self.bounds.size.width, 1);
        NSRect bottomGroove = NSMakeRect(0, 0, self.bounds.size.width, 1);
        NSRect topBevel = NSOffsetRect(topGroove, 0, -1);
        
        [bevelColor set];
        NSRectFill(topBevel);
        
        [fadeColor set];
        NSRectFill(topGroove);
        
        [shadowColor set];
        NSRectFill(bottomGroove);
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

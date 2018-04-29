/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDriveList.h"
#import "BXDriveItem.h"
#import "BXBaseAppController.h"
#import "BXDrive.h"
#import "BXDrivePanelController.h"
#import "ADBGeometry.h"
#import "NSShadow+ADBShadowExtensions.h"
#import "NSImage+ADBImageEffects.h"
#import "BXThemes.h"
#import "NSView+ADBDrawingHelpers.h"


@implementation BXDriveItemView

- (BOOL) mouseDownCanMoveWindow	{ return NO; }
- (BOOL) acceptsFirstMouse: (NSEvent *)theEvent { return YES; }

@end


@implementation BXDriveItemButtonCell

+ (NSString *) defaultThemeKey
{
    return @"BXInspectorListTheme";
}

- (id) initWithCoder: (NSCoder *)coder
{
    self = [super initWithCoder: coder];
    if (self)
    {
        self.highlightsBy = NSNoCellMask;
    }
    return self;
}

- (void) mouseEntered: (NSEvent *)event	{ self.hovered = YES; }
- (void) mouseExited: (NSEvent *)event	{ self.hovered = NO; }

- (void) setHovered: (BOOL)hover
{
	_hovered = hover;
	[self.controlView setNeedsDisplay: YES];
}

- (BOOL) showsBorderOnlyWhileMouseInside
{
	return YES;
}

- (NSGradient *) _fillForCurrentState
{
    if (self.isHighlighted)
        return self.themeForKey.pushedImageFill;
    
    if (self.isHovered)
        return self.themeForKey.highlightedImageFill;
    
    if (!self.isEnabled)
        return self.themeForKey.disabledImageFill;
    
    return self.themeForKey.imageFill;
}

- (NSShadow *) _innerShadowForCurrentState
{
    if (self.isHighlighted)
        return self.themeForKey.pushedImageInnerShadow;
    
    if (self.isHovered)
        return self.themeForKey.highlightedImageInnerShadow;
    
    if (!self.isEnabled)
        return self.themeForKey.disabledImageInnerShadow;
    
    return self.themeForKey.imageInnerShadow;
}

- (NSShadow *) _dropShadowForCurrentState
{
    if (self.isHighlighted)
        return self.themeForKey.pushedImageDropShadow;
    
    if (self.isHovered)
        return self.themeForKey.highlightedImageDropShadow;
    
    if (!self.isEnabled)
        return self.themeForKey.disabledImageDropShadow;
    
    return self.themeForKey.imageDropShadow;
}

- (NSRect) imageRectForBounds: (NSRect)theRect
{
    return NSInsetRect(theRect, 2, 2); //To safely accommodate our myriad possible drop shadow states
}

- (void) drawWithFrame: (NSRect)cellFrame inView: (NSView *)controlView
{
    [self drawImage: self.image withFrame: cellFrame inView: controlView];
}

- (void) drawImage: (NSImage *)image
         withFrame: (NSRect)cellFrame
            inView: (NSView *)controlView
{
	//Apply our foreground colour and shadow when drawing any template image
	if (image.isTemplate)
	{
        NSRect imageRect = [self imageRectForImage: image forBounds: cellFrame];
        imageRect = NSIntegralRect(imageRect);
        
        [NSGraphicsContext saveGraphicsState];
            [image drawInRect: imageRect
                 withGradient: self._fillForCurrentState
                   dropShadow: self._dropShadowForCurrentState
                  innerShadow: self._innerShadowForCurrentState
               respectFlipped: YES];
        [NSGraphicsContext restoreGraphicsState];
	}
	else
	{
		[super drawImage: image
               withFrame: cellFrame
                  inView: controlView];
	}
}
@end


@implementation BXDriveLetterCell
@synthesize themeKey = _themeKey;

+ (NSString *) defaultThemeKey
{
    return @"BXInspectorListTheme";
}

- (void) setThemeKey: (NSString *)key
{
    if (![key isEqual: self.themeKey])
    {
        _themeKey = [key copy];
        
        [self.controlView setNeedsDisplay: YES];
    }
}

- (BOOL) drawsBackground
{
    return NO;
}

- (void) drawInteriorWithFrame: (NSRect)frame inView: (NSView *)controlView
{
    BGTheme *theme = self.themeForKey;
    
    NSGradient *fill;
    NSShadow *innerShadow, *dropShadow;
    if (self.isEnabled)
    {
        fill = theme.imageFill;
        innerShadow = theme.imageInnerShadow;
        dropShadow = theme.imageDropShadow;
    }
    else
    {
        fill = theme.disabledImageFill;
        innerShadow = theme.disabledImageInnerShadow;
        dropShadow = theme.disabledImageDropShadow;
    }
    
    CGFloat titleSize = [NSFont systemFontSizeForControlSize: self.controlSize];
    NSFont *titleFont = [NSFont boldSystemFontOfSize: titleSize];
    NSDictionary *titleAttribs = @{
        NSForegroundColorAttributeName: [NSColor blackColor],
        NSFontAttributeName: titleFont,
    };
    
    frame = [self titleRectForBounds: controlView.bounds];
    NSRect titleFrame = [self.stringValue boundingRectWithSize: frame.size
                                                       options: NSStringDrawingUsesLineFragmentOrigin
                                                    attributes: titleAttribs];
    
    titleFrame = alignInRectWithAnchor(titleFrame, frame, NSMakePoint(0.5, 1));
    
    NSSize pillPadding = NSMakeSize(0.0, 2.0);
    NSSize pillMargin = NSMakeSize(2.0, 0.0);
    
    //Position the pill frame centered on the character being drawn,
    //filling the cell horizontally but constrained vertically to the height of the character plus padding.
    NSRect pillFrame = NSMakeRect(pillMargin.width,
                                  (titleFrame.origin.y - titleFont.descender) - pillPadding.height,
                                  frame.size.width - (pillMargin.width * 2),
                                  titleFont.capHeight + (pillPadding.height * 2)
    );
    
    pillFrame = NSIntegralRect(pillFrame);
    
    CGFloat cornerRadius = pillFrame.size.height * 0.5;
    NSBezierPath *backgroundPill = [NSBezierPath bezierPathWithRoundedRect: pillFrame
                                                                   xRadius: cornerRadius
                                                                   yRadius: cornerRadius];
    
    NSBezierPath *borderPill = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(pillFrame, 0.5f, 0.5f)
                                                               xRadius: cornerRadius - 0.5f
                                                               yRadius: cornerRadius - 0.5f];
    
    //When active, we display the drive letter knocked out on a solid background.
    //To do this, we first render the regular text to a temporary image, and then
    //the pill on top with a special compositing mode to knock out the drive letter.
    //We can then draw the rendered pill into the final view context.
    //(If we tried to draw everything directly into the view, we'd get really screwy
    //knockout effects and weird shadow behaviour and basically it just won't work.)
    
    NSImage *tempImage = [[NSImage alloc] init];
    tempImage.size = frame.size;
    
    [tempImage lockFocus];
        //[super drawInteriorWithFrame: frame inView: controlView];
        [[NSColor blackColor] set];
        [self.title drawWithRect: titleFrame options: NSStringDrawingUsesLineFragmentOrigin attributes: titleAttribs];
    
        if (self.isEnabled)
        {
            [NSGraphicsContext currentContext].compositingOperation = NSCompositeXOR;
            [backgroundPill fill];
        }
        else
        {
            [borderPill stroke];
        }
    [tempImage unlockFocus];
    
    tempImage.template = YES;
    [tempImage drawInRect: frame
             withGradient: fill
               dropShadow: dropShadow
              innerShadow: innerShadow
           respectFlipped: YES];
}
@end



@implementation BXDriveList

- (BOOL) mouseDownCanMoveWindow	{ return NO; }

#pragma mark - Selection behaviour

- (void) _selectItemAtPoint: (NSPoint)point
{
	NSView *clickedView = [self hitTest: point];
	
    //If the user clicked on our own background, instead of a drive element, then clear the selection
	if ([clickedView isEqual: self])
	{
        self.selectionIndexes = [NSIndexSet indexSet];
	}
    //Otherwise, go through the parents of the selected view to see if any of them are a drive element
    else
    {
        while (![clickedView isKindOfClass: [BXDriveItemView class]])
        {
            clickedView = clickedView.superview;
            if ([clickedView isEqual: self])
                return;
        }
        
		[(BXDriveItemView *)clickedView delegate].selected = YES;
    }
}

//This amounts to a complete reimplementation of NSCollectionView's default mouseDown implementation,
//just so that we can stick in our own drag functionality. Fuck. You.
- (void) mouseDown: (NSEvent *)theEvent
{
    //Fall back on the standard show-menu behaviour if the user control-clicks.
    if (theEvent.modifierFlags & NSControlKeyMask)
    {
        [self rightMouseDown: theEvent];
    }
    else
    {
        //Select the drive item that was clicked on.
        NSPoint clickPoint = [self convertPoint: theEvent.locationInWindow fromView: nil];
        [self _selectItemAtPoint: clickPoint];
        
        //Otherwise, if we have a selection, open a mouse tracking loop of our own
        //here in mouseDown and break out of it for mouseUp and mouseDragged.
        while (self.selectionIndexes.count)
        {
            NSEvent *eventInDrag = [self.window nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
            switch (eventInDrag.type)
            {
                case NSLeftMouseDragged:
                    [self _beginDragOperationWithEvent: eventInDrag];
                    return;
                case NSLeftMouseUp:
                    [self mouseUp: eventInDrag];
                    return;
            }
        };
    }
}

//If the user Cmd-clicked, reveal the drive in Finder
- (void) mouseUp: (NSEvent *)theEvent
{
    //If the user double-clicked: trigger a drive-mount action or a reveal action,
    //depending on the Cmd key modifier
	if (theEvent.clickCount > 1)
	{
        SEL action;
        if (theEvent.modifierFlags & NSCommandKeyMask)
            action = @selector(revealSelectedDrivesInFinder:);
        else
            action = @selector(mountSelectedDrives:);
        
		[NSApp sendAction: action to: self.delegate from: self];
	}
}

- (void) keyDown: (NSEvent *)theEvent
{
    //Mount the selected drive(s) when the user presses Space.
    //(TWEAK: this used to be a toggle, i.e. unmount the drive if it was already mounted,
    //but that proved to feel weird and unexpected.)
    if ([theEvent.charactersIgnoringModifiers isEqualToString: @" "])
    {
        [NSApp sendAction: @selector(mountSelectedDrives:) to: self.delegate from: self];
    }
    //Open the selected drive(s) in Finder when the user presses Return.
    else if ([theEvent.charactersIgnoringModifiers isEqualToString: @"\r"])
    {
        [NSApp sendAction: @selector(revealSelectedDrivesInFinder:) to: self.delegate from: self];
    }
    //Remove the selected drive(s) from the drive list when the user presses Cmd+Backspace.
    else if ([theEvent.charactersIgnoringModifiers isEqualToString: @"\x7f"] &&
             (theEvent.modifierFlags & NSCommandKeyMask))
    {
        [NSApp sendAction: @selector(removeSelectedDrives:) to: self.delegate from: self];
    }
    else
    {
        [super keyDown: theEvent];
    }
}

- (BXDriveItem *) itemForDrive: (BXDrive *)drive
{
	for (BXDriveItemView *view in self.subviews)
	{
        BXDriveItem *item = (BXDriveItem *)view.delegate;
		if ([item.drive isEqual: drive])
            return item;
	}
	return nil;
}


#pragma mark -
#pragma mark Drag-dropping

- (NSImage *) draggingImageForItemsAtIndexes: (NSIndexSet *)indexes
                                   withEvent: (NSEvent *)event
                                      offset: (NSPointPointer)dragImageOffset
{
    //TODO: render images for all selected drives, once we allow more than one
    NSView *selectedItemView = [self itemAtIndex: indexes.firstIndex].view;
    return [selectedItemView imageWithContentsOfRect: selectedItemView.bounds];
}

- (void) _beginDragOperationWithEvent: (NSEvent *)theEvent
{
    //Ignore the drag if we have nothing selected.
    if (!self.selectionIndexes.count) return;
    
    //Make a new pasteboard and get our delegate to set it up for us
	NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName: NSDragPboard];
    
    BOOL continueDrag = [self.delegate collectionView: self
                                  writeItemsAtIndexes: self.selectionIndexes
                                         toPasteboard: pasteboard];
    
    if (continueDrag)
    {
        //Choose one out of the selected items to be the visible source of the drag
        NSPoint dragImageOffset = NSZeroPoint;
        NSImage *draggedImage = [self draggingImageForItemsAtIndexes: self.selectionIndexes
                                                           withEvent: theEvent
                                                              offset: &dragImageOffset];
    
        NSView *selectedItemView = [self itemAtIndex: self.selectionIndexes.firstIndex].view;
        
        //dragImage:at:etc takes a coordinate at which to place the *lower left* corner
        //of the images.
        NSPoint viewOffset;
        if (self.isFlipped)
        {
            viewOffset = NSMakePoint(NSMinX(selectedItemView.frame),
                                     NSMaxY(selectedItemView.frame));
        }
        else
        {
            viewOffset = NSMakePoint(NSMinX(selectedItemView.frame),
                                     NSMinY(selectedItemView.frame));
        }
        
        [self dragImage: draggedImage
                     at: viewOffset
                 offset: NSZeroSize
                  event: theEvent
             pasteboard: pasteboard
                 source: self.delegate
              slideBack: NO];
    }
}

@end

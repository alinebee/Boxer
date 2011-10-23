/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDriveList.h"
#import "BXAppController.h"
#import "BXDrive.h"
#import "BXDrivePanelController.h"
#import "BXGeometry.h"
#import "NSShadow+BXShadowExtensions.h"
#import "NSImage+BXImageEffects.h"


@implementation BXDriveItemView

- (BOOL) mouseDownCanMoveWindow	{ return NO; }
- (BOOL) acceptsFirstMouse: (NSEvent *)theEvent { return YES; }

@end


@implementation BXDriveItemButtonCell
@synthesize hovered;

- (id) initWithCoder: (NSCoder *)coder
{
	if ((self = [super initWithCoder: coder]))
	{
		[self setHighlightsBy: NSNoCellMask];
	}
	return self;
}
- (void) mouseEntered: (NSEvent *)event	{ [self setHighlighted: YES]; }
- (void) mouseExited: (NSEvent *)event	{ [self setHighlighted: NO]; }
- (void) setHighlighted: (BOOL)hover
{
	hovered = hover;
	[[self controlView] setNeedsDisplay: YES];
}

- (BOOL) showsBorderOnlyWhileMouseInside
{
	return YES;
}

- (void) drawImage: (NSImage *)image
         withFrame: (NSRect)frame
            inView: (NSView *)controlView
{
	CGFloat opacity;
	NSColor *tint;

	if ([self isEnabled])
	{
        tint = [NSColor whiteColor];
		if ([self isHighlighted])   opacity = 1.0f;
		else if ([self isHovered])  opacity = 0.75f;
        else                        opacity = 0.5f;
	}
	else
	{
		tint = [NSColor blackColor];
		opacity = 0.25f;
	}
	
	if ([image isTemplate])
	{
		image = [image imageFilledWithColor: tint
                                     atSize: frame.size];
	}
	
	[image drawInRect: frame
			 fromRect: NSZeroRect
			operation: NSCompositeSourceOver
			 fraction: opacity
       respectFlipped: YES];
}
@end


@implementation BXDriveLetterCell

- (BOOL) drawsBackground
{
    return NO;
}

- (NSColor *) textColor
{
    if ([self isEnabled])
        return [NSColor whiteColor];
    else
        return [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.5f];
}

- (NSColor *) backgroundColor
{
    if ([self isEnabled])
        return [NSColor whiteColor];
    else
        return [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.5f];
}

- (NSColor *) borderColor
{
    if ([self isEnabled])
        return [NSColor whiteColor];
    else
        return [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.25f];
}

- (NSShadow *) dropShadow
{
    return [NSShadow shadowWithBlurRadius: 3.0f offset: NSMakeSize(0, -1.0f)];
}

- (NSShadow *) textShadow
{
    return [self dropShadow];
}

- (void) drawInteriorWithFrame: (NSRect)frame inView: (NSView *)controlView
{
    NSShadow *dropShadow = [self dropShadow];
    NSRect frameForShadow = [dropShadow insetRectForShadow: frame flipped: NO];
    CGFloat cornerRadius = frameForShadow.size.height / 2;
    NSBezierPath *backgroundPill = [NSBezierPath bezierPathWithRoundedRect: frameForShadow
                                                                   xRadius: cornerRadius
                                                                   yRadius: cornerRadius];
    
    NSBezierPath *borderPill = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(frameForShadow, 0.5f, 0.5f)
                                                               xRadius: cornerRadius - 0.5f
                                                               yRadius: cornerRadius - 0.5f];
    
    
    //When active, we display the drive letter knocked out on a solid background.
    //To do this, we first render the regular text to a temporary image, and then
    //the pill on top with a special compositing mode to knock out the drive letter.
    //We can then draw the rendered pill into the final view context.
    //(If we tried to draw everything directly into the view, we'd get really screwy
    //knockout effects and weird shadow behaviour and basically it just won't work.)
    
    NSImage *tempImage = [[NSImage alloc] init];
    [tempImage setSize: frame.size];
    
    [tempImage lockFocus];
        [super drawInteriorWithFrame: frame inView: controlView];
        if ([self isEnabled])
        {
            [[self backgroundColor] set];
            [[NSGraphicsContext currentContext] setCompositingOperation: NSCompositeSourceOut];
            [backgroundPill fill];
        }
        else
        {
            [[self borderColor] set];
            [borderPill stroke];
        }
    [tempImage unlockFocus];
    
    [[NSGraphicsContext currentContext] saveGraphicsState];
        [[self dropShadow] set];
    
        [tempImage drawInRect: frame
                     fromRect: NSZeroRect
                    operation: NSCompositeSourceOver
                     fraction: 1.0f
               respectFlipped: YES];
    [[NSGraphicsContext currentContext] restoreGraphicsState];
    
    [tempImage release];
}
@end



@implementation BXDriveList
@synthesize delegate;

- (BOOL) mouseDownCanMoveWindow	{ return NO; }


#pragma mark -
#pragma mark Selection behaviour

- (void) _selectItemAtPoint: (NSPoint)point
{
	NSView *clickedView = [self hitTest: point];
	
    //If the user clicked on our own background, instead of a drive element, then clear the selection
	if ([clickedView isEqual: self])
	{
		[self setSelectionIndexes: [NSIndexSet indexSet]];
	}
    //Otherwise, go through the parents of the selected view to see if any of them are a drive element
    else
    {
        while (![clickedView isKindOfClass: [BXDriveItemView class]])
        {
            clickedView = [clickedView superview];
            if ([clickedView isEqual: self]) return;
        }
        
		[[(BXDriveItemView *)clickedView delegate] setSelected: YES];
    }
}

//This amounts to a complete reimplementation of NSCollectionView's default mouseDown implementation,
//just so that we can stick in our own drag functionality. Fuck. You.
- (void) mouseDown: (NSEvent *)theEvent
{	
	NSPoint clickPoint = [self convertPoint: [theEvent locationInWindow] fromView: nil];
	[self _selectItemAtPoint: clickPoint];
	
	//If we have a selection, open a mouse tracking loop of our own here in mouseDown
	//and break out of it for mouseUp and mouseDragged.
    while ([[self selectionIndexes] count])
	{
        NSEvent *eventInDrag = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
        switch ([eventInDrag type])
		{
            case NSLeftMouseDragged: 
				return [self mouseDragged: eventInDrag];
			case NSLeftMouseUp:
				return [self mouseUp: eventInDrag];
        }
    };
}

//If the user Cmd-clicked, reveal the drive in Finder
- (void) mouseUp: (NSEvent *)theEvent
{
    //If the user double-clicked, trigger a drive-mount action or a reveal action, depending on the Cmd key modifier
	if ([theEvent clickCount] > 1)
	{
        SEL action;
        if ([theEvent modifierFlags] & NSCommandKeyMask) action = @selector(revealSelectedDrivesInFinder:);
        else action = @selector(mountSelectedDrives:);
        
		[NSApp sendAction: action to: [self delegate] from: self];
	}
}

- (BXDriveItemView *) viewForDrive: (BXDrive *)drive
{
	for (BXDriveItemView *view in [self subviews])
	{
		if ([[[view delegate] representedObject] isEqual: drive]) return view;
	}
	return nil;
}


- (BXDriveItem *) itemForDrive: (BXDrive *)drive
{
	for (BXDriveItemView *view in [self subviews])
	{
        BXDriveItem *item = (id)[view delegate];
		if ([[item representedObject] isEqual: drive]) return item;
	}
	return nil;
}


#pragma mark -
#pragma mark Drag-dropping

- (NSDragOperation) draggingSourceOperationMaskForLocal: (BOOL)isLocal
{
	return (isLocal) ? NSDragOperationPrivate : NSDragOperationNone;
}

- (NSImage *) draggingImageForItemsAtIndexes: (NSIndexSet *)indexes
                                   withEvent: (NSEvent *)event
                                      offset: (NSPointPointer)dragImageOffset
{
    //TODO: render images for all selected drives, once we allow more than one
    BXDrive *firstSelectedDrive = [[self content] objectAtIndex: [indexes firstIndex]];
    NSView *itemView = [self viewForDrive: firstSelectedDrive];
    if (itemView)
    {
        NSData *imageData = [itemView dataWithPDFInsideRect: [itemView bounds]];
        return [[[NSImage alloc] initWithData: imageData] autorelease];
    }
    else return nil;
}

- (void) mouseDragged: (NSEvent *)theEvent
{
    NSIndexSet *indexes = [self selectionIndexes];
    
    //Ignore the drag if we have nothing selected.
    if (![indexes count]) return;
    
    //Make a new pasteboard and get our delegate to set it up for us
	NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName: NSDragPboard];
    
    BOOL continueDrag = [[self delegate] collectionView: self
                                    writeItemsAtIndexes: [self selectionIndexes]
                                           toPasteboard: pasteboard];
    
    if (continueDrag)
    {
        //Choose one out of the selection to be the visible source of the drag
        NSImage *draggedImage   = [self draggingImageForItemsAtIndexes: indexes
                                                             withEvent: theEvent
                                                                offset: nil];
    
        BXDrive *firstSelectedDrive = [[self content] objectAtIndex: [indexes firstIndex]];
        NSView *itemView = [self viewForDrive: firstSelectedDrive];
        
        [itemView dragImage: draggedImage
                         at: NSZeroPoint
                     offset: NSZeroSize
                      event: theEvent
                 pasteboard: pasteboard
                     source: [self delegate]
                  slideBack: NO];
    }
}

@end

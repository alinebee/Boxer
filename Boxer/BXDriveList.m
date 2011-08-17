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



//The tags of the component parts of drive item views
enum {
	BXDriveItemLetterLabel			= 1,
	BXDriveItemNameLabel			= 2,
	BXDriveItemTypeLabel			= 3,
	BXDriveItemIcon					= 4,
	BXDriveItemProgressMeterLabel	= 5,
	BXDriveItemProgressMeterCancel	= 6
};


@implementation BXDriveItemView

//Quick accessors for our subviews
- (NSImageView *) driveIcon				{ return [self viewWithTag: BXDriveItemIcon]; }
- (NSTextField *) driveTypeLabel		{ return [self viewWithTag: BXDriveItemTypeLabel]; }
- (NSTextField *) displayNameLabel		{ return [self viewWithTag: BXDriveItemNameLabel]; }
- (NSTextField *) letterLabel			{ return [self viewWithTag: BXDriveItemLetterLabel]; }
- (NSTextField *) progressMeterLabel	{ return [self viewWithTag: BXDriveItemProgressMeterLabel]; }
- (NSButton *) progressMeterCancel		{ return [self viewWithTag: BXDriveItemProgressMeterCancel]; }

//Progress meters don't have a tag field, which means we have to track the damn thing down by hand
//(Limiting us to only having one progress meter in the entire view)
- (NSProgressIndicator *) progressMeter
{
	for (id view in [self subviews])
	{
		if ([view isKindOfClass: [NSProgressIndicator class]]) return view;
	}
	return nil;
}

- (BOOL) mouseDownCanMoveWindow	{ return NO; }
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

- (void) drawImage: (NSImage *)image withFrame: (NSRect)frame inView: (NSView *)controlView
{
	CGFloat opacity = 0.5f;
	NSColor *tint = [NSColor whiteColor];
	
	if (![self isEnabled])
	{
		tint = [NSColor blackColor];
		opacity = 0.25f;
	}
	else
	{
		if ([self isHighlighted])  opacity = 1.0f;
		else if ([self isHovered]) opacity = 0.75f;
	}
	
	if ([image isTemplate])
	{
		NSImage *tintedImage = [image copy];
		[tintedImage setSize: frame.size];
		
		NSRect bounds = NSZeroRect;
		bounds.size = [tintedImage size];
		
		
		[tintedImage lockFocus];
			[tint set];
			NSRectFillUsingOperation(bounds, NSCompositeSourceAtop);
		[tintedImage unlockFocus];
		
		image = [tintedImage autorelease];
	}
	
	[image drawInRect: frame
			 fromRect: NSZeroRect
			operation: NSCompositeSourceOver
			 fraction: opacity];
}
@end



@implementation BXDriveList
@synthesize delegate;

- (BOOL) mouseDownCanMoveWindow	{ return NO; }


#pragma mark -
#pragma mark Selection behaviour

- (void) _selectItemAtPoint: (NSPoint)point
{
	id clickedView = [self hitTest: point];
	
	if ([clickedView isKindOfClass: [BXDriveItemView class]])
	{
		[[clickedView delegate] setSelected: YES];
	}
	else
	{
		//Clear our selection
		[self setSelectionIndexes: [NSIndexSet indexSet]];
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
	if ([theEvent clickCount] > 1 && ([theEvent modifierFlags] & NSCommandKeyMask))
	{
		[NSApp sendAction: @selector(revealSelectedDrivesInFinder:) to: [self delegate] from: self];
	}
}

- (NSArray *) selectedViews
{	
	NSMutableArray *selectedViews = [NSMutableArray arrayWithCapacity: [[self selectionIndexes] count]];
	
	for (BXDriveItemView *view in [self subviews])
	{
		if ([[view delegate] isSelected]) [selectedViews addObject: view];
	}
	return (NSArray *)selectedViews;
}

- (BXDriveItemView *) viewForDrive: (BXDrive *)drive
{
	for (BXDriveItemView *view in [self subviews])
	{
		if ([[[view delegate] representedObject] isEqual: drive]) return view;
	}
	return nil;
}

#pragma mark -
#pragma mark Drag-dropping

- (NSDragOperation) draggingSourceOperationMaskForLocal: (BOOL)isLocal
{
	return (isLocal) ? NSDragOperationPrivate : NSDragOperationNone;
}

- (NSImage *) draggableImageFromView: (NSView *)itemView
{
	NSData *imageData = [itemView dataWithPDFInsideRect: [itemView bounds]];
	return [[[NSImage alloc] initWithData: imageData] autorelease];
}

- (void) mouseDragged: (NSEvent *)theEvent
{		
    //Make a new pasteboard and get our delegate to set it up for us
	NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName: NSDragPboard];
    
    BOOL continueDrag = [[self delegate] collectionView: self
                                    writeItemsAtIndexes: [self selectionIndexes]
                                           toPasteboard: pasteboard];
    
    if (continueDrag)
    {
        //Hide all of the selected views while we drag them, and choose one to be the visible source of the drag
        NSArray *selectedViews = [self selectedViews];
        NSView *draggedView = [selectedViews lastObject];
        NSImage *draggedImage = [self draggableImageFromView: draggedView];
        
        for (NSView *itemView in selectedViews) [itemView setHidden: YES];
        
        //Implementation note: slideBack would be nice but it can't be cancelled by the source :(
        //Which we would want to do after discarding the drive.
        [draggedView dragImage: draggedImage
                            at: NSZeroPoint
                        offset: NSZeroSize
                         event: theEvent
                    pasteboard: pasteboard
                        source: self
                     slideBack: NO];
    }
}

//While dragging, this checks for valid Boxer windows under the cursor; if there aren't any, it displays
//a disappearing item cursor (poof) to indicate the action will discard the dragged drive(s).
- (void) draggedImage: (NSImage *)draggedImage movedTo: (NSPoint)screenPoint
{	
	NSPoint mousePoint = [NSEvent mouseLocation];
	NSCursor *poof = [NSCursor disappearingItemCursor];
	
	//If there's no Boxer window under the mouse cursor,
	//change the cursor to a poof to indicate we will discard the drive
	if (![(BXAppController *)[NSApp delegate] windowAtPoint: mousePoint]) [poof set];
	
	//otherwise, revert any poof cursor (which may already have been changed by valid drag destinations anyway) 
	else if ([[NSCursor currentCursor] isEqual: poof]) [[NSCursor arrowCursor] set];
}

//This is called when dragging completes, and discards the drive if it was not dropped onto a valid destination
//(or back onto the drive list).
- (void) draggedImage: (NSImage *)draggedImage
			  endedAt: (NSPoint)screenPoint
		    operation: (NSDragOperation)operation
{
	NSPoint mousePoint = [NSEvent mouseLocation];
	
	if (operation == NSDragOperationNone && ![(BXAppController *)[NSApp delegate] windowAtPoint: mousePoint])
	{
		//Send the remove-these-drives action and see whether any drives were removed
		//(IBActions do not provide a return value, so we can't find out directly
		//if the action succeeded or failed)
		NSUInteger oldItems = [[self content] count];
		[NSApp sendAction: @selector(unmountSelectedDrives:) to: [self delegate] from: self];
		NSUInteger newItems = [[self content] count];
		
		//If any drives were removed by the action, display the poof animation
		if (newItems < oldItems)
		{		
			//Calculate the center-point of the image for displaying the poof icon
			NSRect imageRect;
			imageRect.size		= [draggedImage size];
			imageRect.origin	= screenPoint;	

			NSPoint midPoint = NSMakePoint(NSMidX(imageRect), NSMidY(imageRect));

			//We make it square instead of fitting the width of the image,
			//because the image may include a big fat horizontal margin 
			NSSize poofSize = imageRect.size;
			poofSize.width = poofSize.height;
			
			//Play the poof animation
			NSShowAnimationEffect(NSAnimationEffectPoof, midPoint, poofSize, nil, nil, nil);
		}
		
		//Reset the cursor back to normal in any case
		[[NSCursor arrowCursor] set];
	}
	
	//Once the drag has finished, clean up by unhiding the dragged items
	for (NSView *itemView in [self selectedViews]) [itemView setHidden: NO];
}

@end

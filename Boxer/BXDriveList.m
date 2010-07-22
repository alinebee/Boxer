/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDriveList.h"
#import "BXAppController.h"
#import "BXDrive.h"
#import "BXInspectorController.h"

#import "NSBezierPath+MCAdditions.h"

@implementation BXDriveItemView
@synthesize delegate;

- (BOOL) mouseDownCanMoveWindow	{ return NO; }
- (BOOL) acceptsFirstMouse: (NSEvent *)theEvent { return YES; }

//Select ourselves and pass menu events up to our parent
- (NSMenu *) menuForEvent:(NSEvent *)event
{
	[[self delegate] setSelected: YES];
	return [[self superview] menuForEvent: event];
}

//Overridden so that we indicate that every click has hit us instead of our descendants.
- (NSView *) hitTest: (NSPoint)thePoint
{
	NSView *hitView = [super hitTest: thePoint];
	if (hitView != nil) hitView = self;
	return hitView;
}

- (void) drawRect: (NSRect)dirtyRect
{	
	if ([[self delegate] isSelected])
	{
		NSColor *selectionColor	= [NSColor alternateSelectedControlColor];
		NSColor *shadowColor	= [selectionColor shadowWithLevel: 0.4f];
		NSGradient *background	= [[NSGradient alloc] initWithStartingColor: selectionColor
																endingColor: shadowColor];
		
		NSShadow *dropShadow = [[NSShadow alloc] init];
		[dropShadow setShadowOffset: NSMakeSize(0.0f, -0.5f)];
		[dropShadow setShadowBlurRadius: 2.0f];
		[dropShadow setShadowColor: [[NSColor blackColor] colorWithAlphaComponent: 0.85f]];
		
		NSShadow *innerGlow = [[NSShadow alloc] init];
		[innerGlow setShadowOffset: NSZeroSize];
		[innerGlow setShadowBlurRadius: 2.0f];
		[innerGlow setShadowColor: [[NSColor whiteColor] colorWithAlphaComponent: 0.5f]];
		
		NSRect backgroundRect = NSInsetRect([self bounds], 3.0f, 2.0f);
		NSBezierPath *backgroundPath = [NSBezierPath bezierPathWithRoundedRect:backgroundRect xRadius: 3.0f yRadius: 3.0f];
		
		[NSGraphicsContext saveGraphicsState];
			[dropShadow set];
		
			//Necessary only so that drop shadow gets drawn: it won't be by NSGradient drawInBezierPath:angle:
			[selectionColor set];
			[backgroundPath fill];
		
			//Now draw the gradient on top
			[background drawInBezierPath: backgroundPath angle: 270.0f];
		[NSGraphicsContext restoreGraphicsState];
		
		//Draw the glow last on top of everything else
		[backgroundPath fillWithInnerShadow: innerGlow];
		
		[background release];
		[dropShadow release];
		[innerGlow release];
	}
}
@end


@implementation BXDriveList

- (BOOL) acceptsFirstMouse: (NSEvent *)theEvent { return YES; }

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return (isLocal) ? NSDragOperationPrivate : NSDragOperationNone;
}


- (NSImage *)draggableImageFromView:(NSView *)itemView
{
	NSData *imageData = [itemView dataWithPDFInsideRect: [itemView bounds]];
	return [[[NSImage alloc] initWithData: imageData] autorelease];
}

- (void) selectItemAtPoint: (NSPoint)point
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
	//Redraw selection in our subviews
	[self setNeedsDisplay: YES];
}

//This amounts to a complete reimplementation of NSCollectionView's default mouseDown implementation, just so that we can stick in our own drag functionality. Fuck. You.
- (void) mouseDown: (NSEvent *)theEvent
{	
	NSPoint clickPoint = [self convertPoint: [theEvent locationInWindow] fromView: nil];
	[self selectItemAtPoint: clickPoint];
	
	//If we have a selection, open a mouse tracking loop of our own here in mouseDown and break out of it for mouseUp and mouseDragged.
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

- (void) mouseDragged: (NSEvent *)theEvent
{		
	//Get a list of all file paths of the selected drives
	NSMutableArray *filePaths = [NSMutableArray arrayWithCapacity: [[self selectionIndexes] count]];
	for (BXDrive *drive in [self selectedObjects]) [filePaths addObject: [drive path]];
	
	//Make a new pasteboard with the paths 
	NSPasteboard *pboard = [NSPasteboard pasteboardWithName: NSDragPboard];
	[pboard declareTypes:[NSArray arrayWithObject: NSFilenamesPboardType] owner:self];	
	[pboard setPropertyList: filePaths forType: NSFilenamesPboardType];
	

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
				pasteboard: pboard
					source: self
				 slideBack: NO];
}

- (void) mouseUp: (NSEvent *)theEvent
{
	if ([theEvent clickCount] > 1 && ([theEvent modifierFlags] & NSCommandKeyMask))
		[NSApp sendAction: @selector(revealSelectedDrivesInFinder:) to: nil from: self];
}

//Select/deselect item at click point before showing our menu
- (NSMenu *) menuForEvent: (NSEvent *)theEvent
{
	NSPoint clickPoint = [self convertPoint: [theEvent locationInWindow] fromView: nil];
	[self selectItemAtPoint: clickPoint];
	return [super menuForEvent: theEvent];
}

//While dragging, this checks for valid Boxer windows under the cursor; if there aren't any, it displays
//a disappearing item cursor (poof) to indicate the action will discard the dragged drive(s).
- (void)draggedImage:(NSImage *)draggedImage movedTo:(NSPoint)screenPoint
{	
	NSPoint mousePoint = [NSEvent mouseLocation];
	NSCursor *poof = [NSCursor disappearingItemCursor];
	
	//If there's no Boxer window under the mouse cursor, change the cursor to a poof to indicate we will discard the drive
	if (![(BXAppController *)[NSApp delegate] windowAtPoint: mousePoint]) [poof set];
	//otherwise, revert any poof cursor (which may already have been changed by valid drag destinations anyway) 
	else if ([[NSCursor currentCursor] isEqualTo: poof]) [[NSCursor arrowCursor] set];
}

//This is called when dragging completes, and discards the drive if it was not dropped onto a valid destination
//(or back onto the drive list).
- (void)draggedImage:(NSImage *)draggedImage endedAt:(NSPoint)screenPoint operation:(NSDragOperation)operation
{
	NSPoint mousePoint = [NSEvent mouseLocation];
	
	if (operation == NSDragOperationNone && ![(BXAppController *)[NSApp delegate] windowAtPoint: mousePoint])
	{
		//Send the remove-these-drives action and see whether any drives were removed
		//(IBActions do not provide a return value, so we can't find out directly if the action succeeded or failed)
		NSUInteger oldItems = [[self content] count];
		[NSApp sendAction: @selector(unmountSelectedDrives:) to: [[self window] windowController] from: self];
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


//My god what a pain in the ass
//We can't just grab array controller's selected objects because we don't know about the array controller;
//we're only bound to its contents and its selectionIndexes, not its selectedObjects :(
- (NSArray *) selectedObjects
{
	NSIndexSet *selection	= [self selectionIndexes];
	NSArray *values			= [self content];
	NSUInteger i, numValues	= [values count];
	NSMutableArray *selectedObjects = [NSMutableArray arrayWithCapacity: [selection count]];
	
	for (i=0; i<numValues; i++)
	{
		if ([selection containsIndex: i]) [selectedObjects addObject: [values objectAtIndex: i]];
	}
	return (NSArray *)selectedObjects;
}

- (NSArray *) selectedViews
{	
	NSMutableArray *selectedItems = [NSMutableArray arrayWithCapacity: [[self selectionIndexes] count]];

	for (BXDriveItemView *item in [self subviews])
	{
		if ([[item delegate] isSelected]) [selectedItems addObject: item];
	}
	return (NSArray *)selectedItems;
}

@end

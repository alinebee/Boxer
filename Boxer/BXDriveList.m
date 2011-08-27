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


//The tags of the component parts of drive item views
enum {
	BXDriveItemLetterLabel			= 1,
	BXDriveItemNameLabel			= 2,
	BXDriveItemTypeLabel			= 3,
	BXDriveItemIcon					= 4,
	BXDriveItemProgressMeterLabel	= 5,
	BXDriveItemProgressMeterCancel	= 6
};

@implementation BXDriveItem

- (NSImage *) icon
{
    NSString *iconName;
    switch ([(BXDrive *)[self representedObject] type])
    {
        case BXDriveCDROM:
            iconName = @"CDROMTemplate";
            break;
        case BXDriveFloppyDisk:
            iconName = @"DisketteTemplate";
            break;
        default:
            iconName = @"HardDiskTemplate";
    }
    
    return [NSImage imageNamed: iconName];
}

- (NSString *) typeDescription
{
    NSString *description = [(BXDrive *)[self representedObject] typeDescription];
    if (![[self representedObject] isMounted])
    {
        NSString *inactiveDescriptionFormat = NSLocalizedString(@"%@ (ejected)", @"Description format for inactive drives. %@ is the original description of the drive (e.g. 'CD-ROM', 'hard disk' etc.)");
        description = [NSString stringWithFormat: inactiveDescriptionFormat, description, nil];
    }
    return description;
}

+ (NSSet *) keyPathsForValuesAffectingTypeDescription
{
    return [NSSet setWithObjects: @"representedObject.typeDescription", @"representedObject.mounted", nil];
}

+ (NSSet *) keyPathsForValuesAffectingTextColor
{
    return [NSSet setWithObject: @"representedObject.type"];
}

+ (NSSet *) keyPathsForValuesAffectingIcon
{
    return [NSSet setWithObject: @"representedObject.type"];
}
@end


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


@implementation BXDriveLetterCell

- (BOOL) drawsBackground
{
    return NO;
}

- (NSColor *) backgroundColor
{
    if ([self isEnabled])
        return [NSColor whiteColor];
    else
        return [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.5f];
}

- (NSShadow *) dropShadow
{
    return [NSShadow shadowWithBlurRadius: 3.0f offset: NSMakeSize(0, -1.0f)];
}

- (void) drawInteriorWithFrame: (NSRect)frame inView: (NSView *)controlView
{
    NSShadow *dropShadow = [self dropShadow];
    NSRect frameForShadow = [dropShadow insetRectForShadow: frame];
    CGFloat cornerRadius = frameForShadow.size.height / 2;
    NSBezierPath *pill = [NSBezierPath bezierPathWithRoundedRect: frameForShadow
                                                         xRadius: cornerRadius
                                                         yRadius: cornerRadius];
    
    //We render the drive letter knocked out on a solid background.
    //To do this, we first render the regular text to a temporary image, and then
    //the pill on top with a special compositing mode to knock out the drive letter.
    //We can then draw the rendered pill into the final view context.
    //(If we tried to draw everything directly into the view, we'd get really screwy
    //knockout effects and weird shadow behaviour and basically it just won't work.)
    
    NSImage *tempImage = [[NSImage alloc] init];
    [tempImage setSize: frame.size];
    [tempImage lockFocus];
        [super drawInteriorWithFrame: frame inView: controlView];
        
        [[NSGraphicsContext currentContext] setCompositingOperation: NSCompositeSourceOut];
    
        [[self backgroundColor] set];
        [pill fill];
    [tempImage unlockFocus];
    
    [[NSGraphicsContext currentContext] saveGraphicsState];
        [[self dropShadow] set];
        [tempImage drawInRect: frame
                     fromRect: NSZeroRect
                    operation: NSCompositeSourceOver
                     fraction: 1.0f];
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
                //If the user double-clicked, trigger a drive-mount action
                if ([eventInDrag clickCount] > 1)
                    [NSApp sendAction: @selector(mountSelectedDrives:) to: [self delegate] from: self];
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
    return [[self subviews] objectsAtIndexes: [self selectionIndexes]];
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

- (NSImage *) draggingImageForItemsAtIndexes: (NSIndexSet *)indexes
                                   withEvent: (NSEvent *)event
                                      offset: (NSPointPointer)dragImageOffset
{
    NSView *itemView = [[self selectedViews] lastObject];
    if (itemView)
    {
        NSData *imageData = [itemView dataWithPDFInsideRect: [itemView bounds]];
        return [[[NSImage alloc] initWithData: imageData] autorelease];
    }
    else return nil;
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
        //Choose one out of the selection to be the visible source of the drag
        NSArray *selectedViews  = [self selectedViews];
        NSView *draggedView     = [selectedViews lastObject];
        
        NSImage *draggedImage   = [self draggingImageForItemsAtIndexes: [self selectionIndexes]
                                                             withEvent: theEvent
                                                                offset: nil];
        
        [draggedView dragImage: draggedImage
                            at: NSZeroPoint
                        offset: NSZeroSize
                         event: theEvent
                    pasteboard: pasteboard
                        source: [self delegate]
                     slideBack: NO];
    }
}

@end

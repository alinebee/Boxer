#import "BXInspectorController.h"
#import "BXSession+BXDragDrop.h"
#import "BXEmulator.h"
#import "BXDrive.h"
#import "BXAppController.h"
#import "BXValueTransformers.h"


@implementation BXInspectorController
@synthesize panelContainer;
@synthesize gamePanel, cpuPanel, drivePanel;
@synthesize panelSelector;
@synthesize driveController;

+ (void) initialize
{
	BXDisplayPathTransformer *displayPath	= [[BXDisplayPathTransformer alloc] initWithJoiner: @" ▸ " maxComponents: 0];
	BXDisplayNameTransformer *displayName	= [BXDisplayNameTransformer new];
	BXImageSizeTransformer *imageSize = [[BXImageSizeTransformer alloc] initWithSize: NSMakeSize(16, 16)];
	
	[NSValueTransformer setValueTransformer: displayPath forName: @"BXDriveDisplayPath"];
	[NSValueTransformer setValueTransformer: displayPath forName: @"BXDocumentationDisplayPath"];
	[NSValueTransformer setValueTransformer: displayName forName: @"BXDocumentationDisplayName"];
	[NSValueTransformer setValueTransformer: imageSize forName: @"BXDocumentationIconSize"];
	
	[displayPath release];
	[displayName release];
	[imageSize release];

}

+ (BXInspectorController *)controller
{
	static BXInspectorController *singleton = nil;
	if (!singleton) singleton = [[self alloc] initWithWindowNibName: @"InspectorPanel"];
	return singleton;
}

- (void) dealloc
{
	[self setPanelContainer: nil],	[panelContainer release];
	[self setGamePanel: nil],		[gamePanel release];
	[self setCpuPanel: nil],		[cpuPanel release];
	[self setDrivePanel: nil],		[drivePanel release];
	[self setPanelSelector: nil],	[panelSelector release];
	[self setDriveController: nil], [driveController release];
	
	[super dealloc];
}

- (void) awakeFromNib
{	
	NSWindow *theWindow = [self window];

	//Note that we actually only accept drag-drop on the drive panel: see draggingEntered et. al. below.
	[theWindow registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil]];

	[theWindow setAcceptsMouseMovedEvents: YES];
		
	[theWindow setFrameAutosaveName: @"InspectorPanel"];
	
	//Set the initial panel based on the user's last chosen panel (defaulting to the CPU panel)
	NSView *initialView;
	NSArray *panels = [self panels];
	NSUInteger selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey: @"initialInspectorPanelIndex"];
	
	if (selectedIndex < [panels count]) initialView = [panels objectAtIndex: selectedIndex];
	else initialView = [self cpuPanel];
	
	[self setCurrentPanel: initialView];
}

- (NSArray *) panels
{
	return [NSArray arrayWithObjects:
		[self gamePanel], [self cpuPanel], [self drivePanel],
	nil];
}

- (NSView *) currentPanel
{
	return [[[self panelContainer] subviews] lastObject];
}

- (void) setCurrentPanel: (NSView *)panel
{
	NSView *oldPanel = [self currentPanel];
	
	if (oldPanel != panel)
	{
		[self willChangeValueForKey: @"currentPanel"];

		//Synchronise the selected tab and record the panel choice in the user default
		NSInteger panelIndex = [[self panels] indexOfObject: panel];
		[[self panelSelector] setSelectedSegment: panelIndex];
		
		//Record the current panel in the user defaults
		[[NSUserDefaults standardUserDefaults] setInteger: panelIndex forKey: @"initialInspectorPanelIndex"];
		
		//Now add the new panel and resize the window to accomodate it

		NSWindow *theWindow	= [self window];
		NSView *container	= [self panelContainer];

		NSRect newFrame, oldFrame = [theWindow frame];
		
		NSSize newSize	= [panel bounds].size;
		NSSize oldSize	= [container bounds].size;
		NSSize difference = NSMakeSize(
			newSize.width - oldSize.width,
			newSize.height - oldSize.height
		);
		
		//Generate a new window frame that can contain the new panel,
		//Ensuring that the top left corner stays put
		newFrame.origin = NSMakePoint(
			oldFrame.origin.x,
			oldFrame.origin.y - difference.height
		);
		newFrame.size	= NSMakeSize(
			oldFrame.size.width + difference.width,
			oldFrame.size.height + difference.height
		);
		
		//Add the new panel into the view
		[container addSubview: panel];
			
		//Animate the panel transition, if we're flipping from a previous panel to a new one
		if (oldPanel)
		{
			[oldPanel removeFromSuperview];
			[self startScalingToFrame: newFrame];
		}
		else
		{
			//Otherwise just resize the window instantly
			[theWindow setFrame: newFrame display: YES];
		}
		
		[self didChangeValueForKey: @"currentPanel"];
	}
}

- (void) startScalingToFrame: (NSRect)newFrame
{
	NSViewAnimation *animation;
	NSDictionary *resize, *fadeIn;

	resize = [NSDictionary dictionaryWithObjectsAndKeys:
		[self window], NSViewAnimationTargetKey,
		[NSValue valueWithRect: newFrame], NSViewAnimationEndFrameKey,
	nil];
	
	fadeIn = [NSDictionary dictionaryWithObjectsAndKeys:
		[self currentPanel], NSViewAnimationTargetKey,
		NSViewAnimationFadeInEffect, NSViewAnimationEffectKey,
	nil];

	//Note: animation is released in our delegate functions
	animation = [[NSViewAnimation alloc] initWithViewAnimations: [NSArray arrayWithObjects: resize, fadeIn, nil]];

	[animation setAnimationBlockingMode: NSAnimationNonblocking];
	[animation setDuration: 0.2];
	[animation setDelegate: self];

	[animation startAnimation];
}

- (void) animationDidEnd: (NSAnimation *)animation
{
	NSWindow *theWindow = [self window];
	//This fixes a weird bug whereby scrollers would drag the window with them after switching panels.
	//TODO: come up with a more direct solution.
	[theWindow setMovableByWindowBackground: NO];
	[theWindow setMovableByWindowBackground: YES];
	
	//Force the window to redraw after the animation has completed
	//to cure an OS X 10.5 text draw bug
	[theWindow display];
	
	[animation release];
}

- (void) animationDidStop: (NSAnimation *)animation
{
	return [self animationDidEnd: animation];
}

//UI Actions
//----------

- (IBAction) showGameInspectorPanel:	(id)sender	{ [self setCurrentPanel: [self gamePanel]]; }
- (IBAction) showCPUInspectorPanel:		(id)sender	{ [self setCurrentPanel: [self cpuPanel]]; }
- (IBAction) showDriveInspectorPanel:	(id)sender	{ [self setCurrentPanel: [self drivePanel]]; }
- (IBAction) selectInspectorPanel:		(NSSegmentedControl *)sender
{
	NSInteger selectorIndex = [sender selectedSegment];
	[self setCurrentPanel: [[self panels] objectAtIndex: selectorIndex]];
}

- (IBAction) revealSelectedDrivesInFinder: (id)sender
{
	NSArray *selection = [[self driveController] selectedObjects];
	for (BXDrive *drive in selection) [NSApp sendAction: @selector(revealInFinder:) to: nil from: drive];
}
- (IBAction) openSelectedDrivesInDOS: (id)sender
{
	//Only bother grabbing the last drive selected
	BXDrive *drive = [[[self driveController] selectedObjects] lastObject];
	if (drive) [NSApp sendAction: @selector(openInDOS:) to: nil from: drive];
}
- (IBAction) unmountSelectedDrives: (id)sender
{
	NSArray *selection = [[self driveController] selectedObjects];
	for (BXDrive *drive in selection) [NSApp sendAction: @selector(unmountDrive:) to: nil from: drive];
}

- (IBAction) showMountPanel: (id) sender
{
	//Pass mount panel action upstream - this works around the fiddly separation of responder chains
	//between the inspector panel and main DOS window.
	[NSApp sendAction: @selector(showMountPanel:) to: [BXSession mainSession] from: self];
}

- (BOOL) validateUserInterfaceItem: (id)theItem
{
	BOOL hasSelection = ([[[self driveController] selectedObjects] count] > 0);
	BXEmulator *theEmulator = [[BXSession mainSession] emulator];
	
	SEL action = [theItem action];
	if (action == @selector(showMountPanel:))				return [BXSession mainSession] != nil;
	if (action == @selector(revealSelectedDrivesInFinder:)) return hasSelection;
	if (action == @selector(unmountSelectedDrives:))		return hasSelection && [theEmulator isExecuting];
	if (action == @selector(openSelectedDrivesInDOS:))		return hasSelection && [theEmulator isExecuting] && ![theEmulator isRunningProcess];
	return YES;
}


//Handling drag-drop
//------------------

- (NSDragOperation)draggingEntered: (id <NSDraggingInfo>)sender
{
	//Only allow drag-drop to the drive panel
	if ([[self currentPanel] isNotEqualTo: [self drivePanel]]) return NSDragOperationNone;
	
	//Ignore drags that originated from the inspector's drive list
	id source = [sender draggingSource];
	if ([[source window] isEqualTo: [self window]]) return NSDragOperationNone;
	
	//Otherwise, ask the current session what it would like to do with the files
	NSPasteboard *pboard = [sender draggingPasteboard];
	if ([[pboard types] containsObject: NSFilenamesPboardType])
	{
		NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		BXSession *theSession = [BXSession mainSession];
		return [theSession responseToDroppedFiles: filePaths];
	}
	else return NSDragOperationNone;
}

- (BOOL)performDragOperation: (id <NSDraggingInfo>)sender
{
	BXSession *theSession = [BXSession mainSession];

	NSPasteboard *pboard = [sender draggingPasteboard];
	if ([[pboard types] containsObject: NSFilenamesPboardType])
	{
		NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		return [theSession handleDroppedFiles: filePaths withLaunching: NO];
	}		
	return NO;
}
@end
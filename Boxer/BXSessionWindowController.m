/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSessionWindowController.h"
#import "BXSessionWindowController+BXRenderController.h"
#import "BXSessionWindow.h"
#import "BXProgramPanelController.h"

#import "BXEmulator+BXRendering.h"
#import "BXCloseAlert.h"
#import "BXSession+BXDragDrop.h"


@implementation BXSessionWindowController
@synthesize programPanelController;

//Overridden to make the types explicit, so we don't have to keep casting the return values to avoid compilation warnings
- (BXSession *)document			{ return (BXSession *)[super document]; }
- (BXSessionWindow *)window		{ return (BXSessionWindow *)[super window]; }

- (BXEmulator *)emulator		{ return [[self document] emulator]; }
- (BXRenderView *)renderView	{ return [[self window] renderView]; }


//Initialisation and cleanup functions
//------------------------------------

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[self setProgramPanelController: nil], [programPanelController release];
	
	[super dealloc];
}

- (void) awakeFromNib
{
	NSNotificationCenter *center	= [NSNotificationCenter defaultCenter];
	BXSessionWindow *theWindow		= [self window];
	BXRenderView *renderView		= [theWindow renderView];
	
	
	//Create our new program panel controller and attach it to our window's program panel
	BXProgramPanelController *panelController = [[[BXProgramPanelController alloc] initWithNibName: @"ProgramPanel" bundle: nil] autorelease];
	[self setProgramPanelController: panelController];
	[panelController setView: [theWindow programPanel]];
	
	
	//These are handled by BoxerRenderController, our category for rendering-related delegate tasks
	[center addObserver:	self
			selector:		@selector(windowWillLiveResize:)
			name:			@"BXRenderViewWillLiveResizeNotification"
			object:			renderView];
	[center addObserver:	self
			selector:		@selector(windowDidLiveResize:)
			name:			@"BXRenderViewDidLiveResizeNotification"
			object:			renderView];
	[center addObserver:	self
			selector:		@selector(menuDidOpen:)
			name:			NSMenuDidBeginTrackingNotification
			object:			nil];
	[center addObserver:	self
			selector:		@selector(menuDidClose:)
			name:			NSMenuDidEndTrackingNotification
			object:			nil];
	
	//While we're here, register for drag-drop file operations (used for mounting folders and such)
	[theWindow registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil]];
	
	
	//Set up the window UI components appropriately
	
	//Show/hide the statusbar based on user's preference
	[self setStatusBarShown: [[NSUserDefaults standardUserDefaults] boolForKey: @"statusBarShown"]];
	
	//Hide the program panel by default - our parent session decides when it's appropriate to display this
	[self setProgramPanelShown: NO];
}

- (void) setDocument: (BXSession *)theSession
{
	[[self programPanelController] setRepresentedObject: nil];
	
	[super setDocument: theSession];
	
	if (theSession)
	{
		id theWindow = [self window];

		//Now that we can retrieve the game's identifier from the session, use the autosaved window size for that game
		if ([theSession isGamePackage])
		{
			if ([theWindow setFrameAutosaveName: [theSession uniqueIdentifier]]) [theWindow center];
			//I hate to have to force the window to be centered but it compensates for Cocoa screwing up the position when it resizes a window from its saved frame: Cocoa pegs the window to the bottom-left origin when resizing this way, rather than the top-left as it should.
			//This comes up with non-16:10 games, since they get resized to match the 16:10 DOS ratio when they load. They would otherwise make the window travel down the screen each time they start up.
		}
		else
		{
			[theWindow setFrameAutosaveName: @"DOSWindow"];
		}
		
		//...and add it to our panel controller, so that it can keep up with the times too
		[[self programPanelController] setRepresentedObject: theSession];
	}
}


//Toggling window UI components
//-----------------------------


- (BOOL) statusBarShown		{ return ![[[self window] statusBar] isHidden]; }
- (BOOL) programPanelShown	{ return ![[[self window] programPanel] isHidden]; }

- (void) setStatusBarShown: (BOOL)show
{
	if (show != [self statusBarShown])
	{
		BXSessionWindow *theWindow	= [self window];
		BXRenderView *renderView	= [theWindow renderView];
		NSView *programPanel		= [theWindow programPanel];
		
		//temporarily override the other views' resizing behaviour so that they don't slide up as we do this
		NSUInteger oldRenderMask		= [renderView autoresizingMask];
		NSUInteger oldProgramPanelMask	= [programPanel autoresizingMask];
		[renderView		setAutoresizingMask: NSViewMinYMargin];
		[programPanel	setAutoresizingMask: NSViewMinYMargin];
		
		//toggle the resize indicator on/off also (it doesn't play nice with the program panel)
		if (!show)	[theWindow setShowsResizeIndicator: NO];
		[theWindow slideView: [theWindow statusBar] shown: show];
		if (show)	[theWindow setShowsResizeIndicator: YES];
		
		[renderView		setAutoresizingMask: oldRenderMask];
		[programPanel	setAutoresizingMask: oldProgramPanelMask];
		
		//record the current statusbar state in the user defaults
		[[NSUserDefaults standardUserDefaults] setBool: show forKey: @"statusBarShown"];
	}
}

- (void) setProgramPanelShown: (BOOL)show
{
	if (show != [self programPanelShown])
	{
		BXSessionWindow *theWindow	= [self window];
		BXRenderView *renderView 	= [theWindow renderView];
		NSView *programPanel		= [theWindow programPanel];
		
		//temporarily override the other views' resizing behaviour so that they don't slide up as we do this
		NSUInteger oldRenderMask = [renderView autoresizingMask];
		[renderView setAutoresizingMask: NSViewMinYMargin];
		
		[theWindow slideView: programPanel shown: show];
		
		[renderView setAutoresizingMask: oldRenderMask];
	}
}


//Responding to interface actions
//-------------------------------

- (IBAction) toggleStatusBarShown:		(id)sender	{ [self setStatusBarShown:		![self statusBarShown]]; }
- (IBAction) toggleProgramPanelShown:	(id)sender	{ [self setProgramPanelShown:	![self programPanelShown]]; }

- (IBAction) exitFullScreen: (id)sender
{
	[self setFullScreenWithZoom: NO];
}

- (IBAction) toggleFullScreen: (id)sender
{
	//Make sure we're the key window first before any shenanigans
	[[self window] makeKeyAndOrderFront: self];
	
	BXEmulator *emulator	= [self emulator];
	BOOL isFullScreen		= [emulator isFullScreen];
	[emulator setFullScreen: !isFullScreen];
}

- (IBAction) toggleFullScreenWithZoom: (id)sender
{
	BOOL enterFullScreen;
	BXEmulator *emulator = [self emulator];
	
	if ([sender isKindOfClass: [NSNumber class]])	enterFullScreen = [sender boolValue];
	else											enterFullScreen = ![emulator isFullScreen];

	[self setFullScreenWithZoom: enterFullScreen];
}

//Toggle the emulator's active rendering filter. This will resize the window to fit, if the
//filter demands a minimum size smaller than the current window size.
- (IBAction) toggleFilterType: (id)sender
{
	NSInteger filterType = [sender tag];
	[[NSUserDefaults standardUserDefaults] setInteger: filterType forKey: @"filterType"];
}

- (BOOL) validateMenuItem: (NSMenuItem *)theItem
{
	BXEmulator *emulator = [self emulator];
	
	SEL theAction = [theItem action];
	BOOL hideItem;
	NSString *title;
	
	if (theAction == @selector(toggleFilterType:))
	{
		NSInteger itemState;
		BXFilterType filterType	= [theItem tag];
		
		//Update the option state to reflect the current filter selection
		//If the filter is selected but not active at the current window size, we indicate this with a mixed state
		if		(filterType != [emulator filterType])	itemState = NSOffState;
		else if	([emulator filterIsActive])				itemState = NSOnState;
		else											itemState = NSMixedState;
		
		[theItem setState: itemState];
		
		return ([emulator isExecuting]);
	}
	
	else if (theAction == @selector(toggleProgramPanelShown:))
	{
		if (![self programPanelShown])
			title = NSLocalizedString(@"Show Programs Panel", @"View menu option for showing the program panel.");
		else
			title = NSLocalizedString(@"Hide Programs Panel", @"View menu option for hiding the program panel.");
		
		[theItem setTitle: title];
	
		return [[self document] isGamePackage];
	}
	
	else if (theAction == @selector(toggleStatusBarShown:))
	{
		if (![self statusBarShown])
			title = NSLocalizedString(@"Show Status Bar", @"View menu option for showing the status bar.");
		else
			title = NSLocalizedString(@"Hide Status Bar", @"View menu option for hiding the status bar.");
		
		[theItem setTitle: title];
	
		return YES;
	}
	
    return YES;
}


//Handling drag-drop
//------------------

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = [sender draggingPasteboard];	
	if ([[pboard types] containsObject: NSFilenamesPboardType])
	{
		NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		return [[self document] responseToDroppedFiles: filePaths];
	}
	else return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = [sender draggingPasteboard];
    NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
 
    if ([[pboard types] containsObject: NSFilenamesPboardType])
	{
        NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		return [[self document] handleDroppedFiles: filePaths withLaunching: YES];
	}
	/*
	else if ([[pboard types] containsObject: NSStringPboardType])
	{
		NSString *droppedString = [pboard stringForType: NSStringPboardType];
		return [[self document] handlePastedString: droppedString];
    }
	*/
    return NO;
}

//Handling dialog sheets
//----------------------

- (BOOL) windowShouldClose: (id)theWindow
{
	if (![[NSUserDefaults standardUserDefaults] boolForKey: @"suppressCloseAlert"]
		&& [[[self document] emulator] isRunningProcess])
	{
		BXCloseAlert *closeAlert = [BXCloseAlert closeAlertWhileSessionIsActive: [self document]];
		[closeAlert beginSheetModalForWindow: [self window]];
		return NO;
	}
	else return YES;
}
@end
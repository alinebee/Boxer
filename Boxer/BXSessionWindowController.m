/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSessionWindowController.h"
#import "BXSessionWindowController+BXRenderController.h"
#import "BXSessionWindow.h"
#import "BXAppController.h"
#import "BXProgramPanelController.h"
#import "BXInputController.h"

#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulator.h"
#import "BXInputHandler.h"
#import "BXVideoHandler.h"
#import "BXInputView.h"

#import "BXCloseAlert.h"
#import "BXSession+BXDragDrop.h"


@implementation BXSessionWindowController

#pragma mark -
#pragma mark Accessors

@synthesize renderingView, inputView, viewContainer, statusBar, programPanel;
@synthesize programPanelController, inputController, statusBarController;
@synthesize resizingProgrammatically;
@synthesize emulator;


//Overridden to make the types explicit, so we don't have to keep casting the return values to avoid compilation warnings
- (BXSession *) document		{ return (BXSession *)[super document]; }
- (BXSessionWindow *) window	{ return (BXSessionWindow *)[super window]; }


#pragma mark -
#pragma mark Initialisation and cleanup

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[self setEmulator: nil],				[emulator release];
	
	[self setProgramPanelController: nil],	[programPanelController release];
	[self setInputController: nil],			[inputController release];
	[self setStatusBarController: nil],		[statusBarController release];

	[self setViewContainer: nil],			[viewContainer release];
	[self setInputView: nil],				[inputView release];
	[self setRenderingView: nil],			[renderingView release];
	
	[self setProgramPanel: nil],			[programPanel release];
	[self setStatusBar: nil],				[statusBar release];
	
	[super dealloc];
}

- (void) awakeFromNib
{
	NSNotificationCenter *center	= [NSNotificationCenter defaultCenter];
	BXSessionWindow *theWindow		= [self window];
	
	//Set up observing for UI events
	//------------------------------
	
	//These are handled by BoxerRenderController, our category for rendering-related delegate tasks
	[center addObserver:	self
			selector:		@selector(windowWillLiveResize:)
			name:			BXViewWillLiveResizeNotification
			object:			inputView];
	[center addObserver:	self
			selector:		@selector(windowDidLiveResize:)
			name:			BXViewDidLiveResizeNotification
			object:			inputView];
	[center addObserver:	self
			selector:		@selector(menuDidOpen:)
			name:			NSMenuDidBeginTrackingNotification
			object:			nil];
	[center addObserver:	self
			selector:		@selector(menuDidClose:)
			name:			NSMenuDidEndTrackingNotification
			object:			nil];
	
	[center addObserver:	self
			   selector:	@selector(applicationWillHide:)
				   name:	NSApplicationWillHideNotification
				 object:	NSApp];
	
	[center addObserver:	self
			   selector:	@selector(applicationWillHide:)
				   name:	NSApplicationWillResignActiveNotification
				 object:	NSApp];
	
	//While we're here, register for drag-drop file operations (used for mounting folders and such)
	[theWindow registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil]];
	
	
	//Set up the window UI components appropriately
	//---------------------------------------------
	
	//Show/hide the statusbar based on user's preference
	[self setStatusBarShown: [[NSUserDefaults standardUserDefaults] boolForKey: @"statusBarShown"]];
	
	//Hide the program panel by default - our parent session decides when it's appropriate to display this
	[self setProgramPanelShown: NO];
	
	//Apply a border to the window matching the size of the statusbar
	CGFloat borderThickness = [statusBar frame].size.height;
	[theWindow setContentBorderThickness: borderThickness forEdge: NSMinYEdge];
	
	//Track mouse movement when this is the main window
	[theWindow setAcceptsMouseMovedEvents: YES];
	
	//Set window rendering behaviour
	//------------------------------
	
	//Fix the window in the aspect ratio it will start up in
	initialContentSize = [self windowedRenderingViewSize];
	[theWindow setContentAspectRatio: initialContentSize];
	
	//We don't support content-preservation yet, so disable the check to be slightly more efficient
	[theWindow setPreservesContentDuringLiveResize: NO];
}

- (void) setDocument: (BXSession *)theSession
{	
	if ([self document])
	{
		[[self document] removeObserver: self forKeyPath: @"activeProgramPath"];
		[self unbind: @"emulator"];
		[programPanelController setRepresentedObject: nil];		
	}
	
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
		
		[theSession addObserver: self forKeyPath: @"activeProgramPath" options: 0 context: nil];
		[self bind: @"emulator" toObject: theSession withKeyPath: @"emulator" options: nil];
		[programPanelController setRepresentedObject: theSession];
	}
}


- (void) setEmulator: (BXEmulator *)newEmulator 
{
	[self willChangeValueForKey: @"emulator"];
	
	if (newEmulator != emulator)
	{
		if (emulator)
		{
			[[emulator videoHandler] unbind: @"aspectCorrected"];
			[[emulator videoHandler] unbind: @"filterType"];
			[inputController setRepresentedObject: nil];	
		}
		
		[emulator release];
		emulator = [newEmulator retain];
		
		if (newEmulator)
		{
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			
			[[newEmulator videoHandler] bind: @"aspectCorrected" toObject: defaults withKeyPath: @"aspectCorrected" options: nil];
			[[newEmulator videoHandler] bind: @"filterType" toObject: defaults withKeyPath: @"filterType" options: nil];
			
			[inputController setRepresentedObject: [newEmulator inputHandler]];
		}
	}
	
	[self didChangeValueForKey: @"emulator"];
}


#pragma mark -
#pragma mark Syncing window title

- (void) synchronizeWindowTitleWithDocumentName
{
	if ([[self document] isGamePackage])
	{
		//If the session is a gamebox, always use the gamebox for the window title (like a regular NSDocument.)
		return [super synchronizeWindowTitleWithDocumentName];
	}
	else
	{
		//If the session isn't a gamebox, then use the currently-active program as the window title.
		NSString *representedPath = [[self document] activeProgramPath];
		
		//If no program is running, then use the local filesystem equivalent of the current directory in DOS.
		if (!representedPath) representedPath = [[[self document] emulator] pathOfCurrentWorkingDirectory];
		
		if (representedPath) [[self window] setTitleWithRepresentedFilename: representedPath];
		else
		{
			//If that wasn't available either (e.g. we're on drive Z) then just display a generic title
			[[self window] setRepresentedFilename: @""];
			[[self window] setTitle: NSLocalizedString(
				@"MS-DOS Prompt", @"The standard window title when the session is at the DOS prompt.")];
		}
	}
}

- (void) observeValueForKeyPath: (NSString *)keyPath
						ofObject: (id)object
						  change: (NSDictionary *)change
						 context: (void *)context
{
	//Whenever the active program path changes, synchronise the window title and the unsaved changes indicator
	if ([keyPath isEqualToString: @"document.activeProgramPath"])
	{
		[self synchronizeWindowTitleWithDocumentName];
		
		//Flag the window as unsaved if pressing the close button would trigger a confirmation panel.
		//This matches the behaviour of the OS X Terminal.
		//Disabled as it also fades out the document icon, which is stretching the dubious
		//justification for using this feature to breaking point.
		
		//[self setDocumentEdited: [self shouldConfirmClose]];
	}
}


#pragma mark -
#pragma mark Toggling UI components

- (BOOL) statusBarShown		{ return ![statusBar isHidden]; }
- (BOOL) programPanelShown	{ return ![programPanel isHidden]; }

- (void) setStatusBarShown: (BOOL)show
{
	if (show != [self statusBarShown])
	{
		BXSessionWindow *theWindow	= [self window];
		
		//temporarily override the other views' resizing behaviour so that they don't slide up as we do this
		NSUInteger oldContainerMask		= [viewContainer autoresizingMask];
		NSUInteger oldProgramPanelMask	= [programPanel autoresizingMask];
		[viewContainer	setAutoresizingMask: NSViewMinYMargin];
		[programPanel	setAutoresizingMask: NSViewMinYMargin];
		
		//toggle the resize indicator on/off also (it doesn't play nice with the program panel)
		if (!show)	[theWindow setShowsResizeIndicator: NO];
		[self _slideView: statusBar shown: show];
		if (show)	[theWindow setShowsResizeIndicator: YES];
		
		[viewContainer	setAutoresizingMask: oldContainerMask];
		[programPanel	setAutoresizingMask: oldProgramPanelMask];
		
		//record the current statusbar state in the user defaults
		[[NSUserDefaults standardUserDefaults] setBool: show forKey: @"statusBarShown"];
	}
}

- (void) setProgramPanelShown: (BOOL)show
{
	//Don't open the program panel if we're not running a gamebox
	if (show && ![[self document] isGamePackage]) return;
	
	if (show != [self programPanelShown])
	{
		//temporarily override the other views' resizing behaviour so that they don't slide up as we do this
		NSUInteger oldMask = [viewContainer autoresizingMask];
		[viewContainer setAutoresizingMask: NSViewMinYMargin];
		
		[self _slideView: programPanel shown: show];
		
		[viewContainer setAutoresizingMask: oldMask];
	}
}


#pragma mark -
#pragma mark UI actions

- (IBAction) toggleStatusBarShown:		(id)sender	{ [self setStatusBarShown:		![self statusBarShown]]; }
- (IBAction) toggleProgramPanelShown:	(id)sender	{ [self setProgramPanelShown:	![self programPanelShown]]; }

- (IBAction) exitFullScreen: (id)sender
{
	[self setFullScreenWithZoom: NO];
}

- (IBAction) toggleFullScreen: (id)sender
{
	BOOL enterFullScreen;
	
	if ([sender respondsToSelector: @selector(boolValue)])	enterFullScreen = [sender boolValue];
	else													enterFullScreen = ![self isFullScreen];
	
	[self setFullScreen: enterFullScreen];
}

- (IBAction) toggleFullScreenWithZoom: (id)sender
{
	BOOL enterFullScreen;
	
	if ([sender respondsToSelector: @selector(boolValue)])	enterFullScreen = [sender boolValue];
	else													enterFullScreen = ![self isFullScreen];
																		
	[self setFullScreenWithZoom: enterFullScreen];
}

- (IBAction) toggleFilterType: (id)sender
{
	NSInteger filterType = [sender tag];
	[[NSUserDefaults standardUserDefaults] setInteger: filterType forKey: @"filterType"];
}

- (BOOL) validateMenuItem: (NSMenuItem *)theItem
{	
	SEL theAction = [theItem action];
	NSString *title;

	if (theAction == @selector(toggleFilterType:))
	{
		NSInteger itemState;
		BXFilterType filterType	= [theItem tag];
		BXVideoHandler *videoHandler = [[self emulator] videoHandler];
		
		//Update the option state to reflect the current filter selection
		//If the filter is selected but not active at the current window size, we indicate this with a mixed state
		
		if		(filterType != [videoHandler filterType])	itemState = NSOffState;
		else if	([videoHandler filterIsActive])				itemState = NSOnState;
		else 												itemState = NSMixedState;
		
		[theItem setState: itemState];
		
		return ([[self emulator] isExecuting]);
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


#pragma mark -
#pragma mark Drag-drop handlers

- (NSDragOperation)draggingEntered: (id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = [sender draggingPasteboard];	
	if ([[pboard types] containsObject: NSFilenamesPboardType])
	{
		NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		return [[self document] responseToDroppedFiles: filePaths];
	}
	else if ([[pboard types] containsObject: NSStringPboardType])
	{
		NSString *droppedString = [pboard stringForType: NSStringPboardType];
		return [[self document] responseToDroppedString: droppedString];
    }
	else return NSDragOperationNone;
}

- (BOOL)performDragOperation: (id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = [sender draggingPasteboard];
    NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
 
    if ([[pboard types] containsObject: NSFilenamesPboardType])
	{
        NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		return [[self document] handleDroppedFiles: filePaths withLaunching: YES];
	}
	
	else if ([[pboard types] containsObject: NSStringPboardType])
	{
		NSString *droppedString = [pboard stringForType: NSStringPboardType];
		return [[self document] handleDroppedString: droppedString];
    }
	return NO;
}

#pragma mark -
#pragma mark Handlers for window and application state changes

- (BOOL) shouldConfirmClose
{
	return (![[NSUserDefaults standardUserDefaults] boolForKey: @"suppressCloseAlert"] && [[self emulator] isRunningProcess]);
}

- (BOOL) windowShouldClose: (id)theWindow
{
	if ([self shouldConfirmClose])
	{
		BXCloseAlert *closeAlert = [BXCloseAlert closeAlertWhileSessionIsActive: [self document]];
		[closeAlert beginSheetModalForWindow: [self window]];
		return NO;
	}
	else return YES;
}

//Prompt to close the window, after exiting a game or program.
- (IBAction) windowShouldCloseAfterProgramCompletion: (id)sender
{
	BXCloseAlert *closeAlert = [BXCloseAlert closeAlertAfterSessionExited: [self document]];
	[closeAlert beginSheetModalForWindow: [self window]];
}

- (void) windowWillClose: (NSNotification *)notification
{
	[self exitFullScreen: self];
}

- (void) windowWillMiniaturize: (NSNotification *)notification
{
	[self exitFullScreen: self];
}

//Drop out of fullscreen mode before showing any sheets
- (void) windowWillBeginSheet: (NSNotification *) notification
{
	[self setFullScreen: NO];
}


//Refresh the DOS renderer after the window resizes, to take the new size into account
- (void) windowDidResize: (NSNotification *) notification
{
	if (![self isFullScreen] && ![self isResizing])
	{
		//Tell the renderer to refresh its filters 
		[[[self emulator] videoHandler] reset];
		
		//Also, update the damn cursors which will have been reset by the window's resizing
		[inputController cursorUpdate: nil];
	}
}


//Warn the emulator to prepare for emulation cutout when the resize starts
- (void) windowWillLiveResize: (NSNotification *) notification
{
	[[self emulator] willPause];
}

//Catch the end of a live resize event and pass it to our normal resize handler
//While we're at it, let the emulator know it can unpause now
- (void) windowDidLiveResize: (NSNotification *) notification
{
	//We do this with a delay to give the resize operation time to 'stop being live'.
	[self performSelector: @selector(windowDidResize:) withObject: notification afterDelay: 0.0];
	[[self emulator] didResume];
}

//Tell the view controller to cancel key events and unlock the mouse
//We ignore this notification in fullscreen, because we receive it when
//the view is swapped to AppKit's private fullscreen window
- (void) windowDidResignKey:	(NSNotification *) notification
{
	if (![self isFullScreen]) [inputController didResignKey];
}
- (void) windowDidResignMain:	(NSNotification *) notification
{
	if (![self isFullScreen]) [inputController didResignKey];
}

//Drop out of fullscreen and warn the emulator to prepare for emulation cutout when a menu opens
- (void) menuDidOpen:	(NSNotification *) notification
{
	[self setFullScreen: NO];
	[[self emulator] willPause];
}

//Let the emulator know the coast is clear
- (void) menuDidClose:	(NSNotification *) notification
{
	[[self emulator] didResume];
}

- (void) applicationWillHide: (NSNotification *) notification
{
	[self setFullScreen: NO];
}
- (void) applicationWillResignActive: (NSNotification *) notification
{
	[self setFullScreen: NO];
}
@end
/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDOSWindowController.h"
#import "BXDOSWindowController+BXRenderController.h"
#import "BXDOSWindow.h"
#import "BXAppController.h"
#import "BXProgramPanelController.h"
#import "BXInputController.h"
#import "BXPackage.h"

#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulator.h"
#import "BXInputHandler.h"
#import "BXVideoHandler.h"
#import "BXInputView.h"

#import "BXSession+BXDragDrop.h"
#import "BXImport.h"

//Private methods
@interface BXDOSWindowController ()

//Performs the slide animation used to toggle the status bar and program panel on or off
- (void) _slideView: (NSView *)view shown: (BOOL)show;

@end

@implementation BXDOSWindowController

#pragma mark -
#pragma mark Accessors

@synthesize renderingView, inputView, viewContainer, statusBar, programPanel;
@synthesize programPanelController, inputController, statusBarController;
@synthesize resizingProgrammatically;


//Overridden to make the types explicit, so we don't have to keep casting the return values to avoid compilation warnings
- (BXSession *) document	{ return (BXSession *)[super document]; }
- (BXDOSWindow *) window	{ return (BXDOSWindow *)[super window]; }


- (void) setDocument: (BXSession *)document
{
	[super setDocument: document];

	//Assign references to our document for our view controllers, or clear those references when the document is cleared.
	[programPanelController setRepresentedObject: document];
	[inputController setRepresentedObject: [[document emulator] inputHandler]];
}

#pragma mark -
#pragma mark Initialisation and cleanup

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
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

- (void) windowDidLoad
{
	NSNotificationCenter *center	= [NSNotificationCenter defaultCenter];
	BXDOSWindow *theWindow			= [self window];
	
	//Set up observing for UI events
	//------------------------------
	
	//These are handled by BoxerRenderController, our category for rendering-related delegate tasks
	[center addObserver: self
			   selector: @selector(windowWillLiveResize:)
				   name: BXViewWillLiveResizeNotification
				 object: inputView];
	
	[center addObserver: self
			   selector: @selector(windowDidLiveResize:)
				   name: BXViewDidLiveResizeNotification
				 object: inputView];
	
	[center addObserver: self
			   selector: @selector(menuDidOpen:)
				   name: NSMenuDidBeginTrackingNotification
				 object: nil];
	[center addObserver: self
			   selector: @selector(menuDidClose:)
				   name: NSMenuDidEndTrackingNotification
				 object: nil];
	
	[center addObserver: self
			   selector: @selector(applicationWillHide:)
				   name: NSApplicationWillHideNotification
				 object: NSApp];
	
	[center addObserver: self
			   selector: @selector(applicationWillHide:)
				   name: NSApplicationWillResignActiveNotification
				 object: NSApp];
	
	//While we're here, register for drag-drop file operations (used for mounting folders and such)
	[theWindow registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil]];
	
	
	//Set up the window UI components appropriately
	//---------------------------------------------
	
	//Show/hide the statusbar based on user's preference
	[self setStatusBarShown: [[NSUserDefaults standardUserDefaults] boolForKey: @"statusBarShown"]];
	
	//Hide the program panel by default - our parent session decides when it's appropriate to display this
	[self setProgramPanelShown: NO];
	
	//Apply a border to the window matching the size of the statusbar
	CGFloat borderThickness = [statusBar frame].size.height + 1.0f;
	[theWindow setContentBorderThickness: borderThickness forEdge: NSMinYEdge];
	
	//Track mouse movement when this is the main window
	[theWindow setAcceptsMouseMovedEvents: YES];
	
	//We don't support content-preservation yet, so disable the check to be slightly more efficient
	[theWindow setPreservesContentDuringLiveResize: NO];	
	
	
	//Now that we can retrieve the game's identifier from the session,
	//use the autosaved window size for that game
	if ([[self document] isGamePackage])
	{
		NSString *gameIdentifier = [[[self document] gamePackage] gameIdentifier];
		if (gameIdentifier) [self setFrameAutosaveName: gameIdentifier];
	}
	else
	{
		[self setFrameAutosaveName: @"DOSWindow"];
	}
	
	//Reassign the document to ensure we've set up our view controllers with references the document/emulator
	//This is necessary because the order of windowDidLoad/setDocument: differs between releases and some
	//of our members may have been nil when setDocument: was first called
	[self setDocument: [self document]];
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


#pragma mark -
#pragma mark Toggling UI components

- (BOOL) statusBarShown		{ return ![statusBar isHidden]; }
- (BOOL) programPanelShown	{ return ![programPanel isHidden]; }

- (void) setStatusBarShown: (BOOL)show
{
	if (show != [self statusBarShown])
	{
		BXDOSWindow *theWindow	= [self window];
		
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

- (IBAction) showProgramPanel: (id)sender
{
	[self setProgramPanelShown: YES];
}

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
		BXVideoHandler *videoHandler = [[[self document] emulator] videoHandler];
		
		//Update the option state to reflect the current filter selection
		//If the filter is selected but not active at the current window size, we indicate this with a mixed state
		
		if		(filterType != [videoHandler filterType])	itemState = NSOffState;
		else if	([videoHandler filterIsActive])				itemState = NSOnState;
		else 												itemState = NSMixedState;
		
		[theItem setState: itemState];
		
		return ([[self document] isEmulating]);
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
		[[[[self document] emulator] videoHandler] reset];
		
		//Also, update the damn cursors which will have been reset by the window's resizing
		[inputController cursorUpdate: nil];
	}
}


//Warn the emulator to prepare for emulation cutout when the resize starts
- (void) windowWillLiveResize: (NSNotification *) notification
{
	[[[self document] emulator] willPause];
}

//Catch the end of a live resize event and pass it to our normal resize handler
//While we're at it, let the emulator know it can unpause now
- (void) windowDidLiveResize: (NSNotification *) notification
{
	//We do this with a delay to give the resize operation time to 'stop being live'.
	[self performSelector: @selector(windowDidResize:) withObject: notification afterDelay: 0.0];
	[[[self document] emulator] didResume];
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
	[[[self document] emulator] willPause];
}

//Let the emulator know the coast is clear
- (void) menuDidClose:	(NSNotification *) notification
{
	[[[self document] emulator] didResume];
}

- (void) applicationWillHide: (NSNotification *) notification
{
	[self setFullScreen: NO];
}
- (void) applicationWillResignActive: (NSNotification *) notification
{
	[self setFullScreen: NO];
}


#pragma mark -
#pragma mark Private methods

//Performs the slide animation used to toggle the status bar and program panel on or off
- (void) _slideView: (NSView *)view shown: (BOOL)show
{
	NSRect newFrame	= [[self window] frame];
	
	CGFloat height	= [view frame].size.height;
	if (!show) height = -height;
	
	newFrame.size.height	+= height;
	newFrame.origin.y		-= height;
	
	if (show) [view setHidden: NO];	//Unhide before sliding out
	if ([self isFullScreen])
	{
		[[self window] setFrame: newFrame display: NO];
	}
	else
	{
		[[self window] setFrame: newFrame display: YES animate: YES];
	}
	
	if (!show) [view setHidden: YES]; //Hide after sliding in 
}

@end

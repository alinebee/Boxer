/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSessionWindowController.h"
#import "BXSessionWindow.h"
#import "BXProgramPanelController.h"

#import "BXEmulator.h"
#import "BXCloseAlert.h"
#import "BXSession+BXDragDrop.h"


@implementation BXSessionWindowController
@synthesize programPanelController;

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
	BXSessionWindow *theWindow		= (BXSessionWindow *)[self window];
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
}

- (void) setDocument: (BXSession *)theSession
{
	[[self document] removeObserver: self forKeyPath: @"processDisplayName"];
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
		
		//While we're here, also observe the process name of the session so that we can change the window title appropriately
		[theSession addObserver: self forKeyPath: @"processDisplayName" options: 0 context: nil];
		
		//...and add it to our panel controller, so that it can keep up with the times too
		[[self programPanelController] setRepresentedObject: theSession];
	}
}

//Sync our window title when we notice that the document's name has changed
- (void)observeValueForKeyPath: (NSString *)keyPath
					  ofObject: (id)object
						change: (NSDictionary *)change
					   context: (void *)context
{
	if ([keyPath isEqualToString: @"processDisplayName"]) [self synchronizeWindowTitleWithDocumentName];
}


//Handling drag-drop
//------------------

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = [sender draggingPasteboard];	
	if ([[pboard types] containsObject: NSFilenamesPboardType])
	{
		NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		BXSession *theSession = (BXSession *)[self document];
		return [theSession responseToDroppedFiles: filePaths];
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
		BXSession *theSession = (BXSession *)[self document];
		
		return [theSession handleDroppedFiles: filePaths withLaunching: YES];
	}
	/*
	else if ([[pboard types] containsObject: NSStringPboardType])
	{
		BXSession *theSession = (BXSession *)[self document];
		NSString *droppedString = [pboard stringForType: NSStringPboardType];
		return [theSession handlePastedString: droppedString];
    }
	*/
    return NO;
}


//Handling window title
//---------------------

//I give up, why is this even here? Why isn't BXSession deciding which to use?
- (void) synchronizeWindowTitleWithDocumentName
{	
	BXSession *theSession = (BXSession *)[self document];
	if (theSession)
	{
		//For game packages, we use the standard NSDocument window title
		if ([theSession isGamePackage]) [super synchronizeWindowTitleWithDocumentName];
		
		//For regular DOS sessions, we use the current process name instead
		else [[self window] setTitle: [theSession processDisplayName]];
	}
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
/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXSessionWindowController manages a session window and its dependent views and view controllers.
//It is responsible for handling drag-drop and window close events, synchronising the window title
//with the document, and initialising the window to a suitable state for the current session.

//BXSessionWindowController has the following categories:
//BXRenderController manages rendering-specific tasks such as window resizing and fullscreening;
//BXInputController manages event handling, window activation and other input-specific tasks.


#import <Cocoa/Cocoa.h>


@class BXEmulator;
@class BXDOSView;
@class BXSession;
@class BXSessionWindow;
@class BXProgramPanelController;
@class BXDOSViewController;
@class BXEmulator;

@interface BXSessionWindowController : NSWindowController
{
	IBOutlet BXDOSView *DOSView;
	IBOutlet NSView *DOSViewContainer;
	IBOutlet NSView *statusBar;
	IBOutlet NSView *programPanel;

	IBOutlet BXProgramPanelController *programPanelController;
	IBOutlet BXDOSViewController *DOSViewController;
	
	BXEmulator *emulator;
	
	NSSize currentScaledSize;	//Used internally by the BXRenderController category for resizing decisions.
	BOOL resizingProgrammatically;
}
//Our view controller for the program picker panel.
@property (retain) BXProgramPanelController *programPanelController;
@property (retain) BXDOSViewController *DOSViewController;

@property (retain) BXDOSView *DOSView;			//The view that displays DOSBox's graphical output.
@property (retain) NSView *DOSViewContainer;	//A wrapper for the DOSView to aid window-sizing behaviour.
@property (retain) NSView *programPanel;		//The slide-out program picker panel.
@property (retain) NSView *statusBar;			//The status bar at the bottom of the window.

//Indicates that the current resize event is internal and not triggered by user interaction.
//Used to change our window constraining behaviour and response to resize events.
@property (assign) BOOL resizingProgrammatically;

//A reference to the emulator instance for this window.
@property (retain) BXEmulator *emulator;


//Recast NSWindowController's standard accessors so that we get our own classes
//(and don't have to keep recasting them ourselves)
- (BXSession *) document;
- (BXSessionWindow *) window;


//Drag-and-drop
//-------------

//The session window responds to dropped files and folders, mounting them as new DOS drives and/or opening
//them in DOS if appropriate. These methods call corresponding methods on BXSession+BXDragDrop.
- (NSDragOperation)draggingEntered:	(id < NSDraggingInfo >)sender;
- (BOOL)performDragOperation:		(id < NSDraggingInfo >)sender;


//Interface actions
//-----------------

//Toggle instantly in and out of fullscreen mode.
- (IBAction) toggleFullScreen: (id)sender;

//Zoom in and out of fullscreen mode with a smooth window sizing animation.
//Toggles setFullScreenWithZoom:
- (IBAction) toggleFullScreenWithZoom: (id)sender;

//Exit back to a window, if in fullscreen; otherwise do nothing.
//This is triggered by pressing ESC when at the DOS prompt.
- (IBAction) exitFullScreen: (id)sender;

//Toggle the status bar and program panel components on and off.
- (IBAction) toggleStatusBarShown:		(id)sender;
- (IBAction) toggleProgramPanelShown:	(id)sender;

//Toggle the emulator's active rendering filter.
- (IBAction) toggleFilterType: (id)sender;


//Toggling window UI components
//-----------------------------

//Get/set whether the statusbar should be shown.
- (BOOL) statusBarShown;
- (void) setStatusBarShown:		(BOOL)show;

//Get/set whether the program panel should be shown.
- (BOOL) programPanelShown;
- (void) setProgramPanelShown:	(BOOL)show;


//Handling window state changes
//-----------------------------

//Returns whether a confirmation sheet should be shown when windowShouldClose is called.
- (BOOL) shouldConfirmClose;

//Called when the user tries to close a window.
//If a program is running, this shows a confirmation sheet; otherwise, it allows the window to close.
- (BOOL) windowShouldClose: (id)theWindow;

//Shows a confirmation sheet asking to close the window, after exiting a game or program.
//Currently unused.
- (IBAction) windowShouldCloseAfterProgramCompletion: (id)sender;


//These listen for any time an NSMenu opens or closes, and warn the active emulator
//to pause or resume emulation. In practice this means muting it to avoid hanging
//music and sound effects while the menu is blocking the thread.
//TODO: BXEmulator itself should handle this at a lower level by watching out for
//whenever a new event loop gets created.
- (void) menuDidOpen:	(NSNotification *) notification;
- (void) menuDidClose:	(NSNotification *) notification;

- (void) applicationWillHide: (NSNotification *) notification;
- (void) applicationWillResignActive: (NSNotification *) notification;
@end


//Methods in this category are not intended to be called outside of BXSessionWindowController.
@interface BXSessionWindowController (BXSessionWindowControllerInternals)

//Performs the slide animation used to toggle the status bar and program panel on or off
- (void) _slideView: (NSView *)view shown: (BOOL)show;

//Resize the window frame to fit the requested render size.
- (void) _resizeWindowToDOSViewSize: (NSSize)newSize animate: (BOOL)performAnimation;

//Returns the view size that should be used for rendering the specified DOSBox output size.
- (NSSize) _DOSViewSizeForScaledOutputSize: (NSSize)scaledSize minSize: (NSSize)minViewSize;

@end
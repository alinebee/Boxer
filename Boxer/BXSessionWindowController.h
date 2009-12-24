/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXSessionWindowController manages a session window and its dependent views and view controllers.
//It is responsible for handling drag-drop and window close events, synchronising the window title
//with the document, and initialising the window to a suitable state for the current session.

//The base controller class currently has no overt custom functionality itself, instead overriding
//the standard behaviour of NSWindowController in various ways. Custom methods and actions
//are provided by the more exciting BXRenderController category instead.


#import <Cocoa/Cocoa.h>


@class BXEmulator;
@class BXRenderView;
@class BXSession;
@class BXSessionWindow;
@class BXProgramPanelController;

@interface BXSessionWindowController : NSWindowController
{
	NSSize currentRenderedSize;	//Used internally by the BXRenderController category for resizing decisions.	
	BXProgramPanelController *programPanelController;
}
//Our view controller for the program picker panel. This is created when awaking from the NIB file.
@property (retain) BXProgramPanelController *programPanelController;


- (BXSession *)document;
- (BXSessionWindow *)window;

- (BXEmulator *) emulator;		//Shortcut accessor for the current session's emulator
- (BXRenderView *) renderView;	//Shortcut accessor for the session window's render view.


//Handling drag-drop
//------------------

//The session window responds to dropped files and folders, mounting them as new DOS drives and/or opening
//them in DOS if appropriate. These methods call corresponding methods on BXSession+BXDragDrop.
- (NSDragOperation)draggingEntered:	(id < NSDraggingInfo >)sender;
- (BOOL)performDragOperation:		(id < NSDraggingInfo >)sender;


//Rendering-related interface actions
//-----------------------------------

//Toggle the emulator's active rendering filter. This will resize the window to fit, if the
//filter demands a minimum size smaller than the current window size.
- (IBAction) toggleFilterType: (NSMenuItem *)sender;

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


//Toggling window UI components
//-----------------------------

//Get/set whether the statusbar should be shown.
//TODO: move to BXWindowController.
- (BOOL) statusBarShown;
- (void) setStatusBarShown:		(BOOL)show;

//Get/set whether the program panel should be shown.
//TODO: move to BXWindowController.
- (BOOL) programPanelShown;
- (void) setProgramPanelShown:	(BOOL)show;


@end
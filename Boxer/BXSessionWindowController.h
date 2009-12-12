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

@class BXProgramPanelController;

@interface BXSessionWindowController : NSWindowController
{
	NSSize currentRenderedSize;	//Used internally by the BXRenderController category for resizing decisions.	
	BXProgramPanelController *programPanelController;
}
//Our view controller for the program picker panel. This is created when awaking from the NIB file.
@property (retain) BXProgramPanelController *programPanelController;


//Handling drag-drop
//------------------

//The session window responds to dropped files and folders, mounting them as new DOS drives and/or opening
//them in DOS if appropriate. These methods call corresponding methods on BXSession+BXDragDrop.
- (NSDragOperation)draggingEntered:	(id < NSDraggingInfo >)sender;
- (BOOL)performDragOperation:		(id < NSDraggingInfo >)sender;

@end
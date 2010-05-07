/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDOSViewController class description goes here.

#import <Cocoa/Cocoa.h>

@class BXSessionWindowController;
@class BXEmulator;

@interface BXDOSViewController : NSViewController
{	
	NSCursor *hiddenCursor;
	BOOL mouseActive;
	BOOL mouseLocked;
	NSPoint lastMousePosition;
	
	IBOutlet BXSessionWindowController *windowController;
}

//Whether the mouse is in use by the DOS program. Set programmatically to match the emulator.
@property (assign) BOOL mouseActive;
//Set/get whether the mouse is locked to the DOS view.
@property (assign) BOOL mouseLocked;
//The blank cursor we use when the mouse should be hidden when over the DOS view.
@property (retain) NSCursor *hiddenCursor;

@property (assign) BXSessionWindowController *windowController;


//Whether the mouse is currently within our view.
- (BOOL) mouseInView;

//Returns the emulator for the session we belong to.
- (BXEmulator *) emulator;

//Called by BXSessionWindowController whenever the keyboard focus leaves the window.
- (void) didResignKey;

//Lock/unlock the mouse.
- (IBAction) toggleMouseLocked: (id)sender;

//Warp the OS X cursor to the point on screen corresponding to (where we think) the DOS cursor is.
- (void) _syncOSXCursorAndDOSCursor;

@end
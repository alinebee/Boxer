/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXRenderController category separates off rendering-specific functionality from general
//window controller housework. The methods herein liaise between BXRenderView and BXEmulator, pass UI
//signals back to BXEmulator, and manage resizing to ensure that the view size and rendering size
//are consistent.

#import <Cocoa/Cocoa.h>
#import "BXSessionWindowController.h"

@class BXSessionWindow;
@class BXEmulator;
@class BXRenderView;

@interface BXSessionWindowController (BXRenderController)

//Managing the DOSBox/SDL draw context
//------------------------------------
- (BXEmulator *) emulator;		//Shortcut accessor for the current session's emulator
- (BXRenderView *) renderView;	//Shortcut accessor for the session window's render view. 

//Get/replace/delete the view inside renderView that SDL will use for output.
//These methods are called directly from inside our own hacked-up version of the SDL framework,
//which is so dirty I need to have a shower whenever I think about it.
- (NSView *) SDLView;
- (void) setSDLView: (NSView *)theView;
- (void) clearSDLView;


//Notification observers
//----------------------

//These listen for any time an NSMenu opens or closes, and warn the active emulator
//to pause or resume emulation. In practice this means muting it to avoid hanging
//music and sound effects while the menu is blocking the thread.
//TODO: BXEmulator itself should handle this at a lower level by watching out for
//whenever a new event loop gets created.
- (void) menuDidOpen:	(NSNotification *) notification;
- (void) menuDidClose:	(NSNotification *) notification;


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


//Window sizing methods
//---------------------

//Returns the view size that should be used for rendering the specified DOSBox output size.
//This information is used by BXEmulator for telling SDL how big a surface to create.
- (NSSize) viewSizeForRenderedSize: (NSSize)renderedSize minSize: (NSSize)minViewSize;

//Resize the window to accomodate the specified view size. Returns YES if a resize was possible,
//or NO if there is not enough room onscreen to do so.
//Currently this is called when choosing a new filter to resize the window if it is smaller than
//the filter's minimum size.
- (BOOL) resizeToAccommodateViewSize: (NSSize) minViewSize;

//Zoom in and out of fullscreen mode with a smooth window sizing animation.
- (BOOL) setFullScreenWithZoom: (BOOL) fullScreen;

@end
/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXRenderController category separates off rendering-specific functionality from general
//window controller housework. The methods herein pass frame rendering on to the rendering view,
//and manage window size and fullscreen mode.

#import <Cocoa/Cocoa.h>
#import "BXDOSWindowController.h"

@class BXDOSWindow;
@class BXEmulator;
@class BXFrameBuffer;

@interface BXDOSWindowController (BXRenderController)

//Returns the size that the rendering view would currently be *if it were in windowed mode.*
//This will differ from the actual render view size if in fullscreen mode.
@property (readonly) NSSize windowedRenderingViewSize;

//Returns YES if the window is in the process of resizing itself.
@property (readonly) BOOL isResizing;

//Sets/gets whether the rendering view is currently fullscreen.
//See also setFullScreenWithZoom:
@property (assign, getter=isFullScreen) BOOL fullScreen;

//The screen to which we will render in fullscreen mode.
//This is currently the screen with the main menu on it.
@property (readonly) NSScreen *fullScreenTarget;

//The maximum BXFrameBuffer size we can render.
@property (readonly) NSSize maxFrameSize;

//The current size of the DOS rendering viewport.
@property (readonly) NSSize viewportSize;


#pragma mark -
#pragma mark Renderer-related methods

- (void) updateWithFrame: (BXFrameBuffer *)frame;

#pragma mark -
#pragma mark Window-sizing and fullscreen methods

//Sets the window to use the specified frame-autosave name, and adjusts the resulting
//frame to ensure the aspect ratio is consistent with what it was before.
- (void) setFrameAutosaveName: (NSString *)savedName;

//Zoom in and out of fullscreen mode with a smooth window sizing animation.
- (void) setFullScreenWithZoom: (BOOL)fullScreen;

//Resize the window to fit the specified render size, with an optional smooth resize animation.
- (void) resizeWindowToRenderingViewSize: (NSSize)newSize animate: (BOOL)performAnimation;

@end

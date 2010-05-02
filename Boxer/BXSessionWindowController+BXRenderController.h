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

//Window sizing methods
//---------------------

//Returns YES if the window is in the process of resizing itself.
- (BOOL) isResizing;

//Returns the size that the render view would currently be *if it were in windowed mode.*
//This will differ from the actual render view size if in fullscreen mode.
- (NSSize) windowedRenderViewSize;

//Resize the window to accomodate the specified view size. Returns YES if a resize was possible,
//or NO if there is not enough room onscreen to do so.
//Currently this is called when choosing a new filter to resize the window if it is smaller than
//the filter's minimum size.
- (BOOL) resizeToAtLeastSize: (NSSize) minViewSize;

//Resize the window to accomodate the specified DOS output size at the specified scale factor.
- (void) resizeToAccommodateOutputSize: (NSSize)outputSize atScale: (NSSize)scale;

//Switch to and from fullscreen mode instantly with no animation.
- (void) setFullScreen: (BOOL)fullScreen;

//Zoom in and out of fullscreen mode with a smooth window sizing animation.
- (void) setFullScreenWithZoom: (BOOL) fullScreen;

//Whether the rendering view is currently fullscreen.
- (BOOL) isFullScreen;

//The screen which we will render to in fullscreen mode.
- (NSScreen *) fullScreenTarget;
@end


//Methods in this category are not intended to be called outside of BXSessionWindowController.
@interface BXSessionWindowController (BXSessionWindowControllerInternals)

//Performs the slide animation used to toggle the status bar and program panel on or off
- (void) _slideView: (NSView *)view shown: (BOOL)show;

//Resize the window frame to fit the requested render size.
- (void) _resizeWindowToRenderViewSize: (NSSize)newSize animate: (BOOL)performAnimation;

//Returns the view size that should be used for rendering the specified DOSBox output size.
- (NSSize) _renderViewSizeForScaledOutputSize: (NSSize)scaledSize minSize: (NSSize)minViewSize;

@end
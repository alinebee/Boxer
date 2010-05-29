/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXRenderController category separates off rendering-specific functionality from general
//window controller housework. The methods herein liaise between BXDOSView and BXEmulator, pass UI
//signals back to BXEmulator, and manage resizing to ensure that the view size and rendering size
//are consistent.

#import <Cocoa/Cocoa.h>
#import "BXSessionWindowController.h"

@class BXSessionWindow;
@class BXEmulator;
@class BXDOSView;
@class BXFrameBuffer;

@interface BXSessionWindowController (BXRenderController)

- (void) updateWithFrame: (BXFrameBuffer *)frame;
- (NSSize) maxFrameSize;
- (NSSize) viewportSize;

//Window sizing methods
//---------------------

//Returns YES if the window is in the process of resizing itself.
- (BOOL) isResizing;

//Returns the size that the render view would currently be *if it were in windowed mode.*
//This will differ from the actual render view size if in fullscreen mode.
- (NSSize) windowedDOSViewSize;

//Switch to and from fullscreen mode instantly with no animation.
- (void) setFullScreen: (BOOL)fullScreen;

//Zoom in and out of fullscreen mode with a smooth window sizing animation.
- (void) setFullScreenWithZoom: (BOOL) fullScreen;

//Whether the rendering view is currently fullscreen.
- (BOOL) isFullScreen;

//The screen which we will render to in fullscreen mode.
- (NSScreen *) fullScreenTarget;
@end
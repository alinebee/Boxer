/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFrameRenderingView is a protocol for views that perform drawing of BXEmulator frames.
//It provides a consistent interface for BXSessionWindowController to communicate with
//different alternative view implementations.

#import <Cocoa/Cocoa.h>

@class BXFrameBuffer;

@protocol BXFrameRenderingView
@property (readonly) BXFrameBuffer *currentFrame;
@property (assign) BOOL managesAspectRatio;

//Tells the view to render the specified frame next time it is redrawn.
//Will usually mark the view as needing display.
- (void) updateWithFrame: (BXFrameBuffer *)frame;

//Reports the maximum displayable frame size.
- (NSSize) maxFrameSize;

//Reports the current viewport size to which frames will be rendered.
- (NSSize) viewportSize;

@end

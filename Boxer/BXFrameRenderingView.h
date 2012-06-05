/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFrameRenderingView is a protocol for views that perform drawing of BXEmulator frames.
//It provides a consistent interface for BXDOSWindowController to communicate with
//different alternative view implementations.

#import <Cocoa/Cocoa.h>

@class BXVideoFrame;

@protocol BXFrameRenderingView

//Returns whether the view should adjust its viewport to suit the aspect ratio
//of the current frame, or whether this will be done by adjusting the dimensions
//of the view itself.
- (void) setManagesAspectRatio: (BOOL)managesAspectRatio;
- (BOOL) managesAspectRatio;

//Tells the view to render the specified frame next time it is redrawn.
//Will usually mark the view as needing display.
- (void) updateWithFrame: (BXVideoFrame *)frame;

//Returns the current frame being rendered - i.e. the last frame that was passed
//to the view via updateWithFrame:.
- (BXVideoFrame *) currentFrame;


//Reports the maximum displayable frame size (which may be limited by e.g. OpenGL
//maximum texture dimensions.) Frames larger than this will not be passed to updateWithFrame:.
- (NSSize) maxFrameSize;

//Reports where in the view the current frame will actually be rendered.
//This may be a portion of the total view size, when in fullscreen mode.
- (NSRect) viewportRect;

@end

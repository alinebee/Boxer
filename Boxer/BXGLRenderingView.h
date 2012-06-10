/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXGLRenderingView is an NSOpenGLView subclass which displays DOSBox's rendered output.
//It manages a BXRenderer object to do the actual drawing, passing it new frames to draw
//and notifying it of changes to the view dimensions.

#import "BXFrameRenderingView.h"
#import <QuartzCore/QuartzCore.h>

@class BXRenderer;
@interface BXGLRenderingView : NSOpenGLView <BXFrameRenderingView>
{
	BXRenderer *_renderer;
    BXVideoFrame *_currentFrame;
	CVDisplayLinkRef _displayLink;
    BOOL _needsCVLinkDisplay;
    BOOL _managesAspectRatio;
    NSRect _viewportRect;
    NSSize _maxViewportSize;
}
@property (retain) BXRenderer *renderer;
@property (assign, nonatomic) BOOL managesAspectRatio;
@property (assign, nonatomic) NSSize maxViewportSize;
@property (assign, nonatomic) NSRect viewportRect;

//Returns the rectangular region of the view into which the specified frame will be drawn.
//This will be equal to the view bounds if managesAspectRatio is NO; otherwise, it will
//be a rectangle of the same aspect ratio as the frame fitted to within the current or maximum
//viewport size (whichever is smaller).
- (NSRect) viewportForFrame: (BXVideoFrame *)frame;
@end

/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXGLRenderingView is an NSOpenGLView subclass which displays DOSBox's rendered output.
//It manages a BXRenderer object to do the actual drawing, passing it new frames to draw
//and notifying it of changes to the view dimensions.


#import "BXFrameRenderingView.h"
#import <QuartzCore/QuartzCore.h>
#import "BXBasicRenderer.h"

@class BXBasicRenderer;
@class ADBTexture2D;

/// \c BXGLRenderingView is an \c NSOpenGLView subclass which displays DOSBox's rendered output.
/// It manages a \c BXRenderer object to do the actual drawing, passing it new frames to draw
/// and notifying it of changes to the view dimensions.
@interface BXGLRenderingView : NSOpenGLView <BXFrameRenderingView, BXRendererDelegate, NSAnimationDelegate>
{
	BXBasicRenderer *_renderer;
    BXVideoFrame *_currentFrame;
	CVDisplayLinkRef _displayLink;
    BOOL _needsCVLinkDisplay;
    BOOL _managesViewport;
    NSRect _viewportRect;
    NSRect _targetViewportRect;
    NSSize _maxViewportSize;
    BXRenderingStyle _renderingStyle;
    
    BOOL _needsRendererUpdate;
    
    BOOL _inViewportAnimation;
    BOOL _inViewAnimation;
    BOOL _usesTransparentSurface;
    
    BOOL _isLowSpecGPU;
}

@property (strong, nonatomic) BXBasicRenderer *renderer;
@property (assign, nonatomic) BXRenderingStyle renderingStyle;

@property (assign, nonatomic) BOOL managesViewport;
@property (assign, nonatomic) NSSize maxViewportSize;
@property (readonly, nonatomic) NSRect viewportRect;


/// Returns the rectangular region of the view into which the specified frame will be drawn.
/// This will be equal to the view bounds if managesAspectRatio is NO; otherwise, it will
/// be a rectangle of the same aspect ratio as the frame fitted to within the current or maximum
/// viewport size (whichever is smaller).
- (NSRect) viewportForFrame: (BXVideoFrame *)frame;

/// The renderer we should use for the specified rendering style, in the specified context.
/// Returns a fully-configured renderer set up for the specified context.
- (BXBasicRenderer *) rendererForStyle: (BXRenderingStyle)style
                             inContext: (CGLContextObj)context;

/// Set the viewport (the area of the view in which the frame is rendered) to the specified rectangle.
/// If animated is YES, the viewport will be smoothly animated to the new size; otherwise the viewport
/// will be changed immediately (cancelling any in-progress animation.)
- (void) setViewportRect: (NSRect)viewportRect animated: (BOOL)animated;

@end

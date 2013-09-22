/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXLayerBackedRenderingView.h"
#import "BXRenderingLayer.h"

@interface BXLayerBackedRenderingView ()

@property (retain, nonatomic) BXRenderingLayer *layer;

//Set the viewport (the area of the view in which the frame is rendered) to the specified rectangle.
//If animated is YES, the viewport will be smoothly animated to the new size; otherwise the viewport
//will be changed immediately (cancelling any in-progress animation.)
//- (void) setViewportRect: (NSRect)viewportRect animated: (BOOL)animated;

//Returns the rectangular region of the view into which the specified frame will be drawn.
//This will be equal to the view bounds if managesAspectRatio is NO; otherwise, it will
//be a rectangle of the same aspect ratio as the frame fitted to within the current or maximum
//viewport size (whichever is smaller).
//- (NSRect) viewportForFrame: (BXVideoFrame *)frame;

@end


@implementation BXLayerBackedRenderingView
@synthesize managesViewport = _managesViewport;
@synthesize maxViewportSize = _maxViewportSize;
@synthesize viewportRect = _viewportRect;

- (void) awakeFromNib
{
    self.layer = [BXRenderingLayer layer];
    self.layer.asynchronous = YES;
    self.layer.delegate = self;
    self.layer.frame = NSRectToCGRect(self.bounds);
    self.layer.needsDisplayOnBoundsChange = YES;
    self.layer.opaque = YES;
    
    self.wantsLayer = YES;
}

- (BXRenderingLayer *) layer
{
    return (BXRenderingLayer *)super.layer;
}

- (void) setLayer: (BXRenderingLayer *)layer
{
    NSAssert([layer isKindOfClass: [BXRenderingLayer class]], @"Layer must be an instance of BXGLRenderingLayer.");
    [super setLayer: layer];
}

- (void) setRenderingStyle: (BXRenderingStyle)style
{
    self.layer.renderingStyle = style;
}

- (BXRenderingStyle) renderingStyle
{
    return self.layer.renderingStyle;
}

- (BOOL) supportsRenderingStyle: (BXRenderingStyle)style
{
    return [self.layer supportsRenderingStyle: style];
}

- (void) updateWithFrame: (BXVideoFrame *)frame
{
    [self.layer updateWithFrame: frame];
}

+ (NSSet *) keyPathsForValuesAffectingCurrentFrame
{
    return [NSSet setWithObject: @"layer.currentFrame"];
}

- (BXVideoFrame *) currentFrame
{
    return self.layer.currentFrame;
}

- (NSSize) maxFrameSize
{
    //Fudged: this is dependant on the maximum texture size of the layer,
    //which depends on which context it's talking to, which we don't know
    return NSMakeSize(2048, 2048);
}

- (BOOL) layer: (CALayer *)layer shouldInheritContentsScale: (CGFloat)newScale fromWindow: (NSWindow *)window
{
    return YES;
}

@end
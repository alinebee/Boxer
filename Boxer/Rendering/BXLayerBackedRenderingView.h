/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>
#import <QuartzCore/CALayer.h>
#import "BXFrameRenderingView.h"

@class BXRenderingLayer;

/// \c BXGLLayerBackedRenderingView is an alternative BXFrameRenderingView implementation that uses
/// a \c CAOpenGLLayer to render frames. This has a few advantages over BXGLRenderingView:
/// - Other views can overlap with it
/// - View animations involving it perform smoothly
/// Aaand some disadvantages:
/// - All rendering occurs on the main thread, causing lag instead of dropped frames during heavy computation
/// - It slows down whenever notification bezels appear over it
@interface BXLayerBackedRenderingView : NSView <BXFrameRenderingView, CALayerDelegate>
{
    BOOL _managesViewport;
    NSSize _maxViewportSize;
}

@property (assign, nonatomic) BOOL managesViewport;
@property (assign, nonatomic) NSSize maxViewportSize;

@end

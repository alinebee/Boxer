/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXGLLayerBackedRenderingView

#import <Cocoa/Cocoa.h>
#import "BXFrameRenderingView.h"

@class BXRenderingLayer;
@interface BXLayerBackedRenderingView : NSView <BXFrameRenderingView>
{
    BOOL _managesViewport;
    NSSize _maxViewportSize;
}

@property (assign, nonatomic) BOOL managesViewport;
@property (assign, nonatomic) NSSize maxViewportSize;

@end

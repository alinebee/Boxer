/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//Convenience classes for Boxer's builtin shader-based renderers.

#import "BXSteppedShaderRenderer.h"


@interface BXBuiltinShaderRenderer : BXSteppedShaderRenderer

- (id) initWithShaderNames: (NSArray *)shaderNames
                  atScales: (CGFloat *)scales
                 inContext: (CGLContextObj)glContext
                     error: (NSError **)outError;

@end

/// A preset renderer that applies the smoothed appearance.
@interface BXSmoothedRenderer : BXBuiltinShaderRenderer

@end

/// A preset renderer that applies the CRT scanlines appearance.
@interface BXCRTRenderer : BXBuiltinShaderRenderer

@end
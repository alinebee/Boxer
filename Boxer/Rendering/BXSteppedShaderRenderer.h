/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXShaderRenderer.h"

/// \c BXSteppedShaderRenderer is a renderer that uses different shaders depending on the current scale:
/// e.g. one version of the shader optimised for 2x, another for 3x, another for 4x and above.
@interface BXSteppedShaderRenderer : BXShaderRenderer
{
    NSMutableArray *_shaderSets;
    CGFloat *_scales;
    BOOL _scalesInPixels;
}

/// Whether the scales for this shader are relative multiples or absolute pixel sizes.
@property (assign, nonatomic) BOOL scalesInPixels;

/// Creates a renderer that uses the specified shader sets at the specified scales.
- (id) initWithShaderSets: (NSArray *)shaderSets
                 atScales: (CGFloat *)steps
                inContext: (CGLContextObj)glContext
                    error: (NSError **)outError;

- (id) initWithContentsOfURLs: (NSArray *)shaderURLs
                     atScales: (CGFloat *)steps
                    inContext: (CGLContextObj)glContext
                        error: (NSError **)outError;

@end

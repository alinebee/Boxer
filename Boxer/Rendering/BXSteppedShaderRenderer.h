//
//  BXSteppedShaderRenderer.h
//  Boxer
//
//  Created by Alun Bestor on 23/09/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

//BXSteppedShaderRenderer is a renderer that uses different shaders depending on the current scale:
//e.g. one version of the shader optimised for 2x, another for 3x, another for 4x and above.


#import "BXShaderRenderer.h"

@interface BXSteppedShaderRenderer : BXShaderRenderer
{
    NSMutableArray *_shaderSets;
    CGFloat *_scales;
    BOOL _scalesInPixels;
}

//Whether the scales for this shader are relative multiples or absolute pixel sizes.
@property (assign, nonatomic) BOOL scalesInPixels;

//Creates a renderer that uses the specified shader sets at the specified scales.
- (id) initWithShaderSets: (NSArray *)shaderSets
                 atScales: (CGFloat *)steps
                inContext: (CGLContextObj)glContext
                    error: (NSError **)outError;

- (id) initWithContentsOfURLs: (NSArray *)shaderURLs
                     atScales: (CGFloat *)steps
                    inContext: (CGLContextObj)glContext
                        error: (NSError **)outError;

@end

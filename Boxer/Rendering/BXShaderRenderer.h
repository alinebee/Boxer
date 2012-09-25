//
//  BXShaderRenderer.h
//  Boxer
//
//  Created by Alun Bestor on 20/06/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import "BXSupersamplingRenderer.h"

@interface BXShaderRenderer : BXSupersamplingRenderer
{
	NSArray *_shaders;
    CGSize _shaderOutputSizes[10];
    BXTexture2D *_auxiliaryBufferTexture;
    
    BOOL _shouldUseShaders;
    BOOL _usesShaderSupersampling;
}

#pragma mark -
#pragma mark Properties

//Whether to render the shader to the largest integer multiple of the base resolution
//instead of to the destination size. Defaults to YES.
@property (assign, nonatomic) BOOL usesShaderSupersampling;


#pragma mark -
#pragma mark Initialization and deallocation

//Returns a new shader renderer using the specified set of shaders.
- (id) initWithShaderSet: (NSArray *)shaderSet
               inContext: (CGLContextObj)glContext
                   error: (NSError **)outError;

//Returns a new shader renderer using shaders loaded from the specified URL.
- (id) initWithContentsOfURL: (NSURL *)shaderURL
                   inContext: (CGLContextObj)glContext
                       error: (NSError **)outError;

@end

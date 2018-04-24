/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSupersamplingRenderer.h"

@interface BXShaderRenderer : BXSupersamplingRenderer
{
	NSArray *_shaders;
    CGSize _shaderOutputSizes[10];
    ADBTexture2D *_auxiliaryBufferTexture;
    
    BOOL _shouldUseShaders;
    BOOL _usesShaderSupersampling;
}

#pragma mark -
#pragma mark Properties

/// Whether to render the shader to the largest integer multiple of the base resolution
/// instead of to the destination size. Defaults to YES.
@property (assign, nonatomic) BOOL usesShaderSupersampling;


#pragma mark -
#pragma mark Initialization and deallocation

/// Returns a new shader renderer using the specified set of shaders.
- (id) initWithShaderSet: (NSArray *)shaderSet
               inContext: (CGLContextObj)glContext
                   error: (NSError **)outError;

/// Returns a new shader renderer using shaders loaded from the specified URL.
- (id) initWithContentsOfURL: (NSURL *)shaderURL
                   inContext: (CGLContextObj)glContext
                       error: (NSError **)outError;

@end

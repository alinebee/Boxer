/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSteppedShaderRenderer.h"
#import "BXBasicRendererPrivate.h"
#import "ADBBSNESShader.h"

@interface BXSteppedShaderRenderer ()

@property (retain, nonatomic) NSMutableArray *shaderSets;

//Returns the set of shaders most appropriate for the specified frame and viewport.
- (NSArray *) _shadersForFrame: (BXVideoFrame *)frame scaledToViewport: (CGRect)viewport;

@end


@implementation BXSteppedShaderRenderer
@synthesize shaderSets = _shaderSets;
@synthesize scalesInPixels = _scalesInPixels;

- (id) initWithShaderSets: (NSArray *)shaderSets
                 atScales: (CGFloat *)steps
                inContext: (CGLContextObj)glContext
                    error: (NSError **)outError
{
    self = [super initWithContext: glContext error: outError];
    if (self)
    {
        NSUInteger i, numScales = shaderSets.count;
        
        self.shaderSets = [NSMutableArray arrayWithArray: shaderSets];
        _scales = malloc(sizeof(CGFloat) * numScales);
        
        for (i=0; i<numScales; i++)
            _scales[i] = steps[i];
    }
    return self;
}

- (id) initWithContentsOfURLs: (NSArray *)shaderURLs
                     atScales: (CGFloat *)steps
                    inContext: (CGLContextObj)glContext
                        error: (NSError **)outError
{
    NSMutableArray *shaderSets = [NSMutableArray arrayWithCapacity: shaderURLs.count];
    BOOL loadingSucceeded = YES;
    for (NSURL *URL in shaderURLs)
    {
        NSArray *shaders = [ADBBSNESShader shadersWithContentsOfURL: URL inContext: glContext error: outError];
        if (shaders)
        {
            [shaderSets addObject: shaders];
        }
        else
        {
            loadingSucceeded = NO;
            break;
        }
    }
    
    if (loadingSucceeded)
    {
        self = [self initWithShaderSets: shaderSets atScales: steps inContext: glContext error: outError];
    }
    else
    {
        [self dealloc];
        self = nil;
    }
    return self;
}

- (void) dealloc
{
    if (_scales)
    {
        free(_scales);
        _scales = NULL;
    }
    [super dealloc];
}

- (void) tearDownContext
{
    [super tearDownContext];
    
    for (NSArray *shaderSet in self.shaderSets)
    {
        [shaderSet makeObjectsPerformSelector: @selector(deleteShaderProgram)];
    }
    self.shaderSets = nil;
}

//We assume that our scale array is ordered from lowest to highest, then
//walk through our scales backwards to locate a shader which is suitable
//for the target scale.
- (NSArray *) _shadersForFrame: (BXVideoFrame *)frame scaledToViewport: (CGRect)viewport
{
    CGFloat targetScale;
    
    if (self.scalesInPixels)
    {
        targetScale = viewport.size.height;
    }
    else
    {
        //BEHAVIOUR NOTE: we use the height scale in favour of the width scale
        //so that we'll use a higher-fidelity shader when aspect ratio correction
        //is in effect.
        CGPoint scalingFactor = [self _scalingFactorFromFrame: frame toViewport: viewport];
        targetScale = scalingFactor.y;
    }
    
    NSUInteger i, numScales = self.shaderSets.count;
    for (i=numScales; i>0; i--)
    {
        CGFloat scale = _scales[i-1];
        if (targetScale >= scale)
        {
            return [self.shaderSets objectAtIndex: i-1];
        }
    }
    
    return nil;
}

- (void) _prepareSupersamplingBufferForFrame: (BXVideoFrame *)frame
{
    if (_shouldRecalculateBuffer)
    {
        self.shaders = [self _shadersForFrame: frame scaledToViewport: self.viewport];
        
        [super _prepareSupersamplingBufferForFrame: frame];
    }
}
@end

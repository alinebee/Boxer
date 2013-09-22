/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXRenderingLayer.h"
#import "BXBasicRenderer.h"
#import "BXSupersamplingRenderer.h"
#import "BXBuiltinShaderRenderers.h"

#import <OpenGL/CGLMacro.h>


#pragma mark - Private method declarations

@interface BXRenderingLayer ()

@property (retain, nonatomic) NSMutableArray *renderers;
@property (retain, nonatomic) BXVideoFrame *currentFrame;

+ (BOOL) contextSupportsAdvancedShaders: (CGLContextObj)context;
+ (Class) rendererClassForStyle: (BXRenderingStyle)style;
+ (BXBasicRenderer *) prepareRendererForStyle: (BXRenderingStyle)style
                                    inContext: (CGLContextObj)context;

- (BXBasicRenderer *) rendererForStyle: (BXRenderingStyle)style
                             inContext: (CGLContextObj)context;

@end


#pragma mark - Implementation

@implementation BXRenderingLayer
@synthesize renderers = _renderers;
@synthesize renderingStyle = _renderingStyle;
@synthesize currentFrame = _currentFrame;

#pragma mark - Renderer creation

+ (Class) rendererClassForStyle: (BXRenderingStyle)style
{
    Class rendererClass;
    switch (style)
    {
        case BXRenderingStyleSmoothed:
            rendererClass = [BXSmoothedRenderer class];
            break;
        case BXRenderingStyleCRT:
            rendererClass = [BXCRTRenderer class];
            break;
        case BXRenderingStyleNormal:
        default:
            rendererClass = [BXSupersamplingRenderer class];
            break;
    }
    return rendererClass;
}

+ (BOOL) contextSupportsAdvancedShaders: (CGLContextObj)context
{
    CGLContextObj cgl_ctx = context;
    GLint maxTextureDims = 0;
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureDims);
    return (maxTextureDims >= 4096);
}

+ (BXBasicRenderer *) prepareRendererForStyle: (BXRenderingStyle)style
                                    inContext: (CGLContextObj)context
{
    //Try to load a renderer for the specified rendering style.
    //If that fails, fall back on increasingly simple renderers until
    //we find one that works (or run out of options.)
    NSArray *renderersToTry;
    
    //On low-performance GPUs, don't even bother trying a fancy renderer:
    //just stick with our standard renderers.
    if (![self contextSupportsAdvancedShaders: context])
    {
        renderersToTry = @[
                           [BXSupersamplingRenderer class],
                           [BXBasicRenderer class],
                           ];
    }
    else
    {
        renderersToTry = @[
                           [self rendererClassForStyle: style],
                           [BXSupersamplingRenderer class],
                           [BXBasicRenderer class],
                           ];
    }
    
    for (Class rendererClass in renderersToTry)
    {
        NSError *loadError = nil;
        BXBasicRenderer *renderer = [[[rendererClass alloc] initWithContext: context error: &loadError] autorelease];
        
        NSAssert(renderer != nil, @"Error loading %@ renderer: %@", NSStringFromClass(rendererClass), loadError);
        
        [renderer prepareContext];
        
        return renderer;
    }
    
    NSAssert(NO, @"No valid renderer could be created, we're screwed!");
    
    return nil;
}

- (BXBasicRenderer *) rendererForStyle: (BXRenderingStyle)style inContext: (CGLContextObj)context
{
    for (BXBasicRenderer *renderer in self.renderers)
    {
        if (renderer.context == context)
            return renderer;
    }
    
    //If we got this far, we don't have a renderer ready for this context yet.
    BXBasicRenderer *renderer = [self.class prepareRendererForStyle: style inContext: context];
    if (!self.renderers)
        self.renderers = [NSMutableArray arrayWithCapacity: 1];
    
    [self.renderers addObject: renderer];
    
    return renderer;
}

- (void) setRenderingStyle: (BXRenderingStyle)style
{
    if (style != _renderingStyle)
    {
        _renderingStyle = style;
        
        //Ensure that we'll be re-rendered
        _lastRenderTime = 0;
    }
}

//FIXME: the answer to this depends on the context we're currently talking to.
- (BOOL) supportsRenderingStyle: (BXRenderingStyle)style
{
    return YES;
}

#pragma mark - Rendering

- (BOOL) canDrawInCGLContext: (CGLContextObj)glContext
                 pixelFormat: (CGLPixelFormatObj)pixelFormat
                forLayerTime: (CFTimeInterval)timeInterval
                 displayTime: (const CVTimeStamp *)timeStamp
{
    return self.currentFrame != nil && _lastFrameUpdateTime > _lastRenderTime;
}

- (void) drawInCGLContext: (CGLContextObj)ctx
              pixelFormat: (CGLPixelFormatObj)pf
             forLayerTime: (CFTimeInterval)t
              displayTime: (const CVTimeStamp *)ts
{
    BXBasicRenderer *renderer = [self rendererForStyle: self.renderingStyle inContext: ctx];
    
    BOOL recalculateViewport = ![(NSView *)self.delegate inLiveResize];
    
    [renderer setViewport: self.bounds recalculate: recalculateViewport];
    [renderer updateWithFrame: self.currentFrame];
    [renderer render];
    
	[super drawInCGLContext: ctx pixelFormat: pf forLayerTime: t displayTime: ts];
    
    _lastRenderTime = t;
}

- (void) releaseCGLContext: (CGLContextObj)ctx
{
    for (BXBasicRenderer *renderer in [NSArray arrayWithArray: self.renderers])
    {
        if (renderer.context == ctx)
        {
            [renderer tearDownContext];
        }
    }
    
    [super releaseCGLContext: ctx];
}

- (void) updateWithFrame: (BXVideoFrame *)frame
{
    self.currentFrame = frame;
    _lastFrameUpdateTime = CFAbsoluteTimeGetCurrent();
    [self setNeedsDisplay];
}

- (void) dealloc
{
    self.renderers = nil;
    self.currentFrame = nil;
    [super dealloc];
}

@end
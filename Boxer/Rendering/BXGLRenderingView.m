/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXGLRenderingView.h"
#import "BXBuiltinShaderRenderers.h"
#import "ADBTexture2D.h"
#import "BXVideoFrame.h"
#import "ADBGeometry.h"
#import "ADBGLHelpers.h"

#import <OpenGL/CGLMacro.h>

#pragma mark -
#pragma mark Private interface declarations

@interface BXGLRenderingView ()

@property (retain) BXVideoFrame *currentFrame;

@property (assign, nonatomic) NSRect viewportRect;

//Whether we should redraw in the next display-link cycle.
//Set to YES upon receiving a new frame, then back to NO after rendering it.
@property (assign) BOOL needsCVLinkDisplay;
//Whether we're currently involved in a view animation.

//This will avoid drawing with the CV link for the duration of the animation.
@property (assign, getter=isInViewAnimation) BOOL inViewAnimation;


//The display link callback that renders the next frame in sync with the screen refresh.
CVReturn BXDisplayLinkCallback(CVDisplayLinkRef displayLink,
                               const CVTimeStamp* now,  
                               const CVTimeStamp* outputTime,
                               CVOptionFlags flagsIn,
                               CVOptionFlags* flagsOut,
                               void* displayLinkContext);

//Updates the current renderer with the appropriate OpenGL viewport,
//whenever the renderer or the viewport changes.
- (void) _applyViewportToRenderer;

//Called when a live resize or other animation ends, to recaculate with the final state of the viewport. 
- (void) _finalizeViewportChanges;

@end


@implementation BXGLRenderingView
@synthesize renderer = _renderer;
@synthesize currentFrame = _currentFrame;
@synthesize managesViewport = _managesViewport;
@synthesize needsCVLinkDisplay = _needsCVLinkDisplay;
@synthesize viewportRect = _viewportRect;
@synthesize maxViewportSize = _maxViewportSize;
@synthesize renderingStyle = _renderingStyle;
@synthesize inViewAnimation = _inViewAnimation;

- (void) dealloc
{
    self.currentFrame = nil;
    self.renderer = nil;
	[super dealloc];
}


//Pass on various events that would otherwise be eaten by the default NSView implementation
- (void) rightMouseDown: (NSEvent *)theEvent
{
	[self.nextResponder rightMouseDown: theEvent];
}

#pragma mark -
#pragma mark Rendering methods

- (Class) rendererClassForStyle: (BXRenderingStyle)style
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

- (BXBasicRenderer *) rendererForStyle: (BXRenderingStyle)style inContext: (CGLContextObj)context
{
    //Try to load a renderer for the specified rendering style.
    //If that fails, fall back on increasingly simple renderers until
    //we find one that works (or run out of options.)
    NSArray *renderersToTry;
    
    //On low-performance GPUs, don't even bother trying a fancy renderer:
    //just stick with our standard renderers.
    if (_isLowSpecGPU)
    {
        renderersToTry = [NSArray arrayWithObjects:
                          [BXSupersamplingRenderer class],
                          [BXBasicRenderer class],
                          nil];
    }
    else
    {
        renderersToTry = [NSArray arrayWithObjects:
                          [self rendererClassForStyle: style],
                          [BXSupersamplingRenderer class],
                          [BXBasicRenderer class],
                          nil];
    }
    
    
    for (Class rendererClass in renderersToTry)
    {
        NSError *loadError = nil;
        BXBasicRenderer *renderer = [[[rendererClass alloc] initWithContext: context error: &loadError] autorelease];
        if (renderer)
            return renderer;
        else
            NSLog(@"Error loading %@ renderer: %@", NSStringFromClass(rendererClass), loadError);
    }
    
    NSAssert(NO, @"No valid renderer could be created, we're screwed!");
    
    return nil;
}

- (void) updateWithFrame: (BXVideoFrame *)frame
{
    self.currentFrame = frame;
    
    CGLContextObj cgl_ctx = self.openGLContext.CGLContextObj;
    CGLLockContext(cgl_ctx);
        [self.renderer updateWithFrame: frame];
    CGLUnlockContext(cgl_ctx);
    
    //If the frame changes size or aspect ratio, and we're responsible for the viewport ourselves,
    //then smoothly animate the transition to the new size. 
    if (self.managesViewport)
    {
        [self setViewportRect: [self viewportForFrame: frame]
                     animated: YES];
    }
    
    //If we're using a CV Link, don't tell Cocoa that we need redrawing:
    //Instead, flag that we need to render and flush in the display link.
    //This prevents Cocoa from drawing the dirty view at the 'wrong' time.
    if (_displayLink)
        self.needsCVLinkDisplay = YES;
    else
        self.needsDisplay = YES;
}


+ (id) defaultAnimationForKey: (NSString *)key
{
    if ([key isEqualToString: @"viewportRect"])
    {
		CABasicAnimation *animation = [CABasicAnimation animation];
        animation.duration = 0.2;
        animation.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseIn];
        animation.delegate = self;
        return animation;
    }
    else
    {
        return [super defaultAnimationForKey: key];
    }
}

- (void) animationDidStart: (CAAnimation *)anim
{
    _inViewportAnimation = YES;
}

- (void) animationDidStop: (CAAnimation *)anim finished: (BOOL)flag
{
    _inViewportAnimation = NO;
    anim.delegate = nil;
    
    [self _finalizeViewportChanges];
}

//Returns the rectangular region of the view into which the specified frame should be drawn.
- (NSRect) viewportForFrame: (BXVideoFrame *)frame
{
    if (frame != nil && self.managesViewport)
	{
		NSSize frameSize = frame.scaledSize;
		NSRect frameRect = NSMakeRect(0.0f, 0.0f, frameSize.width, frameSize.height);
        
        NSRect canvasRect = self.bounds;
        NSRect maxViewportRect = canvasRect;
        
        //If we have a maximum viewport size, fit the frame within that; otherwise, just fill the canvas as best we can.
        if (!NSEqualSizes(self.maxViewportSize, NSZeroSize) && sizeFitsWithinSize(self.maxViewportSize, canvasRect.size))
        {
            maxViewportRect = resizeRectFromPoint(canvasRect, self.maxViewportSize, NSMakePoint(0.5f, 0.5f));
        }
        
        NSRect fittedViewportRect = fitInRect(frameRect, maxViewportRect, NSMakePoint(0.5f, 0.5f));
        
        return fittedViewportRect;
	}
	else
    {
        return self.bounds;
    }
}

- (void) setManagesViewport: (BOOL)enabled
{
    if (self.managesViewport != enabled)
    {
        _managesViewport = enabled;
        
        //Update our viewport immediately to compensate for the change
        [self setViewportRect: [self viewportForFrame: self.currentFrame]
                     animated: NO];
    }
}

- (void) setViewportRect: (NSRect)newRect
{
    if (!NSEqualRects(newRect, _viewportRect))
    {
        _viewportRect = newRect;
        
        [self _applyViewportToRenderer];
        
        if (_displayLink)
            self.needsCVLinkDisplay = YES;
        else
            self.needsDisplay = YES;
    }
}

- (void) setViewportRect: (NSRect)newRect animated: (BOOL)animated
{
    if (!NSEqualRects(_targetViewportRect, newRect))
    {
        //If our viewport is zero (i.e. we haven't received a frame until now)
        //then just replace the viewport with the new one instead of animating to it.
        if (NSIsEmptyRect(_viewportRect))
        {
            self.viewportRect = newRect;
        }
        else
        {
            NSTimeInterval duration = (animated) ? 0.2 : 0;
            
            _targetViewportRect = newRect;
            
            [NSAnimationContext beginGrouping];
                [NSAnimationContext currentContext].duration = duration;
                [self.animator setViewportRect: _targetViewportRect];
            [NSAnimationContext endGrouping];
        }
    }
}

- (void) _applyViewportToRenderer
{
    CGLContextObj cgl_ctx = self.openGLContext.CGLContextObj;
    CGLLockContext(cgl_ctx);
        NSRect backingRect = self.viewportRect;
        
        //Compensate for hi-res contexts
        if ([self respondsToSelector: @selector(convertRectToBacking:)])
            backingRect = [self convertRectToBacking: backingRect];
    
        BOOL recalculate = !(_inViewportAnimation || self.inLiveResize);
        [self.renderer setViewport: NSRectToCGRect(backingRect) recalculate: recalculate];
    CGLUnlockContext(cgl_ctx);
}

- (void) _finalizeViewportChanges
{
    [self.renderer recalculateViewport];
    
    if (_displayLink)
        self.needsCVLinkDisplay = YES;
    else
        self.needsDisplay = YES;
}

- (void) setMaxViewportSize: (NSSize)maxViewportSize
{
    if (!NSEqualSizes(maxViewportSize, self.maxViewportSize))
    {
        _maxViewportSize = maxViewportSize;
        
        //Animate our viewport to the new viewport size if it's not already there.
        [self setViewportRect: [self viewportForFrame: self.currentFrame]
                     animated: YES];
    }
}

- (NSSize) maxFrameSize
{
	return NSSizeFromCGSize(self.renderer.maxFrameSize);
}

- (void) setRenderingStyle: (BXRenderingStyle)renderingStyle
{
    NSAssert1(renderingStyle >= 0 && renderingStyle < BXNumRenderingStyles,
              @"Unrecognised rendering style: %i", renderingStyle);
    
    if (self.renderingStyle != renderingStyle)
    {
        _renderingStyle = renderingStyle;
        
        //Switch renderers to one that suits the new rendering style
        if (self.openGLContext)
        {
            _needsRendererUpdate = YES;
            
            if (_displayLink)
                self.needsCVLinkDisplay = YES;
            else
                self.needsDisplay = YES;
        }
    }
}

- (BOOL) supportsRenderingStyle: (BXRenderingStyle)style
{
    if (style == BXRenderingStyleNormal)
        return YES;
    else
        return !_isLowSpecGPU;
}


- (void) setRenderer: (BXBasicRenderer *)renderer
{
    if (_renderer != renderer)
    {
        CGLLockContext(self.openGLContext.CGLContextObj);
            //Tell the old renderer to dispose of its assets immediately.
            [self.renderer tearDownContext];
            
            [_renderer release];
            _renderer = [renderer retain];
        
            self.renderer.delegate = self;
        
            //Tell the new renderer to configure its context.
            [self.renderer prepareContext];
            
            if (self.currentFrame)
                [self.renderer updateWithFrame: self.currentFrame];
            
            //Sync up the new renderer with our current state.
            if (NSIsEmptyRect(self.viewportRect))
            {
                NSRect viewportRect = [self viewportForFrame: self.currentFrame];
                [self setViewportRect: viewportRect animated: NO];
            }
            else
            {
                [self _applyViewportToRenderer];
            }
        CGLUnlockContext(self.openGLContext.CGLContextObj);
    }
}

- (void) prepareOpenGL
{
	CGLContextObj cgl_ctx = self.openGLContext.CGLContextObj;
	
    CGLLockContext(cgl_ctx);
    
	//Enable multithreaded OpenGL execution (if available)
	CGLEnable(cgl_ctx, kCGLCEMPEngine);
    
    //Synchronize buffer swaps with vertical refresh rate
    GLint useVSync = [[NSUserDefaults standardUserDefaults] boolForKey: @"useVSync"];
    [self.openGLContext setValues: &useVSync
                     forParameter: NSOpenGLCPSwapInterval];
	
    //As a very simple test of the performance, check the GPU's maximum texture size.
    //A low size such as 2048x2048 indicates a very low-performance GPU.
    
    GLint maxTextureDims = 0;
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureDims);
    _isLowSpecGPU = (maxTextureDims < 4096);
    
    //Create a new renderer for this context, and set it up appropriately
    self.renderer = [self rendererForStyle: self.renderingStyle
                                 inContext: cgl_ctx];
    
    //Set up the CV display link if desired
    BOOL useCVDisplayLink = [[NSUserDefaults standardUserDefaults] boolForKey: @"useCVDisplayLink"];
    if (useCVDisplayLink)
    {
        //Create a display link capable of being used with all active displays
        CVReturn status = CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
        
        if (status == kCVReturnSuccess)
        {
            //Set the renderer output callback function
            CVDisplayLinkSetOutputCallback(_displayLink, &BXDisplayLinkCallback, (__bridge void *)(self));
            
            // Set the display link for the current renderer
            CGLPixelFormatObj cglPixelFormat = self.pixelFormat.CGLPixelFormatObj;
            CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(_displayLink, cgl_ctx, cglPixelFormat);
            
            //Activate the display link
            CVDisplayLinkStart(_displayLink);
        }
    }
    
    CGLUnlockContext(cgl_ctx);
}

- (void) clearGLContext
{
    //Get rid of our entire renderer when the context changes.
    self.renderer = nil;
    
	if (_displayLink)
	{
		CVDisplayLinkRelease(_displayLink);
		_displayLink = NULL;
	}
    	
	[super clearGLContext];
}

- (void) reshape
{
    [super reshape];
    
    //Instantly recalculate our viewport rect whenever the view changes shape.
    [self setViewportRect: [self viewportForFrame: self.currentFrame] animated: NO];
}

- (void) viewDidEndLiveResize
{
    [self _finalizeViewportChanges];
}

- (void) windowDidChangeBackingProperties: (NSNotification *)notification
{
    [self _applyViewportToRenderer];
}

- (void) viewAnimationWillStart: (NSViewAnimation *)animation
{
    self.inViewAnimation = YES;
    
    //If the animation involves fading the opacity of one of our parent views,
    //we'll need to change our rendering method to compensate.
    BOOL involvesFade = NO;
    for (NSDictionary *animDefinition in animation.viewAnimations)
    {
        NSView *targetView = [animDefinition objectForKey: NSViewAnimationTargetKey];
        if ([self isDescendantOf: targetView])
        {
            NSString *animType = [animDefinition objectForKey: NSViewAnimationEffectKey];
            if ([animType isEqualToString: NSViewAnimationFadeInEffect] ||
                [animType isEqualToString: NSViewAnimationFadeOutEffect])
            {
                involvesFade = YES;
                break;
            }
        }
    }
    
    if (involvesFade)
    {
        _usesTransparentSurface = YES;
        GLint opacity = 0;
        [self.openGLContext setValues: &opacity forParameter: NSOpenGLCPSurfaceOpacity];
    }
}

- (void) viewAnimationDidEnd: (NSViewAnimation *)animation
{
    if (_usesTransparentSurface)
    {
        _usesTransparentSurface = NO;
        GLint opacity = 1;
        [self.openGLContext setValues: &opacity forParameter: NSOpenGLCPSurfaceOpacity];
    }
    self.inViewAnimation = NO;
    
    //Apply any viewport changes that may have occurred.
    [self _finalizeViewportChanges];
}

- (void) drawRect: (NSRect)dirtyRect
{
    if (![self.renderer canRender])
    {
        [[NSColor blackColor] set];
        NSRectFill(dirtyRect);
    }
    else
    {
        self.needsCVLinkDisplay = NO;
        
        CGLContextObj cgl_ctx = self.openGLContext.CGLContextObj;
        
        CGLLockContext(cgl_ctx);
        
            if (_needsRendererUpdate)
            {
                self.renderer = [self rendererForStyle: self.renderingStyle inContext: cgl_ctx];
                _needsRendererUpdate = NO;
            }
            
            [self.renderer render];
            CGLFlushDrawable(cgl_ctx);
        
        CGLUnlockContext(cgl_ctx);
    }
}

- (void) renderer: (BXBasicRenderer *)renderer willRenderTextureToDestinationContext: (ADBTexture2D *)texture
{
    
}

- (void) renderer: (BXBasicRenderer *)renderer didRenderTextureToDestinationContext: (ADBTexture2D *)texture
{
    
}

CVReturn BXDisplayLinkCallback(CVDisplayLinkRef displayLink,
                               const CVTimeStamp* now,  
                               const CVTimeStamp* outputTime,
                               CVOptionFlags flagsIn,
                               CVOptionFlags* flagsOut,
                               void* displayLinkContext)
{
	//Needed because we're operating in a different thread
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	BXGLRenderingView *view = (__bridge BXGLRenderingView *)displayLinkContext;
    
    if (view.needsCVLinkDisplay && !view.inViewAnimation)
        [view display];
    
	[pool drain];
	return kCVReturnSuccess;
}

@end
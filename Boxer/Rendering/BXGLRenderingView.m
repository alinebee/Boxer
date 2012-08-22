/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXGLRenderingView.h"
#import "BXBasicRenderer.h"
#import "BXSupersamplingRenderer.h"
#import "BXShaderRenderer.h"
#import "BXRippleShader.h"
#import "BXTexture2D.h"
#import "BXVideoFrame.h"
#import "BXGeometry.h"
#import "BXDOSWindowController.h" //For notifications
#import "BXBSNESShader.h"
#import "BXPostLeopardAPIs.h"
#import "NSView+BXDrawing.h"
#import "BXGLHelpers.h"

#import <OpenGL/CGLMacro.h>

#pragma mark -
#pragma mark Private interface declarations

@interface BXGLRenderingView ()

@property (retain) BXVideoFrame *currentFrame;

@property (retain) BXRippleShader *rippleEffect2D;
@property (retain) BXRippleShader *rippleEffectRectangle;

@property (assign, nonatomic) CGPoint rippleOrigin;
@property (assign, nonatomic) CGFloat rippleProgress;
@property (assign, nonatomic) BOOL rippleReversed;

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
- (void) _applyViewportToRenderer: (BXBasicRenderer *)renderer;

@end

@interface NSBitmapImageRep (BXFlipper)

//Flip the pixels of the bitmap from top to bottom. Used when grabbing screenshots from the GL view.
- (void) flip;

@end



@implementation BXGLRenderingView
@synthesize renderer = _renderer;
@synthesize currentFrame = _currentFrame;
@synthesize managesAspectRatio = _managesAspectRatio;
@synthesize needsCVLinkDisplay = _needsCVLinkDisplay;
@synthesize viewportRect = _viewportRect;
@synthesize maxViewportSize = _maxViewportSize;
@synthesize renderingStyle = _renderingStyle;
@synthesize inViewAnimation = _inViewAnimation;

@synthesize rippleEffect2D = _rippleEffect2D;
@synthesize rippleEffectRectangle = _rippleEffectRectangle;

@synthesize rippleProgress = _rippleProgress;
@synthesize rippleOrigin = _rippleOrigin;
@synthesize rippleReversed = _rippleReversed;

- (void) dealloc
{
    self.currentFrame = nil;
    self.renderer = nil;
    self.rippleEffect2D = nil;
    self.rippleEffectRectangle = nil;
	[super dealloc];
}


//Pass on various events that would otherwise be eaten by the default NSView implementation
- (void) rightMouseDown: (NSEvent *)theEvent
{
	[self.nextResponder rightMouseDown: theEvent];
}

#pragma mark -
#pragma mark Rendering methods

- (BXBasicRenderer *) rendererForStyle: (BXRenderingStyle)style inContext: (CGLContextObj)context
{
    BXBasicRenderer *renderer = nil;
    NSString *shaderName = nil;
    
    switch (style)
    {
        case BXRenderingStyleNormal:
            shaderName = nil;
            break;
        case BXRenderingStyleSmoothed:
            shaderName = @"5xBR Semi-Rounded";
            break;
        case BXRenderingStyleCRT:
            shaderName = @"CRT-simple";
            break;
    }
    
    if (shaderName)
    {
        NSURL *shaderURL = [[NSBundle mainBundle] URLForResource: shaderName
                                                   withExtension: @"shader"
                                                    subdirectory: @"Shaders"];
        
        NSError *loadError = nil;
        renderer = [[[BXShaderRenderer alloc] initWithContentsOfURL: shaderURL
                                                          inContext: context
                                                              error: &loadError] autorelease];
        
        if (loadError)
            NSLog(@"Error loading renderer for %@ shader: %@", shaderName, loadError);
    }
    
    if (!renderer)
        renderer = [[[BXSupersamplingRenderer alloc] initWithContext: context error: NULL] autorelease];
    
    if (!renderer)
        renderer = [[[BXBasicRenderer alloc] initWithContext: context error: NULL] autorelease];
    
    return renderer;
}

- (void) updateWithFrame: (BXVideoFrame *)frame
{
    self.currentFrame = frame;
    
    CGLContextObj cgl_ctx = self.openGLContext.CGLContextObj;
    CGLLockContext(cgl_ctx);
        [self.renderer updateWithFrame: frame];
    CGLUnlockContext(cgl_ctx);
    
    //If the view changes aspect ratio, and we're responsible for the aspect ratio ourselves,
    //then smoothly animate the transition to the new ratio. 
    if (self.managesAspectRatio)
    {
        NSRect newViewport = [self viewportForFrame: frame];
        if (!NSEqualRects(newViewport, self.viewportRect))
            [self.animator setViewportRect: newViewport];
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
        animation.duration = 0.1;
        return animation;
    }
    else if ([key isEqualToString: @"rippleProgress"])
    {
        CABasicAnimation *animation = [CABasicAnimation animation];
        animation.duration = 0.5;
        return animation;
    }
    else
    {
        return [super defaultAnimationForKey: key];
    }
}

//Returns the rectangular region of the view into which the specified frame should be drawn.
- (NSRect) viewportForFrame: (BXVideoFrame *)frame
{
    if (self.managesAspectRatio)
	{
		NSSize frameSize = frame.scaledSize;
		NSRect frameRect = NSMakeRect(0.0f, 0.0f, frameSize.width, frameSize.height);
		
        NSRect maxViewportRect = self.bounds;
        //If we have a maximum viewport size, fit the frame within that.
        if (!NSEqualSizes(self.maxViewportSize, NSZeroSize) && !sizeFitsWithinSize(maxViewportRect.size, self.maxViewportSize))
        {
            maxViewportRect = resizeRectFromPoint(maxViewportRect, self.maxViewportSize, NSMakePoint(0.5f, 0.5f));
            
            //TODO: snap the viewport rect to an even multiple of the base resolution of the frame if it's close enough,
            //using the same algorithm as we do in BXDOSWindowController when resizing the window.
        }
		return fitInRect(frameRect, maxViewportRect, NSMakePoint(0.5f, 0.5f));
	}
	else
    {
        return self.bounds;
    }
}

- (void) setManagesAspectRatio: (BOOL)enabled
{
    if (self.managesAspectRatio != enabled)
    {
        _managesAspectRatio = enabled;
        
        //Update our viewport immediately to compensate for the change
        self.viewportRect = [self viewportForFrame: self.currentFrame];
    }
}

- (void) setViewportRect: (NSRect)newRect
{
    if (!NSEqualRects(newRect, _viewportRect))
    {
        _viewportRect = newRect;
        
        [self _applyViewportToRenderer: self.renderer];
        
        if (_displayLink)
            self.needsCVLinkDisplay = YES;
        else
            self.needsDisplay = YES;
    }
}

- (void) _applyViewportToRenderer: (BXBasicRenderer *)renderer
{
    NSRect backingRect = self.viewportRect;
    
    //Compensate for hi-res contexts
    if ([self respondsToSelector: @selector(convertRectToBacking:)])
        backingRect = [self convertRectToBacking: backingRect];
    
    CGLContextObj cgl_ctx = self.openGLContext.CGLContextObj;
    
    CGLLockContext(cgl_ctx);
        renderer.viewport = NSRectToCGRect(backingRect);
    CGLUnlockContext(cgl_ctx);
}

- (void) setMaxViewportSize: (NSSize)maxViewportSize
{
    if (!NSEqualSizes(maxViewportSize, self.maxViewportSize))
    {
        _maxViewportSize = maxViewportSize;
        
        //Update our viewport immediately to compensate for the change
        self.viewportRect = [self viewportForFrame: self.currentFrame];
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
            
            //Sync up the new renderer with our current state
            if (NSIsEmptyRect(self.viewportRect))
            {
                self.viewportRect = (self.currentFrame) ? [self viewportForFrame: self.currentFrame] : self.bounds;
            }
            [self _applyViewportToRenderer: self.renderer];
        
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
	
    
    //Create a new renderer for this context, and set it up appropriately
    self.renderer = [self rendererForStyle: self.renderingStyle
                                 inContext: cgl_ctx];
    
    //Load in our ripple effects
    NSError *rippleLoadingError = nil;
    self.rippleEffect2D = [BXRippleShader shaderNamed: @"ripple2D"
                                       inSubdirectory: @"Shaders"
                                            inContext: cgl_ctx
                                                error: &rippleLoadingError];
    
    if (rippleLoadingError)
        NSLog(@"%@", rippleLoadingError);
    
    self.rippleEffectRectangle = [BXRippleShader shaderNamed: @"rippleRect"
                                              inSubdirectory: @"Shaders"
                                                   inContext: cgl_ctx
                                                       error: &rippleLoadingError];
    
    if (rippleLoadingError)
        NSLog(@"%@", rippleLoadingError);
    
    //Set up the CV display link if desired
    BOOL useCVDisplayLink = [[NSUserDefaults standardUserDefaults] boolForKey: @"useCVDisplayLink"];
    if (useCVDisplayLink)
    {
        //Create a display link capable of being used with all active displays
        CVReturn status = CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
        
        if (status == kCVReturnSuccess)
        {
            //Set the renderer output callback function
            CVDisplayLinkSetOutputCallback(_displayLink, &BXDisplayLinkCallback, self);
            
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
    
    [self.rippleEffect2D deleteShaderProgram];
    self.rippleEffect2D = nil;
    
    [self.rippleEffectRectangle deleteShaderProgram];
    self.rippleEffectRectangle = nil;
    
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
    self.viewportRect = [self viewportForFrame: self.currentFrame];
}

- (void) windowDidChangeBackingProperties: (NSNotification *)notification
{
    [self _applyViewportToRenderer: self.renderer];
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

- (void) showRippleAtPoint: (NSPoint)point reverse: (BOOL)reverse
{
    NSPoint relativeOrigin = pointRelativeToRect(point, self.viewportRect);
    self.rippleOrigin = CGPointMake(relativeOrigin.x, 1.0f - relativeOrigin.y);
    self.rippleReversed = reverse;
    self.rippleProgress = 0.0f;
    [self.animator setRippleProgress: 1.0f];
}

- (void) setRippleProgress: (CGFloat)progress
{
    _rippleProgress = progress;
    
    if (_displayLink)
        self.needsCVLinkDisplay = YES;
    else
        self.needsDisplay = YES;
}

- (void) renderer: (BXBasicRenderer *)renderer willRenderTextureToDestinationContext: (BXTexture2D *)texture
{
    if (_rippleProgress > 0.0f && _rippleProgress < 1.0f)
    {
        //We need to switch which shader we use based on texture type: one shader version is written
        //for 2D textures, the other for rectangle textures.
        BXRippleShader *effect = (texture.type == GL_TEXTURE_RECTANGLE_ARB) ? self.rippleEffectRectangle : self.rippleEffect2D;
        
        if (effect)
        {
            CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
            if (self.rippleReversed) currentTime = -currentTime;
            
            //Translate our 0->1 progress to 0->1->0, where the ripples are strongest midway through the animation.
            CGFloat baseHeight = 0.5f;
            CGFloat mirroredProgress = ABS(_rippleProgress - 0.5f) * 2.0f;
            GLfloat height = baseHeight - (mirroredProgress * baseHeight);
            
            CGLContextObj cgl_ctx = effect.context;
            glUseProgramObjectARB(effect.shaderProgram);
            
            effect.textureIndex = 0;
            effect.textureSize = texture.textureSize;
            effect.frameTime = currentTime;
            effect.rippleHeight = height;
            effect.rippleOrigin = self.rippleOrigin;
        }
    }
}

- (void) renderer: (BXBasicRenderer *)renderer didRenderTextureToDestinationContext: (BXTexture2D *)texture
{
    CGLContextObj cgl_ctx = self.openGLContext.CGLContextObj;
    
    glUseProgramObjectARB(0);
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
	
	BXGLRenderingView *view = (BXGLRenderingView *)displayLinkContext;
    
    if (view.needsCVLinkDisplay && !view.inViewAnimation)
        [view display];
    
	[pool drain];
	return kCVReturnSuccess;
}

@end



@implementation BXGLRenderingView (BXImageCapture)

//Replacement implementation for base method on NSView: initializes an NSBitmapImageRep
//that can cope with our renderer's OpenGL output.
- (NSBitmapImageRep *) bitmapImageRepForCachingDisplayInRect: (NSRect)theRect
{
    //Account for high-resolution displays when creating the bitmap context.
    if ([self respondsToSelector: @selector(convertRectToBacking:)])
        theRect = [self convertRectToBacking: theRect];
    
    theRect = NSIntegralRect(theRect);
    
    //Pad the row out to the appropriate length
    NSInteger bytesPerRow = (NSInteger)((theRect.size.width * 4) + 3) & ~3;
    
    //IMPLEMENTATION NOTE: we use the device RGB rather than a calibrated or generic RGB,
    //so that the bitmap matches what the user is seeing.
    NSBitmapImageRep *rep	= [[[NSBitmapImageRep alloc]
                                initWithBitmapDataPlanes: nil
                                pixelsWide: theRect.size.width
                                pixelsHigh: theRect.size.height
                                bitsPerSample: 8
                                samplesPerPixel: 3
                                hasAlpha: NO
                                isPlanar: NO
                                colorSpaceName: NSDeviceRGBColorSpace
                                bytesPerRow: bytesPerRow
                                bitsPerPixel: 32] autorelease];
    
    return rep;
}

//Replacement implementation for base method on NSView: pours contents of OpenGL front buffer
//into specified NSBitmapImageRep (which must have been created by bitmapImageRepForCachingDisplayInRect:)
- (void) cacheDisplayInRect: (NSRect)theRect 
           toBitmapImageRep: (NSBitmapImageRep *)rep
{
    //Account for high-resolution displays when filling the bitmap context.
    if ([self respondsToSelector: @selector(convertRectToBacking:)])
        theRect = [self convertRectToBacking: theRect];
    
	//Ensure the rectangle isn't fractional
	theRect = NSIntegralRect(theRect);
    
    //If we don't have a renderer yet, we won't be able to provide any image data.
    //This will be the case if the view has never been rendered (e.g. it's offscreen.)
    //In this case, just fill the rep with black.
    if (!self.renderer)
    {
        NSUInteger numBytes = rep.bytesPerPlane * rep.numberOfPlanes;
        bzero(rep.bitmapData, numBytes);
        return;
    }
    
	//Now, do the OpenGL calls to rip out the image data
    CGLContextObj cgl_ctx = self.openGLContext.CGLContextObj;
    
    CGLLockContext(cgl_ctx);
        GLenum channelOrder, byteType;
    
    //Alternate implementation that renders to a renderbuffer instead of grabbing pixel
    //data straight from the front buffer. This is currently disabled as it offered no
    //benefits and would frequently result in screenshots of incomplete frames.
    /*
        GLuint framebuffer, renderbuffer;
        
        glGenFramebuffersEXT(1, &framebuffer);
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, framebuffer);
    
        glGenRenderbuffersEXT(1, &renderbuffer);
        glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, renderbuffer);
    
        glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_RGBA8, theRect.size.width, theRect.size.height);
        glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT,
                                     GL_COLOR_ATTACHMENT0_EXT,
                                     GL_RENDERBUFFER_EXT,
                                     renderbuffer);
    
        GLenum status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
        if (status != GL_FRAMEBUFFER_COMPLETE_EXT)
        {
            NSAssert1(status == GL_FRAMEBUFFER_COMPLETE_EXT,
                      @"Framebuffer creation failed: %@",
                      errorForGLFramebufferExtensionStatus(status));
        }
    
        glClearColor(0, 0, 0, 0);
        glClear(GL_COLOR);
        [self.renderer render];
        
        //Restore previous framebuffer
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
     
        //Read the pixels out of the renderbuffer
        glReadBuffer(GL_COLOR_ATTACHMENT0_EXT);
    */
    
        //Read out the contents of the front buffer 
        glReadBuffer(GL_FRONT);
    
        //Back up current settings
        glPushClientAttrib(GL_CLIENT_PIXEL_STORE_BIT);
        
        glPixelStorei(GL_PACK_ALIGNMENT,	4);
        glPixelStorei(GL_PACK_ROW_LENGTH,	0);
        glPixelStorei(GL_PACK_SKIP_ROWS,	0);
        glPixelStorei(GL_PACK_SKIP_PIXELS,	0);
        
        //Reverse the retrieved byte order depending on the endianness of the processor.
#ifdef BIG_ENDIAN
        byteType = GL_UNSIGNED_INT_8_8_8_8_REV;
#else
        byteType = GL_UNSIGNED_INT_8_8_8_8;
#endif
        channelOrder	= GL_RGBA;
        
        //Pour the data into the NSBitmapImageRep
        glReadPixels(theRect.origin.x,
                     theRect.origin.y,
                     
                     theRect.size.width,
                     theRect.size.height,
                     
                     channelOrder,
                     byteType,
                     rep.bitmapData
                     );
        
        //Restore the old settings
        glPopClientAttrib();
    
    /*
        //Delete the renderbuffer and framebuffer
        glDeleteRenderbuffersEXT(1, &renderbuffer);
        glDeleteFramebuffersEXT(1, &framebuffer);
     */
    CGLUnlockContext(cgl_ctx);
    
	//Finally, flip the captured image since GL reads it in the reverse order from what we need
	[rep flip];
}
@end


@implementation NSBitmapImageRep (BXFlipper)
//Tidy bit of C 'adapted' from http://developer.apple.com/samplecode/OpenGLScreenSnapshot/listing5.html
- (void) flip
{
	NSInteger top, bottom, height, rowBytes;
	void * data;
	void * buffer;
	void * topP;
	void * bottomP;
	
	height		= self.pixelsHigh;
	rowBytes	= self.bytesPerRow;
	data		= self.bitmapData;
	
	top			= 0;
	bottom		= height - 1;
	buffer		= malloc(rowBytes);
	NSAssert(buffer != nil, @"malloc failure");
	
	while (top < bottom)
	{
		topP	= (void *)((top * rowBytes)		+ (intptr_t)data);
		bottomP	= (void *)((bottom * rowBytes)	+ (intptr_t)data);
		
		/*
		 * Save and swap scanlines.
		 *
		 * This code does a simple in-place exchange with a temp buffer.
		 * If you need to reformat the pixels, replace the first two bcopy()
		 * calls with your own custom pixel reformatter.
		 */
		bcopy(topP,		buffer,		rowBytes);
		bcopy(bottomP,	topP,		rowBytes);
		bcopy(buffer,	bottomP,	rowBytes);
		
		++top;
		--bottom;
	}
	free(buffer);
}
@end
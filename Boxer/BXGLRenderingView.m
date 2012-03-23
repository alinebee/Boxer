/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXGLRenderingView.h"
#import "BXRenderer.h"
#import "BXDOSWindowController.h" //For notifications

#pragma mark -
#pragma mark Private interface declaration

@interface BXGLRenderingView ()

//Whether we should redraw in the next display-link cycle.
//Set to YES upon receiving a new frame, then back to NO after rendering it.
@property (assign) BOOL needsCVLinkDisplay;

//The display link callback that renders the next frame in sync with the screen refresh.
CVReturn BXDisplayLinkCallback(CVDisplayLinkRef displayLink,
                               const CVTimeStamp* now,  
                               const CVTimeStamp* outputTime,
                               CVOptionFlags flagsIn,
                               CVOptionFlags* flagsOut,
                               void* displayLinkContext);

@end

@interface NSBitmapImageRep (BXFlipper)

//Flip the pixels of the bitmap from top to bottom. Used when grabbing screenshots from the GL view.
- (void) flip;

@end



@implementation BXGLRenderingView
@synthesize renderer;
@synthesize needsCVLinkDisplay;

- (id) initWithCoder: (NSCoder *)aDecoder
{
    if ((self = [super initWithCoder: aDecoder]))
    {
        [self setRenderer: [[[BXRenderer alloc] init] autorelease]];
    }
    return self;
}

- (void) dealloc
{
	[self setRenderer: nil], [renderer release];
	[super dealloc];
}


//Pass on various events that would otherwise be eaten by the default NSView implementation
- (void) rightMouseDown: (NSEvent *)theEvent
{
	[[self nextResponder] rightMouseDown: theEvent];
}

#pragma mark -
#pragma mark Rendering methods

- (void) setManagesAspectRatio: (BOOL)manage
{
	[[self renderer] setMaintainsAspectRatio: manage];
}

- (BOOL) managesAspectRatio
{
	return [[self renderer] maintainsAspectRatio];	
}

- (void) updateWithFrame: (BXFrameBuffer *)frame
{
    //If we're using a CV Link, don't tell Cocoa that we need redrawing:
    //Instead, flag that we need to render and flush in the display link.
    //This prevents Cocoa from drawing the dirty view at the 'wrong' time.
    [[self renderer] updateWithFrame: frame inGLContext: [[self openGLContext] CGLContextObj]];
    
    if (displayLink)
        [self setNeedsCVLinkDisplay: YES];
    else
        [self setNeedsDisplay: YES];
}

- (BXFrameBuffer *) currentFrame
{
    return [[self renderer] currentFrame];
}

- (NSRect) viewportRect
{
	return NSRectFromCGRect([renderer viewportForFrame: [self currentFrame]]);
}

- (NSSize) maxFrameSize
{
	return NSSizeFromCGSize([renderer maxFrameSize]);
}


- (void) prepareOpenGL
{
	CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
	
	//Enable multithreaded OpenGL execution (if available)
	CGLEnable(cgl_ctx, kCGLCEMPEngine);
    
    //Synchronize buffer swaps with vertical refresh rate
    GLint useVSync = [[NSUserDefaults standardUserDefaults] boolForKey: @"useVSync"];
    [[self openGLContext] setValues: &useVSync forParameter: NSOpenGLCPSwapInterval];
	
    //Let the renderer do its own preparations
	[[self renderer] prepareForGLContext: cgl_ctx];
    
    
    //Set up the CV display link if desired
    BOOL useCVDisplayLink = [[NSUserDefaults standardUserDefaults] boolForKey: @"useCVDisplayLink"];
    if (useCVDisplayLink)
    {
        //Create a display link capable of being used with all active displays
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
        
        //Set the renderer output callback function
        CVDisplayLinkSetOutputCallback(displayLink, &BXDisplayLinkCallback, self);
        
        // Set the display link for the current renderer
        CGLPixelFormatObj cglPixelFormat = [[self pixelFormat] CGLPixelFormatObj];
        CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(displayLink, cgl_ctx, cglPixelFormat);
        
        //Activate the display link
        CVDisplayLinkStart(displayLink);
    }
}

- (void) clearGLContext
{
	if (displayLink)
	{
		CVDisplayLinkRelease(displayLink);
		displayLink = NULL;
	}
    
	[[self renderer] tearDownGLContext: [[self openGLContext] CGLContextObj]];	
	[super clearGLContext];
}

- (void) reshape
{
    [super reshape];
	[[self renderer] setCanvas: NSRectToCGRect([self bounds])];
}

- (void) drawRect: (NSRect)dirtyRect
{
    [self setNeedsCVLinkDisplay: NO];
    
    CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
    if ([[self renderer] canRenderToGLContext: cgl_ctx])
	{
		CGLLockContext(cgl_ctx);
            [[self renderer] renderToGLContext: cgl_ctx];
            [[self renderer] flushToGLContext: cgl_ctx];
        CGLUnlockContext(cgl_ctx);
	}
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
    
    if ([view needsCVLinkDisplay])
        [view display];
    
	[pool drain];
	return kCVReturnSuccess;
}


//Silly notifications to let the window controller know when a live resize operation is starting/stopping,
//so that it can clean up afterwards.
- (void) viewWillStartLiveResize
{	
	[super viewWillStartLiveResize];
	[[NSNotificationCenter defaultCenter] postNotificationName: BXViewWillLiveResizeNotification object: self];
}

- (void) viewDidEndLiveResize
{
	[super viewDidEndLiveResize];
	[[NSNotificationCenter defaultCenter] postNotificationName: BXViewDidLiveResizeNotification object: self];
}
@end



@implementation BXGLRenderingView (BXImageCapture)

//Replacement implementation for base method on NSView: initializes an NSBitmapImageRep
//that can cope with our renderer's OpenGL output.
- (NSBitmapImageRep *) bitmapImageRepForCachingDisplayInRect: (NSRect)theRect
{
    theRect = NSIntegralRect(theRect);
    
    //Pad the row out the appropriate length
    NSInteger bytesPerRow	= (NSInteger)((theRect.size.width * 4) + 3) & ~3;
    
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
	GLenum channelOrder, byteType;
    
	//Ensure the rectangle isn't fractional
	theRect = NSIntegralRect(theRect);
	
    
	//Now, do the OpenGL calls to rip off the image data
    CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
    
    CGLLockContext(cgl_ctx);
        CGLSetCurrentContext(cgl_ctx);
        
        //Grab what's in the front buffer
        glReadBuffer(GL_FRONT);
        //Back up current settings
        glPushClientAttrib(GL_CLIENT_PIXEL_STORE_BIT);
        
        glPixelStorei(GL_PACK_ALIGNMENT,	4);
        glPixelStorei(GL_PACK_ROW_LENGTH,	0);
        glPixelStorei(GL_PACK_SKIP_ROWS,	0);
        glPixelStorei(GL_PACK_SKIP_PIXELS,	0);
        
        //Reverse the retrieved byte order depending on the endianness of the processor.
        byteType		= (NSHostByteOrder() == NS_LittleEndian) ? GL_UNSIGNED_INT_8_8_8_8_REV : GL_UNSIGNED_INT_8_8_8_8;
        channelOrder	= GL_RGBA;
        
        //Pour the data into the NSBitmapImageRep
        glReadPixels(theRect.origin.x,
                     theRect.origin.y,
                     
                     theRect.size.width,
                     theRect.size.height,
                     
                     channelOrder,
                     byteType,
                     [rep bitmapData]
                     );
        
        //Restore the old settings
        glPopClientAttrib();
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
	
	height		= [self pixelsHigh];
	rowBytes	= [self bytesPerRow];
	data		= [self bitmapData];
	
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
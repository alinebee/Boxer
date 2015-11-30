/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXGLRenderingView+BXImageCapture.h"
#import <OpenGL/CGLMacro.h>

@interface NSBitmapImageRep (BXFlipper)

//Flip the pixels of the bitmap from top to bottom. Used when grabbing screenshots from the GL view.
- (void) flip;

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

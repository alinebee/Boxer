/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "NSOpenGLView+BXImageCapture.h"

@implementation NSOpenGLView (BXImageCapture)

//Replacement implementation for base method on NSView: initializes an NSBitmapImageRep to cope with OpenGL output
- (NSBitmapImageRep *) bitmapImageRepForCachingDisplayInRect: (NSRect)theRect
{
	theRect = NSIntegralRect(theRect);
	//Pad the row out the appropriate length
	NSInteger bytesPerRow	= (NSInteger)((theRect.size.width * 4) + 3) & ~3;
	NSBitmapImageRep *rep	= [[[NSBitmapImageRep alloc]
							  initWithBitmapDataPlanes: nil
							  pixelsWide: theRect.size.width
							  pixelsHigh: theRect.size.height
							  bitsPerSample: 8
							  samplesPerPixel: 3
							  hasAlpha: NO
							  isPlanar: NO
							  colorSpaceName: NSCalibratedRGBColorSpace
							  bytesPerRow: bytesPerRow
							  bitsPerPixel: 32] autorelease];
	return rep;
}

//Replacement implementation for base method on NSView: pours contents of OpenGL front buffer into specified NSBitmapImageRep
- (void) cacheDisplayInRect:	(NSRect)theRect 
			toBitmapImageRep:	(NSBitmapImageRep *)rep
{
	GLenum channelOrder, byteType;

	//Ensure the rectangle isn't fractional
	theRect = NSIntegralRect(theRect);
	
	//Now, do the OpenGL calls to rip off the image data
	//--------------------------------------------------
	[[self openGLContext] makeCurrentContext];
	
	//Grab what's in the front buffer
	glReadBuffer(GL_FRONT);
	//Back up current settings
	glPushClientAttrib(GL_CLIENT_PIXEL_STORE_BIT);
    
	glPixelStorei(GL_PACK_ALIGNMENT,	4);
	glPixelStorei(GL_PACK_ROW_LENGTH,	0);
	glPixelStorei(GL_PACK_SKIP_ROWS,	0);
	glPixelStorei(GL_PACK_SKIP_PIXELS,	0);

	//We need to reverse the byte order depending on the endianness of the processor
	//We could do this check with compiler directives instead but I think it's better practice to check it at runtime
	byteType		= (NSHostByteOrder() == NS_LittleEndian) ? GL_UNSIGNED_INT_8_8_8_8_REV : GL_UNSIGNED_INT_8_8_8_8;
	channelOrder	= GL_RGBA;
	
	//Pour the data into the NSBitmapImageRep
	glReadPixels(	theRect.origin.x,
					theRect.origin.y,
					
					theRect.size.width,
					theRect.size.height,
					
					channelOrder,
					byteType,
					[rep bitmapData]
				);
	
	//Restore the old settings
    glPopClientAttrib();

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
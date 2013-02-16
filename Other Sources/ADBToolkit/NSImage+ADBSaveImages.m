/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSImage+ADBSaveImages.h"


@implementation NSImage (ADBSaveImages)

- (BOOL) saveToURL: (NSURL *)URL
          withType: (NSBitmapImageFileType)type
        properties: (NSDictionary *)properties
             error: (out NSError **)outError
{
    NSRect targetRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    NSDictionary *hints = @{ NSImageHintInterpolation: @(NSImageInterpolationHigh) };
	NSBitmapImageRep *rep = (NSBitmapImageRep *)[self bestRepresentationForRect: targetRect
                                                                        context: nil
                                                                          hints: hints];
	
	//If the image representation is not actually an NSBitmapImageRep,
	//(e.g. it's vector data) then create one from the TIFF data.
	//FIXME: it may be faster just to render the image into a new bitmap context instead.
	if (![rep isKindOfClass: [NSBitmapImageRep class]])
	{
		rep = [NSBitmapImageRep imageRepWithData: self.TIFFRepresentation];
	}
	
	NSData *data = [rep representationUsingType: type properties: properties];
	return [data writeToURL: URL options: NSAtomicWrite error: outError];
}

@end

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
#import "ADBGeometry.h"

/// The maximum number of representations that @c CGImageDestinationCreateWithURL
/// can prepare to store in an @c icns file before it chokes. 10 as of OS X 10.9.
#define kCGMaxICNSRepresentations 10


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

- (BOOL) saveAsIconToURL: (NSURL *)URL
                   error: (out NSError **)outError
{
    if ([URL checkResourceIsReachableAndReturnError: NULL])
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                            code: NSFileWriteFileExistsError
                                        userInfo: @{ NSURLErrorKey: URL }];
        }
        return NO;
    }
    
    NSArray *representationsToSave = self.representations;
    
    NSUInteger numImages = representationsToSave.count;
    if (numImages > kCGMaxICNSRepresentations)
    {
        //IMPLEMENTATION NOTE: CGImageDestinationCreateWithURL can only handle a maximum of 10 representations.
        //But in OS X 10.9, icons served up by NSWorkspace may have much more than this - 15 or more -
        //because they now include synthesized representations for retina display, spotlight versions etc.
        
        //So, we need to cull the representations down to 10 or less. We do this by prioritising the standard
        //versions: 16, 32, 128, 256, 512. Any icon sizes outside of these are discarded.
        
        NSMutableArray *filteredRepresentations = [NSMutableArray arrayWithCapacity: 10];
        for (NSImageRep *rep in representationsToSave)
        {
            //Note that the size is in logical units, not device pixels: retina 16x16@2x and non-retina 16x16
            //will both report 16x16.
            NSSize size = rep.size;
            if (size.width == size.height &&
                size.width >= 16 && size.width <= 512 &&
                isPowerOfTwo((NSUInteger)size.width))
            {
                [filteredRepresentations addObject: rep];
            }
        }
        
        //If we still have too many representations after culling, then we have a pretty weird icon file:
        //An icon with retina and non-retina versions of 16, 32, 128, 256 and 512 should have a maximum of 10.
        //In any case, just discard the extra ones.
        if (filteredRepresentations.count <= kCGMaxICNSRepresentations)
            representationsToSave = filteredRepresentations;
        else
            representationsToSave = [filteredRepresentations subarrayWithRange: NSMakeRange(0, kCGMaxICNSRepresentations)];
        
        numImages = representationsToSave.count;
    }
    
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)URL,
                                                                        kUTTypeAppleICNS,
                                                                        numImages,
                                                                        NULL);
    
    if (destination != NULL)
    {
        for (NSImageRep *rep in representationsToSave)
        {
            CGImageRef image = [rep CGImageForProposedRect: NULL context: nil hints: nil];
            NSDictionary* properties = @{(NSString *)kCGImagePropertyDPIWidth: @(rep.size.width),
                                         (NSString *)kCGImagePropertyDPIHeight: @(rep.size.height),
                                         (NSString *)kCGImagePropertyPixelWidth: @(rep.pixelsWide),
                                         (NSString *)kCGImagePropertyPixelHeight: @(rep.pixelsHigh),
                                         };
            
            CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)properties);
        }
        
        BOOL finalized = CGImageDestinationFinalize(destination);
        CFRelease(destination);
        
        if (finalized)
        {
            return YES;
        }
        else
        {
            //TODO: try to get more specific error information out of Core Graphics
            if (outError)
            {
                *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                                code: NSFileWriteUnknownError
                                            userInfo: @{ NSURLErrorKey: URL }];
            }
            return NO;
        }
    }
    else
    {
        //TODO: try to get more specific error information out of Core Graphics
        if (outError)
        {
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                            code: NSFileWriteUnknownError
                                        userInfo: @{ NSURLErrorKey: URL }];
        }
        
        return NO;
    }
}

@end

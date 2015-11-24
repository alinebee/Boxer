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

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSImage (ADBImageEffects)

/// Returns the relative anchor point (from {0.0, 0.0} to {1.0, 1.0})
/// that's equivalent to the specified image alignment constant.
+ (NSPoint) anchorForImageAlignment: (NSImageAlignment)alignment;

/// Returns a rect suitable for drawing this image into,
/// given the specified alignment and scaling mode. Intended
/// for NSCell/NSControl subclasses.
- (NSRect) imageRectAlignedInRect: (NSRect)outerRect
                        alignment: (NSImageAlignment)alignment
                          scaling: (NSImageScaling)scaling;

/// Returns a new version of the image filled with the specified color at the
/// specified size, using the current image's alpha channel. The resulting image
/// will be a bitmap.<br>
/// Pass \c NSZeroSize as the size to use the size of the original image.
/// Intended for use with black-and-transparent template images,
/// although it will work with any image.
- (NSImage *) imageFilledWithColor: (NSColor *)color atSize: (NSSize)targetSize;

/// Returns a new version of the image masked by the specified image, at the
/// specified size. The resulting image will be a bitmap.
- (NSImage *) imageMaskedByImage: (NSImage *)mask atSize: (NSSize)targetSize;

/// Draw a template image filled with the specified gradient and rendered
/// with the specified inner and drop shadows.
- (void) drawInRect: (NSRect)drawRect
       withGradient: (nullable NSGradient *)fillGradient
         dropShadow: (nullable NSShadow *)dropShadow
        innerShadow: (nullable NSShadow *)innerShadow
     respectFlipped: (BOOL)respectContextIsFlipped;

@end

NS_ASSUME_NONNULL_END

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


//The ADBShadowExtensions category adds helper methods to make NSShadows easier to work with.

#import <Cocoa/Cocoa.h>

@interface NSShadow (ADBShadowExtensions)

/// Returns an autoreleased shadow initialized with the default settings
/// (0 radius, 0 offset, 33% opaque black).
+ (instancetype) shadow;

/// Returns an autoreleased shadow initialized with the specified radius and offset,
/// and the default color (33% opaque black).
+ (instancetype) shadowWithBlurRadius: (CGFloat)blurRadius
                               offset: (NSSize)offset;

/// Returns an autoreleased shadow initialized with the specified radius, offset and colour.
+ (instancetype) shadowWithBlurRadius: (CGFloat)blurRadius
                               offset: (NSSize)offset
                                color: (NSColor *)color;

/// Returns the specified rect, inset to accomodate the shadow's offset and blur radius.
/// Intended for draw operations where one has a fixed draw region (the original rect)
/// and needs to scale an object so that its shadow will fit inside that region without clipping.
- (NSRect) insetRectForShadow: (NSRect)origRect flipped: (BOOL)flipped;

/// Returns the specified rect, expanded to accomodate the shadow's offset and blur radius.
/// Intended for draw operations where one has a target size and position to draw an object at,
/// and needs the total region that will be drawn including the shadow.
- (NSRect) expandedRectForShadow: (NSRect)origRect flipped: (BOOL)flipped;

/// Returns the area that will be filled if the specified rect cast this shadow.
/// If flipped is YES, the offset rect will be calculated as if it will be used
/// in a flipped coordinate system.
- (NSRect) shadowedRect: (NSRect)origRect flipped: (BOOL)flipped;

/// The inverse of the above: returns the rect that would be needed to produce
/// a shadow in the specified area.
- (NSRect) rectToCastShadow: (NSRect)origRect flipped: (BOOL)flipped;

/// The rectangle needed to draw an inner shadow in the specified area.
- (NSRect) rectToCastInnerShadow: (NSRect)origRect flipped: (BOOL)flipped;

@end

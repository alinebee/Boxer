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


#import "NSView+ADBDrawingHelpers.h"
#import "ADBGeometry.h"

@implementation NSView (ADBDrawingHelpers)

- (NSPoint) offsetFromWindowOrigin
{
	NSPoint offset = NSZeroPoint;
	NSView *offsetParent = self;
	do
	{
		offset = pointWithDelta(offset, offsetParent.frame.origin);
	}
	while ((offsetParent = offsetParent.superview));
	
	return offset;
}

- (BOOL) windowIsActive
{
    return (self.window.isMainWindow || !self.window.canBecomeMainWindow);
}

- (NSImage *) imageWithContentsOfRect: (NSRect)rect
{
    NSBitmapImageRep *rep = [self bitmapImageRepForCachingDisplayInRect: rect];
    [self cacheDisplayInRect: rect toBitmapImageRep: rep];
    
    NSImage *capture = [[NSImage alloc] init];
    [capture addRepresentation: rep];
    
    return [capture autorelease];
}
@end
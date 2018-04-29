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


#import "NSWindow+ADBWindowEffects.h"

#pragma mark -
#pragma mark Private method declarations

@interface NSWindow (ADBWindowEffectsPrivate)
//Completes the ordering out from a fadeOutWithDuration: call.
- (void) _orderOutAfterFade;
@end


@implementation NSWindow (ADBWindowEffects)

- (void) fadeInWithDuration: (NSTimeInterval)duration
{
    //Don't bother fading in if we're already completely visible; just cancel any pending order-out.
	if (!self.isVisible || self.alphaValue < 1.0f)
    {
        //Hide ourselves completely if we weren't visible, before fading in.
        if (!self.isVisible) self.alphaValue = 0.0f;
        
        [self orderFront: self];
        
        [NSAnimationContext beginGrouping];
            [NSAnimationContext currentContext].duration = duration;
            [self.animator setAlphaValue: 1.0f];
        [NSAnimationContext endGrouping];
	}
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_orderOutAfterFade) object: nil];
}

- (void) fadeOutWithDuration: (NSTimeInterval)duration
{
	if (!self.isVisible) return;
	
	[NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration: duration];
    [self.animator setAlphaValue: 0.0f];
	[NSAnimationContext endGrouping];
	[self performSelector: @selector(_orderOutAfterFade) withObject: nil afterDelay: duration];
}

- (void) _orderOutAfterFade
{
	[self willChangeValueForKey: @"visible"];
	[self orderOut: self];
	[self didChangeValueForKey: @"visible"];
	
    //Restore our alpha value after we've finished ordering out.
	self.alphaValue = 1.0f;
}

@end

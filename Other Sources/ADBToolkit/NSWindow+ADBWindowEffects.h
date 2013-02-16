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


//The ADBWindowEffects category adds several Core Graphics-powered transition and filter effects
//to use on windows.

#import <Cocoa/Cocoa.h>

@interface NSWindow (ADBWindowEffects)

//Order the window in/out with a simple non-blocking fade effect.
- (void) fadeInWithDuration: (NSTimeInterval)duration;
- (void) fadeOutWithDuration: (NSTimeInterval)duration;

@end


//The following methods use private Core Graphics APIs that will likely fall foul
//of App Store private-API restrictions.
#ifdef USE_PRIVATE_APIS

#import "CGSPrivate.h"

@interface NSWindow (ADBPrivateAPIWindowEffects)

//Applies a gaussian blur filter behind the window background.
//Only useful for HUD-style translucent windows.
- (void) applyGaussianBlurWithRadius: (CGFloat)radius;

//Hide the window by using the specified transition.
- (void) hideWithTransition: (CGSTransitionType)type
				  direction: (CGSTransitionOption)direction
				   duration: (NSTimeInterval)duration
			   blockingMode: (NSAnimationBlockingMode)blockingMode;

//Reveal the window by using the specified transition.
- (void) revealWithTransition: (CGSTransitionType)type
					direction: (CGSTransitionOption)direction
					 duration: (NSTimeInterval)duration
				 blockingMode: (NSAnimationBlockingMode)blockingMode;

#pragma mark -
#pragma mark Low-level methods

//Adds a filter with the specified name and options to the window. The backgroundOnly flag
//determines whether the filter applies directly to the window's contents, or to what lies
//behind the window.
- (void) addCGSFilterWithName: (NSString *)filterName
				  withOptions: (NSDictionary *)filterOptions
			   backgroundOnly: (BOOL)backgroundOnly;

//Applies the specified Core Graphics transition to the window.
- (void) applyCGSTransition: (CGSTransitionType)type
				  direction: (CGSTransitionOption)direction
				   duration: (NSTimeInterval)duration
			   blockingMode: (NSAnimationBlockingMode)blockingMode;

@end

#endif
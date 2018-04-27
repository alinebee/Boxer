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


#import <Foundation/Foundation.h>

/// @c ADBPerformExtensions provides helper methods for performing selectors with arbitrary arguments.
@interface NSObject (ADBPerformExtensions)

- (void) performSelector: (SEL)selector
              withValues: (void *)arg1, ...;

- (void) performSelector: (SEL)aSelector
              afterDelay: (NSTimeInterval)delay
              withValues: (void *)arg1, ...;

- (void) performSelector: (SEL)selector
                onThread: (NSThread *)thread
           waitUntilDone: (BOOL)wait
              withValues: (void *)arg1, ...;

- (void) performSelectorOnMainThread: (SEL)selector
                       waitUntilDone: (BOOL)wait
                          withValues: (void *)arg1, ...;

- (void) performSelectorInBackground: (SEL)aSelector
                          withValues: (void *)arg1, ...;

@end


@interface NSInvocation (ADBInvocationExtensions)

//Helper methods to make defining invocations less painful.
+ (NSInvocation *) invocationWithTarget: (id)target
                               selector: (SEL)selector;

+ (NSInvocation *) invocationWithTarget: (id)target
                               selector: (SEL)selector
                              arguments: (void *)arg1, ...;

/// For use with downstream variadic methods like performSelector:withValues:...).
/// args is expected to be already started with va_start(): It is the responsibility
/// of the calling context to call va_end() after this method returns.
+ (NSInvocation *) invocationWithTarget: (id)target
                               selector: (SEL)selector
                          firstArgument: (void *)arg1
                     remainingArguments: (va_list)args;
@end

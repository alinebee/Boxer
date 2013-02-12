/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Foundation/Foundation.h>

//BXPerformExtensions provides helper methods for performing selectors with arbitrary arguments.

@interface NSObject (BXPerformExtensions)

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


@interface NSInvocation (BXInvocationExtensions)

//Helper methods to make defining invocations less painful.
+ (NSInvocation *) invocationWithTarget: (id)target
                               selector: (SEL)selector;

+ (NSInvocation *) invocationWithTarget: (id)target
                               selector: (SEL)selector
                              arguments: (void *)arg1, ...;

//For use with downstream variadic methods like performSelector:withValues:...).
//args is expected to be already started with va_start(): It is the responsibility
//of the calling context to call va_end() after this method returns.
+ (NSInvocation *) invocationWithTarget: (id)target
                               selector: (SEL)selector
                          firstArgument: (void *)arg1
                     remainingArguments: (va_list)args;
@end

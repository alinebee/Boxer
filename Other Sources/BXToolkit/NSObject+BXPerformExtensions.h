//
//  NSObject+BXPerformExtensions.h
//  Boxer
//
//  Created by Alun Bestor on 27/02/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

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

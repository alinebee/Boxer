//
//  NSObject+BXPerformExtensions.m
//  Boxer
//
//  Created by Alun Bestor on 27/02/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import "NSObject+BXPerformExtensions.h"


@implementation NSObject (BXPerformExtensions)

//Convenience method for preparing an invocation for the perform methods below.
- (NSInvocation *) _invocationWithSelector: (SEL)selector
                             firstArgument: (void *)arg1
                        remainingArguments: (va_list)args
                           retainArguments: (BOOL)retain
{
    NSInvocation *invocation = [NSInvocation invocationWithTarget: self
                                                         selector: selector
                                                    firstArgument: arg1
                                               remainingArguments: args];
    if (retain) [invocation retainArguments];
    return invocation;
}

- (void) performSelector: (SEL)selector withValues: (void *)arg1, ...
{
    if (arg1)
    {
        va_list args;
        va_start(args, arg1);
        NSInvocation *invocation = [self _invocationWithSelector: selector
                                                   firstArgument: arg1
                                              remainingArguments: args
                                                 retainArguments: NO];
        va_end(args);
        
        [invocation invoke];
    }
    else [self performSelector: selector withObject: nil];
}

- (void) performSelector: (SEL)selector afterDelay: (NSTimeInterval)delay withValues: (void *)arg1, ...
{
    if (arg1)
    {
        va_list args;
        va_start(args, arg1);
        NSInvocation *invocation = [self _invocationWithSelector: selector
                                                   firstArgument: arg1
                                              remainingArguments: args
                                                 retainArguments: YES];
        va_end(args);
        
        [invocation performSelector: @selector(invoke) withObject: nil afterDelay: delay];
    }
    else [self performSelector: selector withObject: nil afterDelay: delay];
}

- (void) performSelectorOnMainThread: (SEL)selector waitUntilDone: (BOOL)wait withValues: (void *)arg1, ...
{
    if (arg1)
    {
        va_list args;
        va_start(args, arg1);
        
        NSInvocation *invocation = [self _invocationWithSelector: selector
                                                   firstArgument: arg1
                                              remainingArguments: args
                                                 retainArguments: YES];
        
        va_end(args);
        
        [invocation performSelectorOnMainThread: @selector(invoke) withObject: nil waitUntilDone: wait];
    }
    else [self performSelectorOnMainThread: selector withObject: nil waitUntilDone: wait];
}


- (void) performSelector: (SEL)selector
                onThread: (NSThread *)thread
           waitUntilDone: (BOOL)wait
              withValues: (void *)arg1, ...
{
    if (arg1)
    {
        va_list args;
        va_start(args, arg1);
        
        NSInvocation *invocation = [self _invocationWithSelector: selector
                                                   firstArgument: arg1
                                              remainingArguments: args
                                                 retainArguments: YES];
        
        va_end(args);
        
        [invocation performSelector: @selector(invoke) onThread: thread withObject: nil waitUntilDone: wait];
    }
    else [self performSelector: selector onThread: thread withObject: nil waitUntilDone: wait];
}

- (void) performSelectorInBackground: (SEL)selector
                          withValues: (void *)arg1, ...
{
    if (arg1)
    {
        va_list args;
        va_start(args, arg1);
        
        NSInvocation *invocation = [self _invocationWithSelector: selector
                                                   firstArgument: arg1
                                              remainingArguments: args
                                                 retainArguments: YES];
        
        va_end(args);
        
        [invocation performSelectorInBackground: @selector(invoke) withObject: nil];
    }
    else [self performSelectorInBackground: selector withObject: nil];
}
@end


@implementation NSInvocation (BXInvocationExtensions)

+ (NSInvocation *) invocationWithTarget: (id)target selector: (SEL)selector
{
    NSMethodSignature *signature = [target methodSignatureForSelector: selector];
    NSAssert2(signature, @"The target %@ does not respond to the selector %@.", target, NSStringFromSelector(selector));
    
    if (signature)
    {
        NSInvocation *invocation = [self invocationWithMethodSignature: signature];
        invocation.target = target;
        invocation.selector = selector;
        return invocation;
    }
    else return nil;
}

+ (NSInvocation *) invocationWithTarget: (id)target
                               selector: (SEL)selector
                              arguments: (void *)arg1, ...
{
    NSInvocation *invocation;
    if (arg1)
    {
        va_list(argList);
        va_start(argList, arg1);
        invocation = [self invocationWithTarget: target
                                       selector: selector
                                  firstArgument: arg1
                             remainingArguments: argList];
        va_end(argList);
    }
    else
    {
        invocation = [self invocationWithTarget: target selector: selector];
    }
    
    return invocation;
}

+ (NSInvocation *) invocationWithTarget: (id)target
                               selector: (SEL)selector
                          firstArgument: (void *)arg1
                     remainingArguments: (va_list)args
{
    NSInvocation *invocation = [self invocationWithTarget: target selector: selector];
    NSUInteger numArgs = invocation.methodSignature.numberOfArguments;
    
    if (invocation && numArgs > 2)
    {
        [invocation setArgument: arg1 atIndex: 2];
        
        if (args)
        {
            NSUInteger nextIndex;
            for (nextIndex = 3; nextIndex < numArgs; nextIndex++)
            {
                void *arg = va_arg(args, void *);
                [invocation setArgument: arg atIndex: nextIndex];
            }
        }
    }
    return invocation;
}
@end

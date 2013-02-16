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

#import "NSObject+ADBPerformExtensions.h"


@implementation NSObject (ADBPerformExtensions)

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
    else
    {
        //Clang will flag a warning about performSelector:withObject: calls with variable selectors under ARC,
        //because it has no way to tell whether any of the selectors we're calling may return a retained object.
        //We suppress the warning for this case on the assumption that the user won't be calling any such
        //methods since we discard the return value.
# pragma clang diagnostic push
# pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector: selector withObject: nil];
# pragma clang diagnostic pop
    }
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

- (void) performSelectorOnMainThread: (SEL)selector waitUntilDone: (BOOL)waitUntilDone withValues: (void *)arg1, ...
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
        
        [invocation performSelectorOnMainThread: @selector(invoke)
                                     withObject: nil
                                  waitUntilDone: waitUntilDone];
    }
    else
    {   
        [self performSelectorOnMainThread: selector
                               withObject: nil
                            waitUntilDone: waitUntilDone];
    }
}


- (void) performSelector: (SEL)selector
                onThread: (NSThread *)thread
           waitUntilDone: (BOOL)waitUntilDone
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
        
        [invocation performSelector: @selector(invoke)
                           onThread: thread
                         withObject: nil
                      waitUntilDone: waitUntilDone];
    }
    else
    {
        [self performSelector: selector
                     onThread: thread
                   withObject: nil
                waitUntilDone: waitUntilDone];
    }
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


@implementation NSInvocation (ADBInvocationExtensions)

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

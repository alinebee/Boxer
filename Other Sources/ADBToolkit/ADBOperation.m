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


#import "ADBOperation.h"
#import "ADBOperationDelegate.h"

#pragma mark -
#pragma mark Notification constants and keys

NSString * const ADBOperationWillStart		= @"ADBOperationWillStart";
NSString * const ADBOperationDidFinish		= @"ADBOperationDidFinish";
NSString * const ADBOperationInProgress		= @"ADBOperationInProgress";
NSString * const ADBOperationWasCancelled	= @"ADBOperationWasCancelled";

NSString * const ADBOperationContextInfoKey	= @"ADBOperationContextInfoKey";
NSString * const ADBOperationSuccessKey		= @"ADBOperationSuccessKey";
NSString * const ADBOperationErrorKey		= @"ADBOperationErrorKey";
NSString * const ADBOperationProgressKey		= @"ADBOperationProgressKey";
NSString * const ADBOperationIndeterminateKey	= @"ADBOperationIndeterminateKey";


@implementation ADBOperation
@synthesize delegate = _delegate;
@synthesize contextInfo = _contextInfo;
@synthesize notifiesOnMainThread = _notifiesOnMainThread;
@synthesize error = _error;
@synthesize willStartSelector = _willStartSelector;
@synthesize wasCancelledSelector = _wasCancelledSelector;
@synthesize inProgressSelector = _inProgressSelector;
@synthesize didFinishSelector = _didFinishSelector;

- (id) init
{
    self = [super init];
	if (self)
	{
        self.notifiesOnMainThread = YES;
        self.willStartSelector = @selector(operationWillStart:);
        self.inProgressSelector = @selector(operationInProgress:);
        self.wasCancelledSelector = @selector(operationWasCancelled:);
        self.didFinishSelector = @selector(operationDidFinish:);
	}
	return self;
}

- (void) start
{
    [self _sendWillStartNotificationWithInfo: nil];
    [super start];
    [self _sendDidFinishNotificationWithInfo: nil];
}

- (void) cancel
{	
	//Only send a notification the first time we're cancelled,
	//and only if we're in progress when we get cancelled
	if (!self.isCancelled && self.isExecuting)
	{
		[super cancel];
		if (!self.error)
		{
			//If we haven't encountered a more serious error, set the error to indicate that this operation was cancelled.
            self.error = [NSError errorWithDomain: NSCocoaErrorDomain
                                             code: NSUserCancelledError
                                         userInfo: nil];
		}
		[self _sendWasCancelledNotificationWithInfo: nil];
	}
	else [super cancel];
}

- (BOOL) succeeded
{
    return !self.error;
}

//The following are meant to be overridden by subclasses to provide more meaningful progress tracking.
- (ADBOperationProgress) currentProgress
{
	return 0.0f;
}

+ (NSSet *) keyPathsForValuesAffectingTimeRemaining
{
	return [NSSet setWithObjects: @"currentProgress", @"isFinished", nil];
}

- (NSTimeInterval) timeRemaining
{
	return self.isFinished ? 0.0 : ADBUnknownTimeRemaining;
}

- (BOOL) isIndeterminate
{
	return YES;
}


#pragma mark -
#pragma mark Notifications

- (void) _sendWillStartNotificationWithInfo: (NSDictionary *)info
{
	//Don't send start notifications if we're already cancelled
	if (self.isCancelled) return;
	
	[self _postNotificationName: ADBOperationWillStart
			   delegateSelector: self.willStartSelector
	 				   userInfo: info];
}

- (void) _sendWasCancelledNotificationWithInfo: (NSDictionary *)info
{
	[self _postNotificationName: ADBOperationWasCancelled
			   delegateSelector: self.wasCancelledSelector
					   userInfo: info];
}

- (void) _sendDidFinishNotificationWithInfo: (NSDictionary *)info
{
	NSMutableDictionary *finishInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									   @(self.succeeded), ADBOperationSuccessKey,
									   self.error, ADBOperationErrorKey,
									   nil];

	if (info)
        [finishInfo addEntriesFromDictionary: info];

	[self _postNotificationName: ADBOperationDidFinish
			   delegateSelector: self.didFinishSelector
					   userInfo: finishInfo];
}

- (void) _sendInProgressNotificationWithInfo: (NSDictionary *)info
{
	//Don't send progress notifications if we're already cancelled
	if (self.isCancelled) return;
	
	NSMutableDictionary *progressInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										 @(self.currentProgress), ADBOperationProgressKey,
										 @(self.isIndeterminate), ADBOperationIndeterminateKey,
										 nil];
	if (info)
        [progressInfo addEntriesFromDictionary: info];
	
	[self _postNotificationName: ADBOperationInProgress
			   delegateSelector: self.inProgressSelector
					   userInfo: progressInfo];
}


- (void) _postNotificationName: (NSString *)name
			  delegateSelector: (SEL)selector
					  userInfo: (NSDictionary *)userInfo
{
	//Extend the notification dictionary with context info
	if (self.contextInfo)
	{
		NSMutableDictionary *contextDict = [NSMutableDictionary dictionaryWithObject: self.contextInfo
																			  forKey: ADBOperationContextInfoKey];
		if (userInfo)
            [contextDict addEntriesFromDictionary: userInfo];
		userInfo = contextDict;
	}
	
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	NSNotification *notification = [NSNotification notificationWithName: name
																 object: self
															   userInfo: userInfo];
	
	if ([self.delegate respondsToSelector: selector])
	{
		if (self.notifiesOnMainThread)
			[(id)self.delegate performSelectorOnMainThread: selector withObject: notification waitUntilDone: NO];
		else
			[self.delegate performSelector: selector withObject: notification];
	}
	
	if (self.notifiesOnMainThread)
		[center performSelectorOnMainThread: @selector(postNotification:) withObject: notification waitUntilDone: NO];		
	else
		[center postNotification: notification];
}

@end

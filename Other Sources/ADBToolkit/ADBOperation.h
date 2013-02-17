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


//ADBOperation is an abstract base class for NSOperations, which can be observed by a delegate
//and which sends periodic progress notifications.
//ADBOperationDelegate defines the interface for delegates.

#import <Foundation/Foundation.h>

typedef float ADBOperationProgress;

#define ADBUnknownTimeRemaining -1

#pragma mark -
#pragma mark Notification constants

//Sent when the operation is about to start.
extern NSString * const ADBOperationWillStart;

//Sent periodically while the operation is in progress.
extern NSString * const ADBOperationInProgress;

//Sent when the operation ends (be it because of success, failure or cancellation.)
extern NSString * const ADBOperationDidFinish;

//Sent when the operation gets cancelled.
extern NSString * const ADBOperationWasCancelled;


#pragma mark -
#pragma mark Notification user info dictionary keys

//An arbitrary object representing the context for the operation.
//Included in all notifications, if contextInfo was set.
extern NSString * const ADBOperationContextInfoKey;

//An NSNumber boolean indicating whether the operation succeeded or failed.
//Included with ADBOperationFinished.
extern NSString * const ADBOperationSuccessKey;

//An NSError containing the details of a failed operation.
//Included with ADBOperationFinished if the operation failed.
extern NSString * const ADBOperationErrorKey;

//An NSNumber float from 0.0 to 1.0 indicating the progress of the operation.
//Included with ADBOperationInProgress.
extern NSString * const ADBOperationProgressKey;

//An NSNumber boolean indicating whether the operation cannot currently
//measure its progress in a meaningful way.
//Included with ADBOperationInProgress.
extern NSString * const ADBOperationIndeterminateKey;


@protocol ADBOperationDelegate;

@interface ADBOperation : NSOperation
{
	__unsafe_unretained id <ADBOperationDelegate> _delegate;
	id _contextInfo;
	
	SEL _willStartSelector;
	SEL _inProgressSelector;
	SEL _wasCancelledSelector;
	SEL _didFinishSelector;
	
	BOOL _notifiesOnMainThread;
	
	NSError *_error;
}

#pragma mark -
#pragma mark Configuration properties

//The delegate that will receive notification messages about this operation.
@property (assign) id <ADBOperationDelegate> delegate;

//The callback methods that will be called on the delegate for progress notifications.
//These default to ADBOperationDelegate operationInProgress:, operationDidFinish: etc.
//and must have the same signatures as those methods.
@property (assign) SEL willStartSelector;
@property (assign) SEL inProgressSelector;
@property (assign) SEL wasCancelledSelector;
@property (assign) SEL didFinishSelector;

//Arbitrary context info for this operation. Included in notification dictionaries
//for controlling contexts to use. Note that this is an NSObject and will be retained.
@property (retain) id contextInfo;

//Whether delegate and NSNotificationCenter notifications should be sent on the main
//thread or on the operation's current thread. Defaults to YES (the main thread).
@property (assign) BOOL notifiesOnMainThread;

#pragma mark -
#pragma mark Operation status properties

//A float from 0.0f to 1.0f indicating how far through its process the operation is.
@property (readonly) ADBOperationProgress currentProgress;

//An estimate of how long remains before the operation completes.
//Will be 0.0 if the operation has already finished, or ADBUnknownTimeRemaining
//if no estimate can be provided (which usually means isIndeterminate is YES also.)
@property (readonly) NSTimeInterval timeRemaining;

//Indicates whether the process cannot currently provide a meaningful indication
//of progress (and thus whether the value of currentProgress should be ignored).
//Returns YES by default; intended to be overridden by subclasses that can offer
//meaningful progress tracking.
@property (readonly, getter=isIndeterminate) BOOL indeterminate;

//Whether the operation has succeeeded or failed: only applicable once the operation
//finishes, though it can be called at any time.
//In the base implementation, this will return NO if the operation has generated
//an error, or YES otherwise (even if the operation has not yet finished.)
//This can be overridden by subclasses.
@property (readonly) BOOL succeeded;

//Any showstopping error that occurred when performing the operation.
//If this is set, succeeded will be NO.
@property (retain) NSError *error;

@end


#pragma mark -
#pragma mark Protected method declarations

//These methods are for the use of ADBOperation subclasses only.
@interface ADBOperation ()

//Called at the start of main, just before performOperation and after
//ADBOperationWillStartNotifications have been sent. 
//Base implementation does nothing; intended to be overridden by subclasses.
- (void) willPerformOperation;

//Called at the end of main, after performOperation has exited and before
//ADBOperationDidFinishNotifications have been sent.
//Base implementation does nothing; intended to be overridden by subclasses.
- (void) didPerformOperation;

//Performs the main work of the operation. This is called from ADBOperation's main
//if the operation has not already been cancelled.
//Base implementation does nothing; intended to be overridden by subclasses.
- (void) performOperation;


//Post one of the corresponding notifications.
- (void) _sendWillStartNotificationWithInfo: (NSDictionary *)info;
- (void) _sendInProgressNotificationWithInfo: (NSDictionary *)info;
- (void) _sendWasCancelledNotificationWithInfo: (NSDictionary *)info;
- (void) _sendDidFinishNotificationWithInfo: (NSDictionary *)info;

//Shortcut method for sending a notification both to the default notification center
//and to a selector on our delegate. The object of the notification will be self.
- (void) _postNotificationName: (NSString *)name
			  delegateSelector: (SEL)selector
					  userInfo: (NSDictionary *)userInfo;
@end

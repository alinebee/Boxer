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

//ADBTaskOperation monitors the progress of an NSTask.


//Default to polling task progress every second
#define ADBTaskOperationDefaultPollInterval 1.0


#import "ADBOperation.h"

NS_ASSUME_NONNULL_BEGIN

/// ADBTaskOperation monitors the progress of an NSTask.
@interface ADBTaskOperation : ADBOperation
{
	@private
	NSTimeInterval _pollInterval;
	NSTask *_task;
}

#pragma mark -
#pragma mark Properties

/// The task we will be running.
@property (retain) NSTask *task;

/// The interval at which to check the progress of the task and issue progress updates.
/// The operation's running time will roughly be a multiple of this interval.
@property (assign) NSTimeInterval pollInterval;


#pragma mark -
#pragma mark Initialization

/// Create/initialize a suitable ADBTaskOperation using the specified task.
+ (instancetype) operationWithTask: (NSTask *)task;
- (instancetype) initWithTask: (NSTask *)task;


#pragma mark -
#pragma mark Task execution

/// Runs the task to completion, while calling monitorTask:withProgressCallback:atInterval:
/// periodically to update our completion status.
- (void) main;

/// Used by \c -main to monitor the specified task while running the run loop:
/// returns when cancelled, or when the task finishes of its own accord.
/// The selected callback should have the same signature as checkTaskProgress,
/// and will be called periodically at the specified polling interval.
/// It will receive the poll timer with userInfo set to the specified task.
- (void) monitorTask: (NSTask *)task
withProgressCallback: (SEL)callback
		  atInterval: (NSTimeInterval)interval;

/// Default callback for \c monitorTask:withProgressCallback:atInterval:.
/// By default this does nothing but send ADBOperationInProgress notifications:
/// intended to be overridden in child classes to provide actual progress calculation.
- (void) checkTaskProgress: (NSTimer *)timer;

@end

NS_ASSUME_NONNULL_END

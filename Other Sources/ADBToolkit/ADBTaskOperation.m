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

#import "ADBTaskOperation.h"



@implementation ADBTaskOperation
@synthesize task = _task;
@synthesize pollInterval = _pollInterval;


#pragma mark -
#pragma mark Initialization and deallocation

+ (id) operationWithTask: (NSTask *)task
{
	return [[self alloc] initWithTask: task];
}

- (id) init
{
	if ((self = [super init]))
	{
        self.pollInterval = ADBTaskOperationDefaultPollInterval;
	}
	return self;
}

- (id) initWithTask: (NSTask *)task
{
	if ((self = [self init]))
	{
        self.task = task;
	}
	return self;
}

#pragma mark -
#pragma mark Task execution

- (void) main
{
    NSAssert(self.task != nil, @"No task provided for operation.");
    
	[self.task launch];
	
	[self monitorTask: self.task
 withProgressCallback: @selector(checkTaskProgress:)
		   atInterval: [self pollInterval]];
}

- (void) monitorTask: (NSTask *)task
withProgressCallback: (SEL)callback
		  atInterval: (NSTimeInterval)interval
{	
	//Use a timer to poll the task's progress. (This also keeps the runloop below alive.)
	NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval: interval
													  target: self
													selector: callback
													userInfo: task
													 repeats: YES];
	
	NSRunLoop *loop = [NSRunLoop currentRunLoop];
	
	//Run the runloop until the task is finished, letting the timer call our polling function.
	//We use a runloop instead of just sleeping, because the runloop lets cancellation messages
	//get dispatched to us correctly.)
	while (task.isRunning && [loop runMode: NSDefaultRunLoopMode
                                beforeDate: [NSDate dateWithTimeIntervalSinceNow: interval]])
	{
		//Kill the task if we've been cancelled in the meantime
		//(this will break out of the loop once the task finishes up)
		if (self.isCancelled)
            [task terminate];
	}
	[timer invalidate];
}

- (void) checkTaskProgress: (NSTimer *)timer
{
	[self _sendInProgressNotificationWithInfo: nil];
}
@end

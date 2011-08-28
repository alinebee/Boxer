//
//  BXTaskOperation.m
//  Boxer
//
//  Created by Alun Bestor on 07/04/2011.
//  Copyright 2011 Alun Bestor and contributors. All rights reserved.
//

#import "BXTaskOperation.h"

//Default to polling task progress every second
#define BXTaskOperationDefaultPollInterval 1.0


@implementation BXTaskOperation
@synthesize task = _task;
@synthesize pollInterval = _pollInterval;


#pragma mark -
#pragma mark Initialization and deallocation

+ (id) operationWithTask: (NSTask *)task
{
	return [[[self alloc] initWithTask: task] autorelease];
}

- (id) init
{
	if ((self = [super init]))
	{
		[self setPollInterval: BXTaskOperationDefaultPollInterval];
	}
	return self;
}

- (id) initWithTask: (NSTask *)task
{
	if ((self = [self init]))
	{
		[self setTask: task];
	}
	return self;
}

- (void) dealloc
{
	[self setTask: nil], _task = nil;
	return [super dealloc];
}

#pragma mark -
#pragma mark Task execution

- (BOOL) shouldPerformOperation
{
    return [super shouldPerformOperation] && [self task];
}

- (void) performOperation
{
	[[self task] launch];
	
	[self monitorTask: [self task]
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
	while ([task isRunning] && [loop runMode: NSDefaultRunLoopMode
								  beforeDate: [NSDate dateWithTimeIntervalSinceNow: interval]])
	{
		//Kill the task if we've been cancelled in the meantime
		//(this will break out of the loop once the task finishes up)
		if ([self isCancelled]) [task terminate];
	}
	[timer invalidate];
}

- (void) checkTaskProgress: (NSTimer *)timer
{
	[self _sendInProgressNotificationWithInfo: nil];
}
@end

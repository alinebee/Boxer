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


#import "ADBOperationSet.h"


#pragma mark -
#pragma mark Private method declarations

@interface ADBOperationSet ()

//Runs a single iteration of the internal run loop while we wait for the queue to finish.
//This simply sends an in-progress notification signal.
- (void) _postUpdateWithTimer: (NSTimer *)timer;

@end


@implementation ADBOperationSet
@synthesize operations = _operations;
@synthesize pollInterval = _pollInterval;
@synthesize maxConcurrentOperations = _maxConcurrentOperations;

#pragma mark -
#pragma mark Initialization and deallocation

+ (id) setWithOperations: (NSArray *)operations
{
	return [[[self alloc] initWithOperations: operations] autorelease];
}

- (id) init
{
	if ((self = [super init]))
	{
		self.pollInterval = ADBOperationSetDefaultPollInterval;
		self.operations = [NSMutableArray arrayWithCapacity: 5];
        self.maxConcurrentOperations = NSOperationQueueDefaultMaxConcurrentOperationCount;
	}
	return self;
}

- (id) initWithOperations: (NSArray *)operations
{
	if ((self = [self init]))
	{
		if (operations)
			self.operations = [[operations mutableCopy] autorelease];
	}
	return self;
}

- (void) dealloc
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    self.operations = nil;
    
	[super dealloc];
#pragma clang diagnostic pop
}


#pragma mark -
#pragma mark Running the operations

+ (NSSet *) keyPathsForValuesAffectingCurrentProgress
{
	return [NSSet setWithObject: @"operations"];
}

- (ADBOperationProgress) currentProgress
{
	//Treat the current progress as the average across all our operations
	NSUInteger numOperations = 0;
	ADBOperationProgress totalProgress = 0.0f;
	
	for (ADBOperation *operation in self.operations)
	{
		//Only count the operation if it can report its progress
		if (!operation.isIndeterminate)
		{
			totalProgress += operation.currentProgress;
			numOperations++;			
		}
	}
	
	return totalProgress / (ADBOperationProgress)numOperations;
}

+ (NSSet *) keyPathsForValuesAffectingIndeterminate
{
	return [NSSet setWithObject: @"operations"];
}

- (BOOL) isIndeterminate
{
	for (ADBOperation *operation in self.operations)
	{
		if (!operation.isIndeterminate) return NO;
	}
	return YES;
}

- (NSTimeInterval) timeRemaining
{
	NSTimeInterval totalRemaining = 0.0;
	for (ADBOperation *operation in self.operations)
	{
		NSTimeInterval operationRemaining = operation.timeRemaining;
		if (operationRemaining != ADBUnknownTimeRemaining)
            totalRemaining += operationRemaining;
	}
	return totalRemaining;
}


- (void) main
{	
	NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = self.maxConcurrentOperations;

	//Queue up all transfer operations before letting them all start at once
	[queue setSuspended: YES];
	for (NSOperation *operation in self.operations)
        [queue addOperation: operation];
	[queue setSuspended: NO];
	
	//Use a timer to execute our polling method. (This also keeps the runloop below alive.)
	NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval: self.pollInterval
													  target: self
													selector: @selector(_postUpdateWithTimer:)
													userInfo: queue
													 repeats: YES];
	
	
	//Poll until all operations are finished, but cancel them all if we ourselves are cancelled.
	while (queue.operations.count && [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                                                              beforeDate: [NSDate dateWithTimeIntervalSinceNow: self.pollInterval]])
	{
		if (self.isCancelled) [queue cancelAllOperations];
	}
	[timer invalidate];
	
	if (!self.error)
	{
		for (ADBOperation *operation in self.operations)
		{
			if (operation.error)
			{
				self.error = operation.error;
				break;
			}
		}		
	}
	
	[queue release];
}

- (void) _postUpdateWithTimer: (NSTimer *)timer
{
	[self willChangeValueForKey: @"currentProgress"];
	[self willChangeValueForKey: @"indeterminate"];
	[self didChangeValueForKey: @"currentProgress"];
	[self didChangeValueForKey: @"indeterminate"];
		
	[self _sendInProgressNotificationWithInfo: nil];
}

@end
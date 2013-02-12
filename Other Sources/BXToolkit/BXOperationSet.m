/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXOperationSet.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXOperationSet ()

//Runs a single iteration of the internal run loop while we wait for the queue to finish.
//This simply sends an in-progress notification signal.
- (void) _postUpdateWithTimer: (NSTimer *)timer;

@end


@implementation BXOperationSet
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
		self.pollInterval = BXOperationSetDefaultPollInterval;
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
    self.operations = nil;
    
	[super dealloc];
}


#pragma mark -
#pragma mark Running the operations

+ (NSSet *) keyPathsForValuesAffectingCurrentProgress
{
	return [NSSet setWithObject: @"operations"];
}

- (BXOperationProgress) currentProgress
{
	//Treat the current progress as the average across all our operations
	NSUInteger numOperations = 0;
	BXOperationProgress totalProgress = 0.0f;
	
	for (BXOperation *operation in self.operations)
	{
		//Only count the operation if it can report its progress
		if (!operation.isIndeterminate)
		{
			totalProgress += operation.currentProgress;
			numOperations++;			
		}
	}
	
	return totalProgress / (BXOperationProgress)numOperations;
}

+ (NSSet *) keyPathsForValuesAffectingIndeterminate
{
	return [NSSet setWithObject: @"operations"];
}

- (BOOL) isIndeterminate
{
	for (BXOperation *operation in self.operations)
	{
		if (!operation.isIndeterminate) return NO;
	}
	return YES;
}

- (NSTimeInterval) timeRemaining
{
	NSTimeInterval totalRemaining = 0.0;
	for (BXOperation *operation in self.operations)
	{
		NSTimeInterval operationRemaining = operation.timeRemaining;
		if (operationRemaining != BXUnknownTimeRemaining)
            totalRemaining += operationRemaining;
	}
	return totalRemaining;
}


- (void) performOperation
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
		for (BXOperation *operation in self.operations)
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
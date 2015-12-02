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


//ADBOperationSet groups multiple concurrent operations into one operation, whose progress can
//be tracked as a whole. It wraps an NSOperationQueue.

#import "ADBOperation.h"

NS_ASSUME_NONNULL_BEGIN

/// The standard interval in seconds at which to poll the progress of our dependent operations
#define ADBOperationSetDefaultPollInterval 0.1

/// ADBOperationSet groups multiple concurrent operations into one operation, whose progress can
/// be tracked as a whole. It wraps an NSOperationQueue.
@interface ADBOperationSet : ADBOperation
{
	NSMutableArray *_operations;
	NSTimeInterval _pollInterval;
    NSInteger _maxConcurrentOperations;
}

#pragma mark -
#pragma mark Properties

/// The operations within this set.
/// These will be added to an operation queue only when this operation is started.
/// After starting, it is not safe to modify this array.
@property (strong, nonatomic) NSMutableArray<ADBOperation*> *operations;

/// The maximum number of operations we should execute at once.
/// Defaults to NSOperationQueueDefaultMaxConcurrentOperationCount.
@property (assign, nonatomic) NSInteger maxConcurrentOperations;

/// The interval at which to check the progress of our dependent operations and
/// issue overall progress updates.<br>
/// ADBOperationSet's overall running time will be a multiple of this interval.
@property (assign) NSTimeInterval pollInterval;

#pragma mark -
#pragma mark Initialization

+ (instancetype) setWithOperations: (NSArray<ADBOperation*> *)operations;
- (instancetype) initWithOperations: (NSArray<ADBOperation*> *)operations;

@end

NS_ASSUME_NONNULL_END

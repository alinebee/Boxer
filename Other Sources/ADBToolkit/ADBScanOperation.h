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

//ADBScanOperation is a generic operation that asynchronously traverses an enumerator
//to generate an array of filtered objects, using a user-supplied block which can filter
//and/or convert the objects being enumerated.
//It sends out notifications when enumerating and matching, and can be cancelled midstream
//by the block itself, by reaching a maximum number of matches, or through the standard
//NSOperation API.
//This class is intended for applications like asynchronous filesystem scanning.

#import "ADBOperation.h"
#import "ADBEnumerationHelpers.h"


NS_ASSUME_NONNULL_BEGIN

//Keys included in update notifications

/// Contains the object most recently enumerated (whether it was considered a match or not.)
extern NSString * const ADBScanLatestScannedObjectKey;

/// Contains the object that was most recently matched.
/// Will be NSNull if no matches have been found.
extern NSString * const ADBScanLatestMatchKey;


@interface ADBScanOperation : ADBOperation
{
    id <NSFastEnumeration> _enumerator;
    ADBScanCallback _matchCallback;
    NSMutableArray *_matches;
    NSUInteger _maxMatches;
}

#pragma mark - Public properties

/// The enumerator which this scan will traverse.
@property (retain) id <NSFastEnumeration> enumerator;

/// The callback block this scan will call with each object returned by the enumerator,
/// to determine whether it is a match or not.
@property (copy) ADBScanCallback matchCallback;

/// An array of all objects that were matched in this search.
/// This property is KVO observable, and will send out notifications
/// on the operation's own thread as new objects are added.
@property (retain) NSMutableArray *matches;

/// Optional: the maximum number of matches to find. If greater than 0,
/// enumeration will stop after this many matches are found. Defaults to 0.
@property (assign) NSUInteger maxMatches;

#pragma mark - Constructors

+ (instancetype) scanWithEnumerator: (id <NSFastEnumeration>)enumerator
                         usingBlock: (ADBScanCallback)matchCallback;

- (instancetype) initWithEnumerator: (id <NSFastEnumeration>)enumerator
                         usingBlock: (ADBScanCallback)matchCallback;


#pragma mark - Subclassable methods

/// Adds the specified object to the matches.
/// This can be overridden in subclasses to perform further processing.
- (void) addMatch: (id)match;

@end

NS_ASSUME_NONNULL_END

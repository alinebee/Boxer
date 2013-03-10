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

//ADBScanOperation is a generic operation to asynchronously traverse an enumerator to
//build up an array of matching objects. It sends out notifications when matches are found,
//and can be cancelled midstream or set to end after a maximum number of matches.
//This class is intended for e.g. asynchronous filesystem scanning.

#import "ADBOperation.h"

//Keys included in update notifications

//Contains the object most recently enumerated (whether it was considered a match or not.)
extern NSString * const ADBScanLatestObjectKey;

//Contains the object that was most recently matched.
//Will be NSNull if no matches have been found.
extern NSString * const ADBScanLatestMatchKey;


//Called for each object that is traversed by the enumerator: should return YES
//if the specified object is considered a match, NO otherwise.
//Object is the object returned by the enumerator's nextObject method,
//enumerator is the enumerator that was passed into the operation, and stop
//is an output boolean that can be set to YES to halt enumeration after this object.
typedef BOOL(^ADBScanCallback)(id object, NSEnumerator *enumerator, BOOL *stop);


@interface ADBScanOperation : ADBOperation
{
    NSEnumerator *_enumerator;
    ADBScanCallback _matchCallback;
    NSMutableArray *_matches;
    NSUInteger _maxMatches;
}

#pragma mark - Public properties

//The enumerator which this scan will traverse.
@property (retain) NSEnumerator *enumerator;

//The callback block this scan will call with each object returned by the enumerator,
//to determine whether it is a match or not.
@property (copy) ADBScanCallback matchCallback;

//An array of all objects that were matched in this search.
//This property is KVO observable, and will send out notifications
//on the operation's own thread as new objects are added.
@property (retain) NSMutableArray *matches;

//Optional: the maximum number of matches to find. If greater than 0,
//enumeration will stop after this many matches are found. Defaults to 0.
@property (assign) NSUInteger maxMatches;

#pragma mark - Constructors

+ (id) scanWithEnumerator: (NSEnumerator *)enumerator
               usingBlock: (ADBScanCallback)matchCallback;

- (id) initWithEnumerator: (NSEnumerator *)enumerator
               usingBlock: (ADBScanCallback)matchCallback;


#pragma mark - Subclassable methods

//Adds the specified object to the matches. This can be overridden in subclasses
//to do further processing.
- (void) addMatch: (id)match;

@end

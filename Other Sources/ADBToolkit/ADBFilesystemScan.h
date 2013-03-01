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
#import "ADBFilesystem.h"

//Included in update notifications and contains the path
//that was most recently enumerated (whether it was considered a match or not.)
extern NSString * const ADBFilesystemScanLatestPathKey;

//Called for each path that is traversed by the enumerator: should return YES
//if the specified path is considered a match, NO otherwise.
//Path is the logical filesystem-relative path to the file being enumerated,
//enumerator is the enumerator that was passed into the operations, and stop
//is an output boolean that can be set to YES to halt enumeration after this path.
typedef BOOL(^ADBFilesystemMatchCallback)(NSString *path, id <ADBFilesystemPathEnumeration>enumerator, BOOL *stop);

@interface ADBFilesystemScan : ADBOperation
{
    id <ADBFilesystemPathEnumeration> _enumerator;
    ADBFilesystemMatchCallback _matchCallback;
    NSMutableArray *_matchingPaths;
    NSUInteger _maxMatches;
}

#pragma mark - Public properties

//The enumerator which this scan will traverse.
@property (retain) id <ADBFilesystemPathEnumeration> enumerator;

//The callback block this scan will call with each path found,
//to determine whether the path is a match or not.
@property (copy) ADBFilesystemMatchCallback matchCallback;

//An array of all paths that were matched in this search.
//These are relative to the filesystem of the enumerator.
//This property is KVO observable, and will send out notifications
//on the operation's own thread as new paths are added.
@property (retain) NSMutableArray *matchingPaths;

//Optional: the maximum number of matches to find. If greater than 0,
//enumeration will stop after this many matches are found. Defaults to 0.
@property (assign) NSUInteger maxMatches;

#pragma mark - Constructors

+ (id) scanWithEnumerator: (id <ADBFilesystemPathEnumeration>)enumerator
               usingBlock: (ADBFilesystemMatchCallback)matchCallback;

- (id) initWithEnumerator: (id <ADBFilesystemPathEnumeration>)enumerator
               usingBlock: (ADBFilesystemMatchCallback)matchCallback;


#pragma mark - Subclassable methods

//Adds the specified path to the matches.
- (void) addMatchingPath: (NSString *)path;

@end

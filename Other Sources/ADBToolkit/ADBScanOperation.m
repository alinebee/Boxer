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

#import "ADBScanOperation.h"

NSString * const ADBScanLatestObjectKey = @"ADBScanLatestObject";
NSString * const ADBScanLatestMatchKey = @"ADBScanLatestMatch";

@implementation ADBScanOperation
@synthesize enumerator = _enumerator;
@synthesize matchCallback = _matchCallback;
@synthesize matches = _matches;
@synthesize maxMatches = _maxMatches;

+ (id) scanWithEnumerator: (NSEnumerator *)enumerator
               usingBlock: (ADBScanCallback)matchCallback
{
    return [[[self alloc] initWithEnumerator: enumerator
                                  usingBlock: matchCallback] autorelease];
}

- (id) initWithEnumerator: (NSEnumerator *)enumerator
               usingBlock: (ADBScanCallback)matchCallback
{
    self = [self init];
    if (self)
    {
        self.enumerator = enumerator;
        self.matchCallback = matchCallback;
    }
    return self;
}

- (void) dealloc
{
    self.enumerator = nil;
    self.matchCallback = nil;
    self.matches = nil;
    [super dealloc];
}

- (void) main
{
    NSAssert(self.enumerator != nil, @"No enumerator provided.");
    NSAssert(self.matchCallback != nil, @"No callback block provided.");
    
    self.matches = [NSMutableArray arrayWithCapacity: 10];
    
    NSMutableDictionary *updateInfo = [NSMutableDictionary dictionaryWithCapacity: 2];
    for (id object in self.enumerator)
    {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        BOOL stop = NO;
        BOOL matched = self.matchCallback(object, self.enumerator, &stop);
        if (matched)
        {
            [self addMatch: object];
            [updateInfo setObject: object forKey: ADBScanLatestMatchKey];
            if (self.maxMatches > 0 && self.matches.count > self.maxMatches)
                stop = YES;
        }
        
        [updateInfo setObject: object forKey: ADBScanLatestObjectKey];
        [self _sendInProgressNotificationWithInfo: updateInfo];
        
        [pool drain];
        
        if (stop || self.isCancelled)
            break;
    }
}

- (void) addMatch: (id)match
{
    //Ensures KVO notifications are sent properly for this key.
	[[self mutableArrayValueForKey: @"matchingPaths"] addObject: match];
}

@end

/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXContinuousThread.h"

@implementation BXContinuousThread

- (void) cancel
{
    //Make sure the cancel request is handled on our own thread,
    //so that runUntilCancelled will receive the message and check for cancellation.
    if ([NSThread currentThread] != self)
    {
        [self performSelector: _cmd onThread: self withObject: nil waitUntilDone: NO];
    }
    else
    {
        [super cancel];
    }
}

- (void) runUntilCancelled
{
    while (![self isCancelled] && [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                                                           beforeDate: [NSDate distantFuture]]);    
}

- (void) waitUntilFinished
{
    NSAssert([NSThread currentThread] != self, @"waitUntilFinished called on self by thread.");
    
    while ([self isExecuting]) [NSThread sleepForTimeInterval: 0.001];
}

@end

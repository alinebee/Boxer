/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXContinuousThread is an NSThread subclass designed to run continuously until cancelled.

#import <Foundation/Foundation.h>

@interface BXContinuousThread : NSThread

//Runs the thread's run-loop until distantFuture, waiting for the thread to be cancelled.
- (void) runUntilCancelled;

//Blocks the current thread until the thread has finished.
- (void) waitUntilFinished;

@end

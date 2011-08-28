/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXTaskOperation monitors the progress of an NSTask.

#import "BXOperation.h"

@interface BXTaskOperation : BXOperation
{
	@private
	NSTimeInterval _pollInterval;
	NSTask *_task;
}

#pragma mark -
#pragma mark Properties

//The task we will be running.
@property (retain) NSTask *task;

//The interval at which to check the progress of the task and issue progress updates.
//The operation's running time will roughly be a multiple of this interval.
@property (assign) NSTimeInterval pollInterval;


#pragma mark -
#pragma mark Initialization

//Create/initialize a suitable BXTaskOperation using the specified task.
+ (id) operationWithTask: (NSTask *)task;
- (id) initWithTask: (NSTask *)task;


#pragma mark -
#pragma mark Task execution


//Used by -performOperation to monitor the specified task while running the run
//loop: returns when cancelled, or when the task finishes of its own accord.
//The selected callback should have the same signature as checkTaskProgress,
//and will be called periodically at the specified polling interval.
//It will receive the poll timer with userInfo set to the specified task.
- (void) monitorTask: (NSTask *)task
withProgressCallback: (SEL)callback
		  atInterval: (NSTimeInterval)interval;

//Default callback for monitorTask:withProgressCallback:atInterval:.
//By default this does nothing but send BXOperationInProgress notifications:
//intended to be overridden in child classes to provide actual progress calculation.
- (void) checkTaskProgress: (NSTimer *)timer;

@end

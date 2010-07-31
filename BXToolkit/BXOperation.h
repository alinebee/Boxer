/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXOperation is an abstract base class for NSOperations, which can be observed by a delegate
//and which sends periodic progress notifications.
//BXOperationDelegate defines the interface for delegates.

#import <Foundation/Foundation.h>

typedef float BXOperationProgress;
#define BXOperationProgressUndefined -1.0f

#pragma mark -
#pragma mark Notification constants

//Sent when the operation is about to start.
extern NSString * const BXOperationWillStart;

//Sent periodically while the operation is in progress.
extern NSString * const BXOperationInProgress;

//Sent when the operation ends (be it in success or failure.)
extern NSString * const BXOperationDidFinish;

//Sent when the operation gets cancelled.
//The transfer will still send a BXOperationWasCancelled after this.
extern NSString * const BXOperationWasCancelled;


#pragma mark -
#pragma mark Notification user info dictionary keys

//An arbitrary object representing the context for the operation.
//Included in all notifications, if contextInfo was set.
extern NSString * const BXOperationContextInfoKey;

//An NSNumber boolean indicating whether the operation succeeded or failed.
//Included with BXOperationFinished.
extern NSString * const BXOperationSuccessKey;

//An NSError containing the details of a failed operation.
//Included with BXOperationFinished if the operation failed.
extern NSString * const BXOperationErrorKey;

//An NSNumber float from 0.0 to 1.0 indicating the progress of the operation.
//Included with BXOperationInProgress.
extern NSString * const BXOperationProgressKey;


@protocol BXOperationDelegate;

@interface BXOperation : NSOperation
{
	id <BXOperationDelegate> delegate;
	id contextInfo;
	BOOL notifyOnMainThread;
	
	BOOL succeeded;
	NSError *error;
}

#pragma mark -
#pragma mark Configuration properties

//The delegate that will receive notification messages about this operation.
@property (assign) id <BXOperationDelegate> delegate;

//Arbitrary context info for this operation. Included in notification dictionaries
//for controlling contexts to use. Note that this is an NSObject and will be retained.
@property (retain) id contextInfo;

//Whether delegate and NSNotificationCenter notifications should be sent on the main
//thread or on the operation's current thread. Defaults to YES (the main thread).
@property (assign) BOOL notifyOnMainThread;

#pragma mark -
#pragma mark Operation status properties

//A float from 0.0f to 1.0f indicating how far through its process the operation is.
//Will be BXOperationProgressUndefined if the operation cannot provide a meaningful
//indication of progress.
@property (readonly) BXOperationProgress currentProgress;

//Whether the operation succeeeded or failed. Only relevant once isFinished is YES.
@property (assign) BOOL succeeded;

//Any showstopping error that occurred when performing the operation.
//Populated once the operation finishes.
@property (retain) NSError *error;

@end


#pragma mark -
#pragma mark Protected method declarations

//These methods are for the use of BXOperation subclasses only.
@interface BXOperation ()

//Post one of the corresponding notifications.
- (void) _sendWillStartNotificationWithInfo: (NSDictionary *)info;
- (void) _sendInProgressNotificationWithInfo: (NSDictionary *)info;
- (void) _sendWasCancelledNotificationWithInfo: (NSDictionary *)info;
- (void) _sendDidFinishNotificationWithInfo: (NSDictionary *)info;

//Shortcut method for sending a notification both to the default notification center
//and to a selector on our delegate. The object of the notification will be self.
- (void) _postNotificationName: (NSString *)name
			  delegateSelector: (SEL)selector
					  userInfo: (NSDictionary *)userInfo;
@end

/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFileTransfer is a class for performing asynchronous file copy/move operations using
//NSOperationQueue. It provides progress indication and sends periodic notifications and
//delegate messages on the main thread before, during and on completion of the operation.

#import <Foundation/Foundation.h>


typedef float BXFileTransferProgress;

#pragma mark -
#pragma mark Notification constants

//BXFileTransfer will post these notifications on the main thread,
//and to its delegate on the main thread.

//Sent when a file transfer operation is about to start,
//before any information is available about the size of the transfer.
extern NSString * const BXFileTransferWillStart;

//Sent periodically while a file transfer operation is in progress.
extern NSString * const BXFileTransferInProgress;

//Sent when a file transfer operation ends (be it in success or failure.)
extern NSString * const BXFileTransferDidFinish;

//Sent when a file transfer operation gets cancelled.
//The transfer will still send a BXFileTransferDidFinish after this.
extern NSString * const BXFileTransferWasCancelled;


#pragma mark -
#pragma mark Notification user info dictionary keys

//An arbitrary object representing the context for the file transfer operation.
//Included in all notifications, if contextInfo was set.
extern NSString * const BXFileTransferContextInfoKey;

//An NSNumber boolean indicating whether the transfer succeeded or failed.
//Included with BXFileTransferFinished.
extern NSString * const BXFileTransferSuccessKey;

//An NSError containing the details of a failed transfer.
//Included with BXFileTransferFinished if the transfer failed.
extern NSString * const BXFileTransferErrorKey;

//An NSNumber unsigned integer with the number of files that will be transferred.
//Included with BXFileTransferInProgress.
extern NSString * const BXFileTransferFileCountKey;

//An NSNumber unsigned long long with the total size in bytes of the files to be transferred.
//Included with BXFileTransferInProgress.
extern NSString * const BXFileTransferTotalSizeKey;

//An NSNumber float from 0.0 to 1.0 indicating the progress of the transfer.
//Included with BXFileTransferInProgress.
extern NSString * const BXFileTransferProgressKey;

//An NSString path indicating the current file being transferred.
//Included with BXFileTransferInProgress.
extern NSString * const BXFileTransferCurrentPathKey;


@protocol BXFileTransferDelegate;

@interface BXFileTransfer : NSOperation
{
	id <BXFileTransferDelegate> delegate;
	id contextInfo;
	BOOL notifyOnMainThread;

	NSFileManager *manager;
	FSFileOperationRef fileOp;
	BOOL isFinished;
	
	
	NSString *sourcePath;
	NSString *destinationPath;
	BOOL copyFiles;

	BXFileTransferProgress currentProgress;
	NSUInteger numFiles;
	NSUInteger filesTransferred;
	unsigned long long numBytes;
	unsigned long long bytesTransferred;
	NSString *currentPath;
	
	BOOL succeeded;
	NSError *error;
}

#pragma mark -
#pragma mark Configuration properties

//The delegate that will receive notification messages about this file operation.
@property (assign) id <BXFileTransferDelegate> delegate;

//Arbitrary context info for this operation. Included in notification dictionaries
//for controlling contexts to use. Note that this is an NSObject and will be retained.
@property (retain) id contextInfo;

//Whether delegate and NSNotificationCenter notifications should be sent on the main
//thread or on the operation's current thread. Defaults to YES (the main thread).
@property (assign) BOOL notifyOnMainThread;

//Whether this is a copy or move operation.
@property (assign) BOOL copyFiles;

//The source path to transfer from.
@property (copy) NSString *sourcePath;

//The destination path to transfer to.
@property (copy) NSString *destinationPath;


#pragma mark -
#pragma mark Operation status properties

//A float from 0.0 to 1.0 indicating how far through its process the file operation is.
@property (readonly) BXFileTransferProgress currentProgress;

//The number of files that will be copied in total.
@property (readonly) NSUInteger numFiles;

//The number of files that have been copied so far.
@property (readonly) NSUInteger filesTransferred;

//The number of bytes that will be copied in total, and have been copied so far.
@property (readonly) unsigned long long numBytes;
@property (readonly) unsigned long long bytesTransferred;

//Whether the operation succeeeded. Only relevant once isFinished is YES.
@property (readonly) BOOL succeeded;

//Any error that occurred when transferring files. Will be populated once the file operation finishes.
@property (readonly, retain) NSError *error;

//The file path of the current file being transferred.
@property (readonly, copy) NSString *currentPath;


#pragma mark -
#pragma mark Initialization

+ (id) transferFromPath: (NSString *)source
				 toPath: (NSString *)destination
			  copyFiles: (BOOL)copy;

- (id) initFromPath: (NSString *)source
			 toPath: (NSString *)destination
		  copyFiles: (BOOL)copy;

@end
/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFileTransfer is a class for performing asynchronous file copy/move operations using
//NSOperationQueue. It provides vague progress indication based on the number of files being
//transferred, and it sends notifications and delegate messages on the main thread when it
//starts transferring a new file and when it finishes the transfer operation.

#import <Cocoa/Cocoa.h>

typedef float BXFileTransferProgress;


#pragma mark -
#pragma mark Notification constants

//BXFileTransfer will post these notifications on the main thread,
//and to its delegate on the main thread.

//Sent when a file transfer operation is about to start,
//before information is available about the size of the transfer.
extern NSString * const BXFileTransferWillStart;

//Sent when a file transfer operation has begun.
extern NSString * const BXFileTransferDidStart;

//Sent when a file transfer operation ends.
extern NSString * const BXFileTransferDidFinish;

//Sent when a file transfer operation gets cancelled.
//The transfer will still send a BXFileTransferDidFinish after this.
extern NSString * const BXFileTransferWasCancelled;

//Sent periodically while a file transfer operation is in progress.
extern NSString * const BXFileTransferInProgress;


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
//Included with BXFileTransferDidStart.
extern NSString * const BXFileTransferFileCountKey;

//An NSNumber unsigned long long with the total size in bytes of the files to be transferred.
//Included with BXFileTransferDidStart.
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
	
	NSString *sourcePath;
	NSString *destinationPath;
	BOOL copyFiles;

	NSFileManager *manager;
	NSUInteger numFiles;
	NSUInteger numFilesTransferred;
	unsigned long long transferSize;
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
@property (readonly) NSUInteger numFilesTransferred;

//The number of bytes that will be copied in total.
@property (readonly) unsigned long long transferSize;

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

/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFileTransfer is a BXOperation subclass class for performing asynchronous file copy/move
//operations using NSOperationQueue. 


#import "BXOperation.h"

#pragma mark -
#pragma mark Notification user info dictionary keys

//NSNumber unsigned integers with the number of files total and transferred so far.
//Included with BXOperationInProgress.
extern NSString * const BXFileTransferFilesTotalKey;
extern NSString * const BXFileTransferFilesTransferredKey;

//NSNumber unsigned long longs with the size in bytes of the files in total and transferred so far.
//Included with BXOperationInProgress.
extern NSString * const BXFileTransferBytesTotalKey;
extern NSString * const BXFileTransferBytesTransferredKey;

//An NSString path indicating the current file being transferred.
//Included with BXOperationInProgress.
extern NSString * const BXFileTransferCurrentPathKey;


@interface BXFileTransfer : BXOperation
{
	BOOL copyFiles;
	NSString *sourcePath;
	NSString *destinationPath;
	
	NSFileManager *manager;
	FSFileOperationRef fileOp;
	FSFileOperationStage stage;	
	
	NSUInteger numFiles;
	NSUInteger filesTransferred;
	unsigned long long numBytes;
	unsigned long long bytesTransferred;
	NSString *currentPath;
}

#pragma mark -
#pragma mark Configuration properties

//Whether this is a copy or move operation.
@property (assign) BOOL copyFiles;

//The full source path to transfer from.
@property (copy) NSString *sourcePath;

//The full destination path to transfer to, including filename.
@property (copy) NSString *destinationPath;


#pragma mark -
#pragma mark Operation status properties

//The number of files that will be copied in total.
@property (readonly) NSUInteger numFiles;

//The number of files that have been copied so far.
@property (readonly) NSUInteger filesTransferred;

//The number of bytes that will be copied in total, and have been copied so far.
@property (readonly) unsigned long long numBytes;
@property (readonly) unsigned long long bytesTransferred;

//The file path of the current file being transferred.
@property (readonly, copy) NSString *currentPath;


#pragma mark -
#pragma mark Initialization

//Create/initialize a suitable file transfer operation from the specified source path
//to the specified destination.
+ (id) transferFromPath: (NSString *)source
				 toPath: (NSString *)destination
			  copyFiles: (BOOL)copy;

- (id) initFromPath: (NSString *)source
			 toPath: (NSString *)destination
		  copyFiles: (BOOL)copy;

@end
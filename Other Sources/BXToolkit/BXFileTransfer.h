/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFileTransfer is an interface for BXOperations implemented by BXSingleFileTransfer
//and BXMultiFileTransfer (which have different parent classes.)

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


#pragma mark -
#pragma mark Interface

@protocol BXFileTransfer <NSObject>

//Whether this is a copy or move operation.
@property (assign) BOOL copyFiles;

//The number of files that will be copied in total.
@property (readonly) NSUInteger numFiles;

//The number of files that have been copied so far.
@property (readonly) NSUInteger filesTransferred;

//The number of bytes that will be copied in total, and have been copied so far.
@property (readonly) unsigned long long numBytes;
@property (readonly) unsigned long long bytesTransferred;

//The file path of the current file being transferred,
//or nil if no path is currently being transferred.
@property (readonly, copy) NSString *currentPath;

//Undo the file operation. Called automatically if the operation is cancelled
//or encounters an unrecoverable error.
- (void) undoTransfer;
@end

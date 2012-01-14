/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
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

//Whether the files in the transfer should be copied or moved.
- (BOOL) copyFiles;
- (void) setCopyFiles: (BOOL)copy;

//The number of bytes that will be copied in total, and have been copied so far.
- (unsigned long long) numBytes;
- (unsigned long long) bytesTransferred;

//Undo the file operation. Called automatically if the operation is cancelled
//or encounters an unrecoverable error.
//Returns YES if the transfer was undone, NO if there was nothing to undo
//(e.g. the operation hadn't successfully copied anything.)
- (BOOL) undoTransfer;

//The number of files that will be copied in total.
- (NSUInteger) numFiles;

//The number of files that have been copied so far.
- (NSUInteger) filesTransferred;

//The file path of the current file being transferred,
//or nil if no path is currently being transferred (or this cannot be determined.)
- (NSString *) currentPath;

@end

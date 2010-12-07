/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXMultiFileTransfer manages the transfer of a set of files to a set of destinations in a single
//operation, reporting on the progress of the operation as a whole.

#import "BXOperationSet.h"

@interface BXMultiFileTransfer : BXOperationSet
{
	BOOL copyFiles;
	NSDictionary *pathsToTransfer;
}

#pragma mark -
#pragma mark Configuration properties

//Whether this is a copy or move operation.
//This applies to all paths being transferred.
@property (assign) BOOL copyFiles;

//A map of source paths to destination paths.
//This is not safe to modify once the operation has been started.
@property (copy, nonatomic) NSDictionary *pathsToTransfer;


#pragma mark -
#pragma mark Operation status properties

//The number of files that will be copied in total across all operations.
@property (readonly) NSUInteger numFiles;

//The number of files that have been copied so far across all operations.
@property (readonly) NSUInteger filesTransferred;

//The number of bytes that will be copied in total across all operations,
//and which have been copied so far.
@property (readonly) unsigned long long numBytes;
@property (readonly) unsigned long long bytesTransferred;

//The file path of the current file being transferred,
//or nil if no file is being transferred.
//This currently returns the file path of the first active file transfer.
@property (readonly) NSString *currentPath;


#pragma mark -
#pragma mark Initialization


//Create/initialize a suitable file transfer operation for the specified
//source->destination mappings.
+ (id) transferForPaths: (NSDictionary *)paths
			  copyFiles: (BOOL)copy;

- (id) initForPaths: (NSDictionary *)paths
		  copyFiles: (BOOL)copy;

@end
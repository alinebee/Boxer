/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFileTransfer is a BXOperation subclass class for performing asynchronous file copy/move
//operations using NSOperationQueue. BXFileTransfer transfers only a single file/directory
//to a single destination: see also BXMultiFileTransfer for a batch transfer operation.


#import "BXOperation.h"
#import "BXFileTransfer.h"

@interface BXSingleFileTransfer : BXOperation <BXFileTransfer>
{
	BOOL _copyFiles;
	NSString *_sourcePath;
	NSString *_destinationPath;
	
	NSFileManager *_manager;
	FSFileOperationRef _fileOp;
	FSFileOperationStage _stage;
	
	NSUInteger _numFiles;
	NSUInteger _filesTransferred;
	unsigned long long _numBytes;
	unsigned long long _bytesTransferred;
	NSString *_currentPath;
	
	NSTimeInterval _pollInterval;
	
	BOOL _hasCreatedFiles;
}

#pragma mark -
#pragma mark Configuration properties

//The full source path to transfer from.
@property (copy) NSString *sourcePath;

//The full destination path to transfer to, including filename.
@property (copy) NSString *destinationPath;

//The interval at which to check the progress of our dependent operations and
//issue overall progress updates.
//BXOperationSet's overall running time will be a multiple of this interval.
@property (assign) NSTimeInterval pollInterval;

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

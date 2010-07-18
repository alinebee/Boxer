/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFileTransfer is a class for performing asynchronous file copy/move operations,
//with loose progress tracking based on the number of files in the copy.

#import <Cocoa/Cocoa.h>

typedef float BXFileTransferProgress;

@interface BXFileTransfer : NSOperation
{
	NSString *sourcePath;
	NSString *destinationPath;
	BOOL copyFiles;

	NSFileManager *manager;
	NSUInteger numFiles;
	NSUInteger numFilesTransferred;
	NSString *currentPath;
	
	BOOL succeeded;
	NSError *error;
}

#pragma mark -
#pragma mark Configuration properties

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

//Whether the operation succeeeded. Only relevant once isFinished is YES.
@property (readonly) BOOL succeeded;

//Any error that occurred when transferring files. Will be populated once the file operation finishes.
@property (readonly, retain) NSError *error;

//The file path of the current file being transferred.
@property (readonly, copy) NSString *currentPath;


#pragma mark -
#pragma mark Initialzation

+ (id) transferFromPath: (NSString *)source
				 toPath: (NSString *)destination
			  copyFiles: (BOOL)copy;

- (id) initFromPath: (NSString *)source
			 toPath: (NSString *)destination
		  copyFiles: (BOOL)copy;

@end

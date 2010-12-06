/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXMultiFileTransfer.h"
#import "BXOperationDelegate.h"
#import "BXFileTransfer.h"

@implementation BXMultiFileTransfer
@synthesize pathsToTransfer, copyFiles;

#pragma mark -
#pragma mark Initialization and deallocation

+ (id) transferForPaths: (NSDictionary *)paths
			  copyFiles: (BOOL)copy
{
	return [[[self alloc] initForPaths: paths copyFiles: copy] autorelease];
}


- (id) init
{
	if ((self = [super init]))
	{
		transferQueue = [[NSOperationQueue alloc] init];
	}
	return self;
}

- (id) initForPaths: (NSDictionary *)paths copyFiles: (BOOL)copy
{
	if ((self = [self init]))
	{
		[self setPathsToTransfer: paths];
		[self setCopyFiles: copy];
	}
	return self;
}

- (void) dealloc
{
	[self setPathsToTransfer: nil], [pathsToTransfer release];
	
	[transferQueue release], transferQueue = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark Performing the transfer

- (BXOperationProgress) currentProgress
{
	//If we haven't begun yet, return an indeterminate result.
	if (![self numBytes]) return BXOperationProgressIndeterminate;
	
	//If not all of our file operations know where they're at yet, return an indeterminate result.
	for (BXFileTransfer *transfer in [transferQueue operations])
	{
		if ([transfer currentProgress] == BXOperationProgressIndeterminate) return BXOperationProgressIndeterminate;
	}
	
	return (BXOperationProgress)[self bytesTransferred] / (BXOperationProgress)[self numBytes];
}

- (unsigned long long) numBytes
{
	unsigned long long bytes = 0;
	for (BXFileTransfer *operation in [transferQueue operations])
	{
		bytes += [operation numBytes];
	}
	return bytes;
}

- (unsigned long long) bytesTransferred
{
	unsigned long long bytes = 0;
	for (BXFileTransfer *operation in [transferQueue operations])
	{
		bytes += [operation bytesTransferred];
	}
	return bytes;
}

- (NSUInteger) numFiles
{
	NSUInteger files = 0;
	for (BXFileTransfer *operation in [transferQueue operations])
	{
		files += [operation numFiles];
	}
	return files;
}

- (NSUInteger) filesTransferred
{
	NSUInteger files = 0;
	for (BXFileTransfer *operation in [transferQueue operations])
	{
		files += [operation filesTransferred];
	}
	return files;
}

- (NSString *) currentPath
{
	for (BXFileTransfer *transfer in [transferQueue operations])
	{
		if ([transfer isExecuting]) return [transfer currentPath];
	}
	return nil;
}


- (void) main
{
	[self setError: nil];

	[self _sendWillStartNotificationWithInfo: nil];
	
	//Queue up all transfer operations before letting them all start at once
	[transferQueue setSuspended: YES];
	
	for (NSString *sourcePath in [[self pathsToTransfer] allKeys])
	{
		NSString *destinationPath = [[self pathsToTransfer] objectForKey: sourcePath];
		
		BXFileTransfer *transfer = [BXFileTransfer transferFromPath: sourcePath
															 toPath: destinationPath
														  copyFiles: copyFiles];
		[transfer setDelegate: self];
		
		[transferQueue addOperation: transfer];
	}
	
	[transferQueue setSuspended: NO];
	[transferQueue waitUntilAllOperationsAreFinished];
	
	for (BXFileTransfer *transfer in [transferQueue operations])
	{
		if ([transfer error])
		{
			[self setError: error];
			break;
		}
	}
	[self setSucceeded: [self error] == nil];
	
	[self _sendDidFinishNotificationWithInfo: nil];
}

- (void) operationInProgress: (NSNotification *)notification
{
	//Post a notification whenever one of our own operations issues a progress update
	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
						  [NSNumber numberWithUnsignedInteger:	[self filesTransferred]],	BXFileTransferFilesTransferredKey,
						  [NSNumber numberWithUnsignedLongLong:	[self bytesTransferred]],	BXFileTransferBytesTransferredKey,
						  [NSNumber numberWithUnsignedInteger:	[self numFiles]],			BXFileTransferFilesTotalKey,
						  [NSNumber numberWithUnsignedLongLong:	[self numBytes]],			BXFileTransferBytesTotalKey,
						  [self currentPath], BXFileTransferCurrentPathKey,
						  nil];
	
	[self _sendInProgressNotificationWithInfo: info];
}
@end
/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXFileTransfer.h"

#pragma mark -
#pragma mark Notification constants and keys

NSString * const BXFileTransferFilesTotalKey		= @"BXFileTransferFilesTotalKey";
NSString * const BXFileTransferFilesTransferredKey	= @"BXFileTransferFilesTransferredKey";
NSString * const BXFileTransferBytesTotalKey		= @"BXFileTransferBytesTotalKey";
NSString * const BXFileTransferBytesTransferredKey	= @"BXFileTransferBytesTransferredKey";
NSString * const BXFileTransferCurrentPathKey		= @"BXFileTransferCurrentPathKey";


//The interval in seconds at which to poll the progress of the file transfer
#define BXFileTransferPollInterval 0.5


#pragma mark -
#pragma mark Private method declarations

@interface BXFileTransfer ()

@property (readwrite) unsigned long long numBytes;
@property (readwrite) unsigned long long bytesTransferred;
@property (readwrite) NSUInteger numFiles;
@property (readwrite) NSUInteger filesTransferred;
@property (readwrite, copy) NSString *currentPath;

//Returns whether we can start the transfer. Should also populate @error (but currently doesn't).
- (BOOL) _canBeginTransfer;

//Start up the FSFileOperation.
- (void) _beginTransfer;

//Called periodically by a timer, to check the progress of the FSFileOperation.
- (void) _checkTransferProgress;

//Clean up after a partial transfer.
- (void) _undoTransfer;

@end


#pragma mark -
#pragma mark Implementation

@implementation BXFileTransfer
@synthesize copyFiles, sourcePath, destinationPath;
@synthesize numFiles, filesTransferred, numBytes, bytesTransferred, currentPath;

#pragma mark -
#pragma mark Initialization and deallocation

- (id) init
{
	if ((self = [super init]))
	{
		fileOp = FSFileOperationCreate(kCFAllocatorDefault);
		
		//Maintain our own NSFileManager instance to ensure thread safety
		manager = [[NSFileManager alloc] init];
	}
	return self;
}

- (id) initFromPath: (NSString *)source toPath: (NSString *)destination copyFiles: (BOOL)copy
{
	if ((self = [self init]))
	{
		[self setSourcePath: source];
		[self setDestinationPath: destination];
		[self setCopyFiles: copy];
	}
	return self;
}

+ (id) transferFromPath: (NSString *)source toPath: (NSString *)destination copyFiles: (BOOL)copy
{
	return [[[self alloc] initFromPath: source toPath: destination copyFiles: copy] autorelease];
}

- (void) dealloc
{
	CFRelease(fileOp);
	[manager release], manager = nil;
	
	[self setCurrentPath: nil],		[currentPath release];
	[self setSourcePath: nil],		[sourcePath release];
	[self setDestinationPath: nil],	[destinationPath release];
	
	[super dealloc];
}


#pragma mark -
#pragma mark Performing the transfer

- (BXOperationProgress) currentProgress
{
	return (BXOperationProgress)bytesTransferred / (BXOperationProgress)numBytes;
}


- (void) main
{
	if (![self _canBeginTransfer]) return;
	
	[self _sendWillStartNotificationWithInfo: nil];
	
	[self setError: nil];
	
	//Start up the file transfer
	[self _beginTransfer];
	
	//Use a timer to poll the FSFileOperation
	NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval: BXFileTransferPollInterval
													  target: self
													selector: @selector(_checkTransferProgress)
													userInfo: NULL
													 repeats: YES];
	
	//Run the runloop until the transfer is finished
	while (stage != kFSOperationStageComplete && [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
												   beforeDate: [NSDate dateWithTimeIntervalSinceNow: BXFileTransferPollInterval]])
	{
		//Cancel the file operation if we've been cancelled in the meantime
		//(this will break out of the loop once the file operation finishes) 
		if ([self isCancelled]) FSFileOperationCancel(fileOp);
	}
	[timer invalidate];
	
	[self setSucceeded: [self error] == nil];
	
	if ([self error])
	{
		//Clean up after ourselves
		[self _undoTransfer];
	}
	
	[self _sendDidFinishNotificationWithInfo: nil];
}

- (BOOL) _canBeginTransfer
{
	//TODO: set errors from these cases
	
	//Sanity checks: if we have no source or destination path or we're already cancelled, bail out now.
	if ([self isCancelled] || ![self sourcePath] || ![self destinationPath]) return NO;
	
	//Don't start if the source path doesn't exist or the destination path does exist.
	if (![manager fileExistsAtPath: [self sourcePath]]) return NO;
	if ([manager fileExistsAtPath: [self destinationPath]]) return NO;
	
	//Otherwise, we're good to go
	return YES;
}

- (void) _beginTransfer
{
	OSStatus status;
	status = FSFileOperationScheduleWithRunLoop(fileOp, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	NSAssert1(!status, @"Could not schedule file operation in current run loop, FSFileOperationScheduleWithRunLoop returned error code: %i", status);
	
	const char *srcPath = [[self sourcePath] fileSystemRepresentation];
	//FSPathCopyObjectAsync expects the destination base path and filename to be provided separately
	const char *destPath = [[[self destinationPath] stringByDeletingLastPathComponent] fileSystemRepresentation];
	CFStringRef destName = (CFStringRef)[[self destinationPath] lastPathComponent];
	
	stage = kFSOperationStageUndefined;
	
	if (copyFiles)
	{
		status = FSPathCopyObjectAsync(fileOp,		//Our file operation object
									   srcPath,		//The full path to the source file
									   destPath,	//The path to the destination folder
									   destName,	//The destination filename
									   kFSFileOperationDefaultOptions,	//File operation flags
									   NULL,
									   0.0,
									   NULL);
		
		NSAssert1(!status, @"Could not start file operation, FSPathCopyObjectAsync returned error code: %i", status);		
	}
	else
	{
		status = FSPathMoveObjectAsync(fileOp,		//Our file operation object
									   srcPath,		//The full path to the source file
									   destPath,	//The path to the destination folder
									   destName,	//The destination filename
									   kFSFileOperationDefaultOptions,	//File operation flags
									   NULL,
									   0.0,
									   NULL);
		
		NSAssert1(!status, @"Could not start file operation, FSPathMoveObjectAsync returned error code: %i", status);		
	}
}

- (void) _undoTransfer
{
	//Delete the destination path to clean up
	//TODO: for move operations, we should put the files back.
	if (copyFiles) [manager removeItemAtPath: [self destinationPath] error: nil];
}

- (void) _checkTransferProgress
{	
	char *currentItem = NULL;
	CFDictionaryRef statusInfo = NULL;
	OSStatus errorCode = noErr;
	
	OSStatus status = FSPathFileOperationCopyStatus(fileOp,
													&currentItem,
													&stage,
													&errorCode,
													&statusInfo,
													NULL);
	
	NSAssert1(!status, @"Could not get file operation status, FSPathFileOperationCopyStatus returned error code: %i", status);
	
	if (errorCode)
	{
		[self setError: [NSError errorWithDomain: NSOSStatusErrorDomain code: errorCode userInfo: nil]];
	}
	
	if (currentItem)
	{
		[self setCurrentPath: [manager stringWithFileSystemRepresentation: currentItem length: strlen(currentItem)]];
	}
	
	if (statusInfo)
	{
		CFNumberRef cfBytes				= CFDictionaryGetValue(statusInfo, kFSOperationTotalBytesKey);
		CFNumberRef cfBytesTransferred	= CFDictionaryGetValue(statusInfo, kFSOperationBytesCompleteKey);
		CFNumberRef cfFiles				= CFDictionaryGetValue(statusInfo, kFSOperationTotalObjectsKey);
		CFNumberRef cfFilesTransferred	= CFDictionaryGetValue(statusInfo, kFSOperationObjectsCompleteKey);
		
		[self setNumBytes:			[(NSNumber *)cfBytes unsignedLongLongValue]];
		[self setBytesTransferred:	[(NSNumber *)cfBytesTransferred unsignedLongLongValue]];
		[self setNumFiles:			[(NSNumber *)cfFiles unsignedIntegerValue]];
		[self setFilesTransferred:	[(NSNumber *)cfFilesTransferred unsignedIntegerValue]];
		
		CFRelease(statusInfo);
	}
	
	if (stage == kFSOperationStageRunning)
	{
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
							  [NSNumber numberWithUnsignedInteger: [self filesTransferred]],	BXFileTransferFilesTransferredKey,
							  [NSNumber numberWithUnsignedLongLong: [self bytesTransferred]],	BXFileTransferBytesTransferredKey,
							  [NSNumber numberWithUnsignedInteger: [self numFiles]],			BXFileTransferFilesTotalKey,
							  [NSNumber numberWithUnsignedLongLong: [self numBytes]],			BXFileTransferBytesTotalKey,
							  [self currentPath], BXFileTransferCurrentPathKey,
							  nil];
		[self _sendInProgressNotificationWithInfo: info];
	}
}

@end
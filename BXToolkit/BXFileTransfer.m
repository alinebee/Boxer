/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXFileTransfer.h"
#import "BXFileTransferDelegate.h"

#pragma mark -
#pragma mark Notification constants and keys

NSString * const BXFileTransferWillStart		= @"BXFileTransferWillStart";
NSString * const BXFileTransferDidFinish		= @"BXFileTransferDidFinish";
NSString * const BXFileTransferInProgress		= @"BXFileTransferInProgress";
NSString * const BXFileTransferWasCancelled		= @"BXFileTransferWasCancelled";

NSString * const BXFileTransferContextInfoKey	= @"BXFileTransferContextInfoKey";
NSString * const BXFileTransferSuccessKey		= @"BXFileTransferSuccessKey";
NSString * const BXFileTransferErrorKey			= @"BXFileTransferErrorKey";
NSString * const BXFileTransferFileCountKey		= @"BXFileTransferFileCountKey";
NSString * const BXFileTransferTotalSizeKey		= @"BXFileTransferTotalSizeKey";
NSString * const BXFileTransferProgressKey		= @"BXFileTransferProgressKey";
NSString * const BXFileTransferCurrentPathKey	= @"BXFileTransferCurrentPathKey";


//The interval in seconds at which to poll the progress of the file transfer
#define BXFileTransferPollInterval 0.5

#pragma mark -
#pragma mark Private method declarations

@interface BXFileTransfer ()

@property (readwrite) BXFileTransferProgress currentProgress;
@property (readwrite) unsigned long long numBytes;
@property (readwrite) unsigned long long bytesTransferred;
@property (readwrite) NSUInteger numFiles;
@property (readwrite) NSUInteger filesTransferred;
@property (readwrite, copy) NSString *currentPath;
@property (readwrite) BOOL succeeded;
@property (readwrite, retain) NSError *error;

//Returns whether we can start the transfer. Should also populate @error (but currently doesn't).
- (BOOL) _canBeginTransfer;

//Start up the FSFileOperation.
- (void) _beginTransfer;

//Called periodically by a timer, to check the progress of the FSFileOperation.
- (void) _checkTransferProgress;

//Clean up after a partial transfer.
- (void) _undoTransfer;

//Post one of the corresponding notifications.
- (void) _sendWillStartNotification;
- (void) _sendInProgressNotification;
- (void) _sendWasCancelledNotification;
- (void) _sendDidFinishNotification;

//Shortcut method for sending a notification both to the default notification center
//and to a selector on our delegate. The object of the notification will be self.
- (void) _postNotificationName: (NSString *)name
			  delegateSelector: (SEL)selector
					  userInfo: (NSDictionary *)userInfo;
@end


#pragma mark -
#pragma mark Implementation

@implementation BXFileTransfer
@synthesize delegate, contextInfo, notifyOnMainThread;
@synthesize copyFiles, sourcePath, destinationPath;
@synthesize currentProgress, numFiles, filesTransferred, numBytes, bytesTransferred, currentPath;
@synthesize succeeded, error;

#pragma mark -
#pragma mark Initialization and deallocation

- (id) init
{
	if ((self = [super init]))
	{
		[self setNotifyOnMainThread: YES];
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
	
	[self setContextInfo: nil],		[contextInfo release];
	[self setError: nil],			[error release];
	[self setCurrentPath: nil],		[currentPath release];
	[self setSourcePath: nil],		[sourcePath release];
	[self setDestinationPath: nil],	[destinationPath release];
	
	[super dealloc];
}


#pragma mark -
#pragma mark Performing the transfer

- (void) main
{
	if (![self _canBeginTransfer]) return;
	
	[self _sendWillStartNotification];
	
	isFinished = NO;
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
	while (!isFinished && [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
												   beforeDate: [NSDate dateWithTimeIntervalSinceNow: BXFileTransferPollInterval]])
	{
		//Cancel the file operation if we've been cancelled in the meantime
		//(this will break out of the loop once the file operation finishes) 
		if ([self isCancelled])
		{
			FSFileOperationCancel(fileOp);
		}
	}
	[timer invalidate];
	
	[self setSucceeded: [self error] == nil];
	
	if ([self error])
	{
		//Clean up after ourselves
		[self _undoTransfer];
	}
	
	[self _sendDidFinishNotification];
}


- (void) cancel
{	
	//Only send a notification the first time we're cancelled,
	//and only if we're in progress when we get cancelled
	if (![self isCancelled] && [self isExecuting])
	{
		[super cancel];
		if (![self error])
		{
			//If we haven't encountered a more serious error, set the error to indicate that this operation was cancelled.
			[self setError: [NSError errorWithDomain: NSCocoaErrorDomain
												code: NSUserCancelledError
											userInfo: nil]];
		}
		[self _sendWasCancelledNotification];
	}
	else [super cancel];
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
	FSFileOperationStage stage = 0;
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
		
		[self setCurrentProgress: (BXFileTransferProgress)bytesTransferred / (BXFileTransferProgress)numBytes];
		
		CFRelease(statusInfo);
	}
	
	switch (stage)
	{
		case kFSOperationStageRunning:
			[self _sendInProgressNotification];
			break;
		case kFSOperationStageComplete:
			isFinished = YES; //This will break out of the timer loop back in -main
			break;
		default:
			break;
	}
}


#pragma mark -
#pragma mark Notifications

- (void) _sendWillStartNotification
{
	if ([self isCancelled]) return;

	[self _postNotificationName: BXFileTransferWillStart
			   delegateSelector: @selector(fileTransferWillStart:)
					   userInfo: nil];
}

- (void) _sendWasCancelledNotification
{
	[self _postNotificationName: BXFileTransferWasCancelled
			   delegateSelector: @selector(fileTransferWasCancelled:)
					   userInfo: nil];
}

- (void) _sendDidFinishNotification
{
	NSDictionary *finishInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								[NSNumber numberWithBool: [self succeeded]], BXFileTransferSuccessKey,
								[self error], BXFileTransferErrorKey,
								nil];
	
	[self _postNotificationName: BXFileTransferDidFinish
			   delegateSelector: @selector(fileTransferDidFinish:)
					   userInfo: finishInfo];
}

- (void) _sendInProgressNotification
{
	if ([self isCancelled]) return;
	
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  [NSNumber numberWithUnsignedInteger: [self numFiles]], BXFileTransferFileCountKey,
							  [NSNumber numberWithUnsignedLongLong: [self numBytes]], BXFileTransferTotalSizeKey,
							  [NSNumber numberWithFloat: [self currentProgress]], BXFileTransferProgressKey,
							  [self currentPath], BXFileTransferCurrentPathKey,
							  nil];
	
	[self _postNotificationName: BXFileTransferInProgress
			   delegateSelector: @selector(fileTransferInProgress:)
					   userInfo: userInfo];
}


- (void) _postNotificationName: (NSString *)name
			  delegateSelector: (SEL)selector
					  userInfo: (NSDictionary *)userInfo
{
	//Extend the notification dictionary with context info, if context was provided
	if ([self contextInfo])
	{
		NSMutableDictionary *extendedInfo = [NSMutableDictionary dictionaryWithObject: [self contextInfo] forKey: BXFileTransferContextInfoKey];
		if (userInfo) [extendedInfo addEntriesFromDictionary: userInfo];
		userInfo = extendedInfo;
	}
	
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	NSNotification *notification = [NSNotification notificationWithName: name
																 object: self
															   userInfo: userInfo];
	
	if ([[self delegate] respondsToSelector: selector])
	{
		if ([self notifyOnMainThread])
			[(id)[self delegate] performSelectorOnMainThread: selector withObject: notification waitUntilDone: NO];
		else
			[[self delegate] performSelector: selector withObject: notification];
	}
		
	if ([self notifyOnMainThread])
		[center performSelectorOnMainThread: @selector(postNotification:) withObject: notification waitUntilDone: NO];		
	else
		[center postNotification: notification];
}
@end
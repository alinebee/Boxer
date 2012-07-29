/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSingleFileTransfer.h"

#pragma mark -
#pragma mark Notification constants and keys

NSString * const BXFileTransferFilesTotalKey		= @"BXFileTransferFilesTotalKey";
NSString * const BXFileTransferFilesTransferredKey	= @"BXFileTransferFilesTransferredKey";
NSString * const BXFileTransferBytesTotalKey		= @"BXFileTransferBytesTotalKey";
NSString * const BXFileTransferBytesTransferredKey	= @"BXFileTransferBytesTransferredKey";
NSString * const BXFileTransferCurrentPathKey		= @"BXFileTransferCurrentPathKey";



#pragma mark -
#pragma mark Private method declarations

@interface BXSingleFileTransfer ()

@property (readwrite) unsigned long long numBytes;
@property (readwrite) unsigned long long bytesTransferred;
@property (readwrite) NSUInteger numFiles;
@property (readwrite) NSUInteger filesTransferred;
@property (readwrite, copy) NSString *currentPath;

//Start up the FSFileOperation. Returns NO and populates @error if the transfer could not be started.
- (BOOL) _beginTransfer;

//Called periodically by a timer, to check the progress of the FSFileOperation.
- (void) _checkTransferProgress;

@end


#pragma mark -
#pragma mark Implementation

@implementation BXSingleFileTransfer
@synthesize copyFiles = _copyFiles, pollInterval = _pollInterval;
@synthesize sourcePath = _sourcePath, destinationPath = _destinationPath, currentPath = _currentPath;
@synthesize numFiles = _numFiles, filesTransferred = _filesTransferred;
@synthesize numBytes = _numBytes, bytesTransferred = _bytesTransferred;


#pragma mark -
#pragma mark Initialization and deallocation

- (id) init
{
	if ((self = [super init]))
	{
		_fileOp = FSFileOperationCreate(kCFAllocatorDefault);
		
		_pollInterval = BXFileTransferDefaultPollInterval;
		
		//Maintain our own NSFileManager instance to ensure thread safety
		_manager = [[NSFileManager alloc] init];
	}
	return self;
}

- (id) initFromPath: (NSString *)sourcePath toPath: (NSString *)destinationPath copyFiles: (BOOL)copyFiles
{
	if ((self = [self init]))
	{
        self.sourcePath = sourcePath;
        self.destinationPath = destinationPath;
        self.copyFiles = copyFiles;
	}
	return self;
}

+ (id) transferFromPath: (NSString *)sourcePath toPath: (NSString *)destinationPath copyFiles: (BOOL)copyFiles
{
	return [[[self alloc] initFromPath: sourcePath
								toPath: destinationPath
							 copyFiles: copyFiles] autorelease];
}

- (void) dealloc
{
	CFRelease(_fileOp);
	[_manager release], _manager = nil;
	
    self.currentPath = nil;
    self.sourcePath = nil;
    self.destinationPath = nil;
	
	[super dealloc];
}


#pragma mark -
#pragma mark Performing the transfer

+ (NSSet *) keyPathsForValuesAffectingCurrentProgress
{
	return [NSSet setWithObjects: @"numBytes", @"bytesTransferred", nil];
}

- (BXOperationProgress) currentProgress
{
	if (self.numBytes > 0)
	{
		return (BXOperationProgress)self.bytesTransferred / (BXOperationProgress)self.numBytes;		
	}
	else return 0;
}

+ (NSSet *) keyPathsForValuesAffectingIndeterminate
{
	return [NSSet setWithObject: @"numBytes"];
}

- (BOOL) isIndeterminate
{
	return self.numBytes == 0;
}

- (void) performOperation
{	
	//Start up the file transfer, bailing out if it could not be started
	if ([self _beginTransfer])
    {
        //Use a timer to poll the FSFileOperation. (This also keeps the runloop below alive.)
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval: self.pollInterval
                                                          target: self
                                                        selector: @selector(_checkTransferProgress)
                                                        userInfo: NULL
                                                         repeats: YES];
        
        //Run the runloop until the transfer is finished, letting the timer call our polling function.
        //We use a runloop instead of just sleeping, because the runloop lets cancellation messages
        //get dispatched to us correctly.)
        while (_stage != kFSOperationStageComplete && [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                                                                               beforeDate: [NSDate dateWithTimeIntervalSinceNow: self.pollInterval]])
        {
            //Cancel the file operation if we've been cancelled in the meantime
            //(this will break out of the loop once the file operation finishes)
            if (self.isCancelled)
                FSFileOperationCancel(_fileOp);
        }
        
        [timer invalidate];
	}
}

- (BOOL) shouldPerformOperation
{	
    if (!super.shouldPerformOperation) return NO;
    
	//Sanity checks: if we have no source or destination path, bail out now.
	if (!self.sourcePath || !self.destinationPath) return NO;
	
	//Don't start if the source path doesn't exist.
	if (![_manager fileExistsAtPath: self.sourcePath])
	{
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject: self.sourcePath forKey: NSFilePathErrorKey];
		NSError *noSourceError = [NSError errorWithDomain: NSCocoaErrorDomain
													 code: NSFileNoSuchFileError
												 userInfo: userInfo];
		self.error = noSourceError;
		return NO;
	}
	
	//...or if the destination path *does* exist.
	if ([_manager fileExistsAtPath: self.destinationPath])
	{
		//TODO: check if there's a better error code to use here
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject: self.destinationPath forKey: NSFilePathErrorKey];
		NSError *destinationExistsError = [NSError errorWithDomain: NSCocoaErrorDomain
															  code: NSFileWriteNoPermissionError
														  userInfo: userInfo];
		self.error = destinationExistsError;
		return NO;
	}
	
	//Otherwise, we're good to go
	return YES;
}

- (BOOL) _beginTransfer
{
	OSStatus status;
	status = FSFileOperationScheduleWithRunLoop(_fileOp, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	NSAssert1(!status, @"Could not schedule file operation in current run loop, FSFileOperationScheduleWithRunLoop returned error code: %li", status);
	
	NSString *destinationBase = self.destinationPath.stringByDeletingLastPathComponent;
	
	//If the destination base folder does not yet exist, create it and any intermediate directories
	if (![_manager fileExistsAtPath: destinationBase])
	{
		NSError *dirError = nil;
		BOOL created = [_manager createDirectoryAtPath: destinationBase
						   withIntermediateDirectories: YES
											attributes: nil
												 error: &dirError];
		if (created)
		{
			_hasCreatedFiles = YES;
		}
		else
		{
			self.error = dirError;
			return NO;
		}
	}
	
	const char *srcPath = self.sourcePath.fileSystemRepresentation;
	//FSPathCopyObjectAsync expects the destination base path and filename to be provided separately
	const char *destPath = destinationBase.fileSystemRepresentation;
	CFStringRef destName = (CFStringRef)(self.destinationPath.lastPathComponent);
	
	_stage = kFSOperationStageUndefined;
	
	if ([self copyFiles])
	{
		status = FSPathCopyObjectAsync(_fileOp,		//Our file operation object
									   srcPath,		//The full path to the source file
									   destPath,	//The path to the destination folder
									   destName,	//The destination filename
									   kFSFileOperationDefaultOptions,	//File operation flags
									   NULL,
									   0.0,
									   NULL);
		
		//NSAssert1(!status, @"Could not start file operation, FSPathCopyObjectAsync returned error code: %i", status);		
	}
	else
	{
		status = FSPathMoveObjectAsync(_fileOp,		//Our file operation object
									   srcPath,		//The full path to the source file
									   destPath,	//The path to the destination folder
									   destName,	//The destination filename
									   kFSFileOperationDefaultOptions,	//File operation flags
									   NULL,
									   0.0,
									   NULL);
		
		//NSAssert1(!status, @"Could not start file operation, FSPathMoveObjectAsync returned error code: %i", status);		
	}

	if (status != noErr)
	{
		//TODO: use this as the underlying error, wrapped inside a more legible human-friendly error
		NSError *FSError = [NSError errorWithDomain: NSOSStatusErrorDomain code: status userInfo: nil];
		[self setError: FSError];
		return NO;
	}
	
	return YES;
}

- (BOOL) undoTransfer
{
	//Delete the destination path to clean up
	//TODO: for move operations, we should put the files back.
	if (_hasCreatedFiles && self.copyFiles)
	{
		return [_manager removeItemAtPath: self.destinationPath error: nil];
	}
    else return NO;
}

- (void) _checkTransferProgress
{	
	char *currentItem = NULL;
	CFDictionaryRef statusInfo = NULL;
	OSStatus errorCode = noErr;
	
	OSStatus status = FSPathFileOperationCopyStatus(_fileOp,
													&currentItem,
													&_stage,
													&errorCode,
													&statusInfo,
													NULL);
	
	//NSAssert1(!status, @"Could not get file operation status, FSPathFileOperationCopyStatus returned error code: %i", status);
	
	if (status && status != userCanceledErr)
	{
		self.error = [NSError errorWithDomain: NSOSStatusErrorDomain code: status userInfo: nil];
	}
	
	if (errorCode && errorCode != userCanceledErr)
	{
		self.error = [NSError errorWithDomain: NSOSStatusErrorDomain code: errorCode userInfo: nil];
	}
	
	if (currentItem)
	{
		self.currentPath = [_manager stringWithFileSystemRepresentation: currentItem length: strlen(currentItem)];
	}
	
	if (statusInfo)
	{
		NSNumber *bytes				= (NSNumber *)CFDictionaryGetValue(statusInfo, kFSOperationTotalBytesKey);
		NSNumber *bytesTransferred	= (NSNumber *)CFDictionaryGetValue(statusInfo, kFSOperationBytesCompleteKey);
		NSNumber *files				= (NSNumber *)CFDictionaryGetValue(statusInfo, kFSOperationTotalObjectsKey);
		NSNumber *filesTransferred	= (NSNumber *)CFDictionaryGetValue(statusInfo, kFSOperationObjectsCompleteKey);
		
		self.numBytes           = bytes.unsignedLongLongValue;
		self.bytesTransferred   = bytesTransferred.unsignedLongLongValue;
		self.numFiles           = files.unsignedIntegerValue;
		self.filesTransferred   = filesTransferred.unsignedIntegerValue;
		
		CFRelease(statusInfo);
	}
	
	if (_stage == kFSOperationStageRunning)
	{
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
							  [NSNumber numberWithUnsignedInteger:	self.filesTransferred],	BXFileTransferFilesTransferredKey,
							  [NSNumber numberWithUnsignedLongLong:	self.bytesTransferred],	BXFileTransferBytesTransferredKey,
							  [NSNumber numberWithUnsignedInteger:	self.numFiles],			BXFileTransferFilesTotalKey,
							  [NSNumber numberWithUnsignedLongLong:	self.numBytes],			BXFileTransferBytesTotalKey,
							  self.currentPath, BXFileTransferCurrentPathKey,
							  nil];
		[self _sendInProgressNotificationWithInfo: info];
	}
	
	//Make a note that we have actually copied/moved any data, in case we need to clean up later
	if (self.bytesTransferred > 0)
        _hasCreatedFiles = YES;
}

@end
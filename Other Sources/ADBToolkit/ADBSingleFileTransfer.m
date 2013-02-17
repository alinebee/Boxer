/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */


#import "ADBSingleFileTransfer.h"

#pragma mark -
#pragma mark Notification constants and keys

NSString * const ADBFileTransferFilesTotalKey		= @"ADBFileTransferFilesTotalKey";
NSString * const ADBFileTransferFilesTransferredKey	= @"ADBFileTransferFilesTransferredKey";
NSString * const ADBFileTransferBytesTotalKey		= @"ADBFileTransferBytesTotalKey";
NSString * const ADBFileTransferBytesTransferredKey	= @"ADBFileTransferBytesTransferredKey";
NSString * const ADBFileTransferCurrentPathKey		= @"ADBFileTransferCurrentPathKey";



#pragma mark -
#pragma mark Private method declarations

@interface ADBSingleFileTransfer ()

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

@implementation ADBSingleFileTransfer
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
		
		_pollInterval = ADBFileTransferDefaultPollInterval;
		
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

- (ADBOperationProgress) currentProgress
{
	if (self.numBytes > 0)
	{
		return (ADBOperationProgress)self.bytesTransferred / (ADBOperationProgress)self.numBytes;		
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

- (void) main
{
    NSAssert(self.sourcePath != nil, @"No source path provided for file transfer.");
    NSAssert(self.destinationPath != nil, @"No destination path provided for file transfer.");
    if (!self.sourcePath || !self.destinationPath)
        return;
    
    //IMPLEMENTATION NOTE: we used to check for the existence of the source path and the nonexistence
    //of the destination path before beginning, but this was redundant (the file operation would fail
    //under these circumstances anyway) and would lead to race conditions.
    
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

- (BOOL) _beginTransfer
{
	OSStatus status;
	status = FSFileOperationScheduleWithRunLoop(_fileOp, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	NSAssert1(!status, @"Could not schedule file operation in current run loop, FSFileOperationScheduleWithRunLoop returned error code: %li", (long)status);
	
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
	CFStringRef destName = (__bridge CFStringRef)(self.destinationPath.lastPathComponent);
	
	_stage = kFSOperationStageUndefined;
	
	if (self.copyFiles)
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
	if (currentItem)
	{
		self.currentPath = [_manager stringWithFileSystemRepresentation: currentItem length: strlen(currentItem)];
	}
    
	if (status && status != userCanceledErr)
	{
        NSDictionary *info = (self.currentPath) ? @{ NSFilePathErrorKey: self.currentPath } : nil;
		self.error = [NSError errorWithDomain: NSOSStatusErrorDomain code: status userInfo: info];
	}
	
	if (errorCode && errorCode != userCanceledErr)
	{
        NSDictionary *info = (self.currentPath) ? @{ NSFilePathErrorKey: self.currentPath } : nil;
		self.error = [NSError errorWithDomain: NSOSStatusErrorDomain code: errorCode userInfo: info];
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
		NSDictionary *info = @{
            ADBFileTransferFilesTransferredKey: @(self.filesTransferred),
            ADBFileTransferBytesTransferredKey: @(self.bytesTransferred),
            ADBFileTransferFilesTotalKey:       @(self.numFiles),
            ADBFileTransferBytesTotalKey:       @(self.numBytes),
            ADBFileTransferCurrentPathKey:      self.currentPath,
        };
        
		[self _sendInProgressNotificationWithInfo: info];
	}
	
	//Make a note that we have actually copied/moved any data, in case we need to clean up later
	if (self.bytesTransferred > 0)
        _hasCreatedFiles = YES;
}

@end
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


//ADBFileTransfer is an ADBOperation subclass class for performing asynchronous file copy/move.
//ADBFileTransfer transfers only a single file/directory to a single destination: see also
//ADBFileTransferSet for a batch transfer operation.


#import "ADBOperation.h"
#import "ADBFileTransfer.h"

/// The default interval in seconds at which to poll the progress of the file transfer.
#define ADBFileTransferDefaultPollInterval 0.5

/// ADBFileTransfer is an ADBOperation subclass class for performing asynchronous file copy/move.
/// ADBFileTransfer transfers only a single file/directory to a single destination: see also
/// ADBFileTransferSet for a batch transfer operation.
@interface ADBSingleFileTransfer : ADBOperation <ADBFileTransfer>
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

/// The full source path to transfer from.
@property (copy) NSString *sourcePath;

/// The full destination path to transfer to, including filename.
@property (copy) NSString *destinationPath;

/// The interval at which to check the progress of the file transfer
/// and issue overall progress updates.
/// Our overall running time will be a multiple of this interval.
@property (assign) NSTimeInterval pollInterval;

/// Whether to copy or move the file(s) in the transfer.
@property (assign, nonatomic) BOOL copyFiles;

#pragma mark -
#pragma mark Initialization

/// Create/initialize a suitable file transfer operation from the specified source path
/// to the specified destination.
+ (instancetype) transferFromPath: (NSString *)source
                           toPath: (NSString *)destination
                        copyFiles: (BOOL)copy;

/// Create/initialize a suitable file transfer operation from the specified source path
/// to the specified destination.
- (instancetype) initFromPath: (NSString *)source
                       toPath: (NSString *)destination
                    copyFiles: (BOOL)copy;

@end

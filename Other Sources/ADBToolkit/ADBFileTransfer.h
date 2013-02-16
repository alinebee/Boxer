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


//ADBFileTransfer is an interface for ADBOperations implemented by ADBSingleFileTransfer
//and ADBMultiFileTransfer (which have different parent classes.)

#import "ADBOperation.h"

#pragma mark -
#pragma mark Notification user info dictionary keys

//NSNumber unsigned integers with the number of files total and transferred so far.
//Included with ADBOperationInProgress.
extern NSString * const ADBFileTransferFilesTotalKey;
extern NSString * const ADBFileTransferFilesTransferredKey;

//NSNumber unsigned long longs with the size in bytes of the files in total and transferred so far.
//Included with ADBOperationInProgress.
extern NSString * const ADBFileTransferBytesTotalKey;
extern NSString * const ADBFileTransferBytesTransferredKey;

//An NSString path indicating the current file being transferred.
//Included with ADBOperationInProgress.
extern NSString * const ADBFileTransferCurrentPathKey;


#pragma mark -
#pragma mark Interface

@protocol ADBFileTransfer <NSObject>

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

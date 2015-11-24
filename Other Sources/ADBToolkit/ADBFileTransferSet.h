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


//ADBFileTransferSet manages a set of individual file transfer operations and reports on their
//progress as a whole. The actual transfer operations can be anything, as long as they conform
//to ADBFileTransfer.

#import "ADBOperationSet.h"
#import "ADBFileTransfer.h"

/// Limit the number of file transfers we will undertake at once:
/// set as the default \c maxConcurrentOperations for ADBFileTransferSets.
/// Large numbers of file transfers may otherwise flood OS X with threads and result in deadlocking.
/// This was observed in OS X 10.7.3 with 63 file transfers.
#define ADBDefaultMaxConcurrentFileTransfers 10

/// ADBFileTransferSet manages a set of individual file transfer operations and reports on their
/// progress as a whole. The actual transfer operations can be anything, as long as they conform
/// to ADBFileTransfer.
@interface ADBFileTransferSet : ADBOperationSet <ADBFileTransfer>
{
    BOOL _copyFiles;
}
@property (assign, nonatomic) BOOL copyFiles;

#pragma mark -
#pragma mark Initialization

/// Create/initialize a suitable file transfer operation for the specified
/// source->destination mappings.
+ (instancetype) transferForPaths: (NSDictionary *)paths
                        copyFiles: (BOOL)copy;

- (instancetype) initForPaths: (NSDictionary *)paths
                    copyFiles: (BOOL)copy;

/// Adds a SingleFileTransfer operation into the set for the specified set of files.
- (void) addTransferFromPath: (NSString *)sourcePath
                      toPath: (NSString *)destinationPath;

/// Adds \c ADBSingleFileTransfer operations for each pair of source->destination mappings
/// in the specified dictionary.
- (void) addTransfers: (NSDictionary *)paths;

@end

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


//ADBFileHandle describes an NSFileHandle-like interface for reading and writing
//data to and from files and file-like resources (i.e. byte streams that allow
//random access). It differs from NSFileHandle in that it can provide a FILE * handle
//for use with stdlib IO functions.


#import <Foundation/Foundation.h>

typedef enum {
    ADBSeekFromStart    = SEEK_SET,
    ADBSeekFromEnd      = SEEK_END,
    ADBSeekFromCurrent  = SEEK_CUR,
} ADBFileHandleSeekLocation;


//Returned by -offset when the offset cannot be determined or is not applicable.
#define ADBOffsetUnknown -1


#pragma mark - Protocol definitions

@protocol ADBFileHandle <NSObject>

#pragma mark - Data access methods

//Return the handle's current byte offset, or ADBOffsetUnknown if this
//could not be determined.
- (long long) offset;

//Return the maximum addressable offset, i.e. the length of the file.
//Return ADBOffsetUnknown if this could not be determined.
- (long long) maxOffset;

//Returns whether the handle's offset is at or beyond the end of the file.
- (BOOL) isAtEnd;

//Sets the handle's byte offset to the relative to the specified location.
//Returns YES if the offset was changed, or NO and populates outError if
//an illegal offset was specified.
//(Note that it is legal to seek beyond the end of the file.)
- (BOOL) seekToOffset: (long long)offset
           relativeTo: (ADBFileHandleSeekLocation)location
                error: (out NSError **)outError;

//Given a buffer and a pointer to a number of bytes, fills the buffer with
//*at most* that many bytes, starting from the current offset of the handle.
//On success, returns YES and populates numBytes with the number of bytes
//that were actually read into the buffer (which may be less than the number
//requested, or zero, if the offset is at the end of the file.)
//Also advances the offset of the file handle by the number of bytes read.
- (BOOL) getBytes: (void *)buffer
           length: (inout NSUInteger *)numBytes
            error: (out NSError **)outError;


#pragma mark - FILE handle access

//Returns an open FILE * handle representing this ADBFileHandle resource.
//If adopt is YES, the calling context is expected to take control of the
//FILE * handle and is responsible for closing the handle when it has finished.
//If adopt is NO, the FILE * handle will only be viable for the lifetime
//of the ADBFileHandle instance: i.e. it may be closed when the instance
//is deallocated.
//This method should raise an assertion if adopt is YES and ownership has
//already been taken of the file handle.
//Calling fclose() on the resulting handle should have the same effect as
//calling the close method below.
- (FILE *) fileHandleAdoptingOwnership: (BOOL)adopt;

//Frees all resources associated with the handle. Should be identical
//in behaviour to calling fclose() on the FILE * handle.
//The handle should be considered unusable after closing, and attempts
//to call any of the data access methods above should raise an exception.
- (void) close;

@end

@protocol ADBWritableFileHandle <ADBFileHandle>

//Writes numBytes bytes from the specified buffer at the current offset.
//Returns YES if the bytes were successfully written, or NO and populates
//outError if writing failed. Advances the handle's offset by the number
//of bytes that were written.
- (BOOL) writeBytes: (const void *)buffer
             length: (NSUInteger)numBytes
              error: (out NSError **)outError;
@end


#pragma mark - Abstract interface definitions

//A base implementation that presents a funopen() wrapper around its own access methods.
//This must be subclassed with concrete implementations of all data access methods.
@interface ADBAbstractFileHandle : NSObject
{
    //A funopen() handle constructed the first time a FILE * handle is requested
    //from this instance. The funopen() handle wraps the instance's own getBytes:,
    //writeBytes:, seekToOffset: and close: methods.
    FILE * _handle;
    
    //The cookie resource pointed to by the funopen handle.
    //Set to self whenever a FILE * handle is requested for adoption,
    //and released only when the handle is explicitly closed:
    //this ensures that the FILE * handle remains viable even after
    //the instance has left scope.
    id _handleCookie;
}

- (FILE *) fileHandleAdoptingOwnership: (BOOL)adopt;

@end

//A base implementation of seekToOffset:relativeTo:error for the convenience of
//file handles that maintain their own offset and can seek without special behaviour.
@interface ADBIndependentlySeekableFileHandle : ADBAbstractFileHandle
{
    long long _offset;
}

@property (assign, nonatomic) long long offset;

- (BOOL) seekToOffset: (long long)offset
           relativeTo: (ADBFileHandleSeekLocation)location
                error: (out NSError **)outError;

- (BOOL) isAtEnd;
- (long long) maxOffset;

@end


#pragma mark - Concrete file handle implementations

//A concrete implementation of ADBFileHandle that wraps a standard FILE * handle.
//Has helper constructor methods for opening a handle for a local filesystem URL.
@interface ADBSimpleFileHandle : NSObject <ADBWritableFileHandle>
{
    FILE * _handle;
    BOOL _closeOnDealloc;
}

//Creates a file handle opened from the specified URL in the specified mode.
- (id) initWithURL: (NSURL *)URL
              mode: (const char *)mode
             error: (out NSError **)outError;

- (id) initWithOpenFileHandle: (FILE *)handle
               closeOnDealloc: (BOOL)closeOnDealloc;

@end


//A concrete implementation of ADBFileHandle that allows the contents of an NSData
//instance to be read from and written to using the FILE * API.
//If opened with a mutable NSData instance, this can be read-writeable; otherwise
//it is read-only and attempts to write will fail with an NSError.
@interface ADBDataHandle : ADBIndependentlySeekableFileHandle <ADBFileHandle>
{
    id _data;
}

- (id) initWithData: (NSData *)data;

@end

@interface ADBWritableDataHandle : ADBDataHandle <ADBWritableFileHandle>

- (id) initWithData: (NSMutableData *)data;

@end


#pragma mark - File handle wrappers

//A wrapper for a source file handle, which treats the source as if it's
//divided into evenly-sized logical blocks with 0 or more bytes of padding
//at the start and end of each block.
//Note that the base class supports reading only. It must be subclassed to
//implement writing of block lead-in and lead-out areas.
@interface ADBPaddedFileHandle : ADBIndependentlySeekableFileHandle <ADBFileHandle>
{
    id <ADBFileHandle> _sourceHandle;
    NSUInteger _blockSize;
    NSUInteger _blockLeadIn;
    NSUInteger _blockLeadOut;
}


//Returns a new padded file handle with the specified logical block size, lead-in
//and lead-out. If lead-in and lead-out are both zero, the original handle will be
//returned (since no extra work is then necessary to take padding into account.)
- (id) initWithSourceHandle: (id <ADBFileHandle>)sourceHandle
           logicalBlockSize: (NSUInteger)blockSize
                     leadIn: (NSUInteger)blockLeadIn
                    leadOut: (NSUInteger)blockLeadOut;

//Converts to and from and logical byte offsets, taking block padding into account.
- (long long) sourceOffsetForLogicalOffset: (long long)offset;
- (long long) logicalOffsetForSourceOffset: (long long)offset;

@end


//A wrapper for a source file handle, which restricts access to a subregion of the
//original handle's data. All offsets and data access are relative to that subregion.
//Note that the base class supports reading only, since truncation and expansion of
//the subregion are not solvable in a generic way.
@interface ADBFileRangeHandle : ADBIndependentlySeekableFileHandle <ADBFileHandle>
{
    id <ADBFileHandle> _sourceHandle;
    NSRange _range;
}

- (id) initWithSourceHandle: (id <ADBFileHandle>)sourceHandle
                      range: (NSRange)range;

//Convert to/from. These will return ADBOffsetUnknown if the specified offset is not
//representable in the corresponding space.
- (long long) sourceOffsetForLocalOffset: (long long)offset;
- (long long) localOffsetForSourceOffset: (long long)offset;

@end
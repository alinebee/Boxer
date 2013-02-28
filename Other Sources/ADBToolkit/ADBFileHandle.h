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

//This library also defines general protocols for describing handles that implement
//one or more aspects of the same API.


#import <Foundation/Foundation.h>


#pragma mark - Constants

enum {
    ADBOpenForReading   = 1 << 0,
    ADBOpenForWriting   = 1 << 1,
    
    //Mutually exclusive
    ADBCreateIfMissing  = 1 << 2,
    ADBCreateAlways     = 1 << 3,
    
    //Mutually exclusive
    ADBTruncate         = 1 << 4,
    ADBAppend           = 1 << 5,
    
    //Equivalents to fopen() access modes
    ADBPOSIXModeR      = ADBOpenForReading,
    ADBPOSIXModeRPlus  = ADBPOSIXModeR | ADBOpenForWriting,
    
    ADBPOSIXModeW      = ADBOpenForWriting | ADBTruncate | ADBCreateIfMissing,
    ADBPOSIXModeWPlus  = ADBPOSIXModeW | ADBOpenForReading,
    
    ADBPOSIXModeA      = ADBOpenForWriting | ADBAppend | ADBCreateIfMissing,
    ADBPOSIXModeAPlus  = ADBPOSIXModeA | ADBOpenForReading,
    
    ADBPOSIXModeWX     = ADBOpenForWriting | ADBTruncate | ADBCreateAlways,
    ADBPOSIXModeWPlusX = ADBPOSIXModeWX | ADBOpenForReading,
    
    ADBPOSIXModeAX     = ADBOpenForWriting | ADBAppend | ADBCreateAlways,
    ADBPOSIXModeAPlusX = ADBPOSIXModeAX | ADBOpenForReading,
};

typedef NSUInteger ADBHandleOptions;


#pragma mark - Protocol definitions

@protocol ADBReadable <NSObject>

#pragma mark - Data access methods

#define ADBReadFailed -1

//Given a buffer and a pointer to a number of bytes, fill the buffer with
//*at most* that many bytes, starting from the current position of the handle.
//On success, return YES and populate bytesRead (a required parameter) with
//the number of bytes that were read into the buffer: which may be less than
//the number requested, or zero if the handle's position is at the end of the file.
//On failure, return NO and populate outError (if provided) with the failure reason.
//bytesRead should still be populated with the number of bytes that were
//successfully read before reading failed.
//This method should advance the offset of the file handle by the number of bytes
//successfully read, even on failure.
- (BOOL) readBytes: (void *)buffer
         maxLength: (NSUInteger)numBytes
         bytesRead: (out NSUInteger *)bytesRead
             error: (out NSError **)outError;

//Return an NSData instance populated with at most numBytes bytes (or until the end
//of the file, whichever comes first) starting from the current position of the handle.
//Return nil and populate outError if the read failed at any point.
- (NSData *) dataWithMaxLength: (NSUInteger)numBytes error: (out NSError **)outError;

//Return an NSData instance populated with all the bytes available from the handle,
//starting from the current position of the handle. Return nil and populate outError
//if the read failed at any point.
- (NSData *) availableDataWithError: (out NSError **)outError;

@end

@protocol ADBWritable <NSObject>

//Writes numBytes bytes from the specified buffer at the current offset, overwriting
//any existing data at that location and expanding the backing location if necessary.
//On success, return YES and populate bytesWritten (if provided) with the number of
//bytes written, which will be equal to the number requested to be written.
//On failure, return NO and populates outError (if provided) with the failure reason.
//bytesRead should still be populated with the number of bytes that were successfully
//written before failure.
//This method advances the offset of the file handle by the number of bytes successfully
//written, even on failure.
- (BOOL) writeBytes: (const void *)buffer
             length: (NSUInteger)numBytes
       bytesWritten: (out NSUInteger *)bytesWritten
              error: (out NSError **)outError;

//Identical to the above, but writes the contents of the specified NSData instance
//instead of a buffer.
- (BOOL) writeData: (NSData *)data
      bytesWritten: (out NSUInteger *)bytesWritten
             error: (out NSError **)outError;

@end

@protocol ADBSeekable <NSObject>

typedef enum {
    ADBSeekFromStart    = SEEK_SET,
    ADBSeekFromEnd      = SEEK_END,
    ADBSeekFromCurrent  = SEEK_CUR,
} ADBHandleSeekLocation;

//Returned by -offset when the offset cannot be determined or is not applicable.
#define ADBOffsetUnknown -1


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
           relativeTo: (ADBHandleSeekLocation)location
                error: (out NSError **)outError;

@end

@protocol ADBFileHandleAccess <NSObject>

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


#pragma mark - Abstract interface definitions

//A base implementation that presents a funopen() wrapper around its own access methods.
//This must be subclassed with concrete implementations of all data access methods.
@interface ADBAbstractHandle : NSObject <ADBFileHandleAccess>
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

@end

//A base implementation of seekToOffset:relativeTo:error for the convenience of
//file handles that maintain their own offset and can seek without special behaviour.
@interface ADBSeekableAbstractHandle : ADBAbstractHandle <ADBSeekable>
{
    long long _offset;
}
@property (assign, nonatomic) long long offset;

@end


#pragma mark - Concrete file handle implementations

//A concrete implementation of ADBFileHandle that wraps a standard FILE * handle.
//Has helper constructor methods for opening a handle for a local filesystem URL.
@interface ADBFileHandle : NSObject <ADBReadable, ADBWritable, ADBSeekable, ADBFileHandleAccess>
{
    FILE * _handle;
    BOOL _closeOnDealloc;
}

//Convert an fopen()-style mode string (e.g. "r", "w+", "a+x") to our own logical flags.
//The implementation of this makes no attempt to validate the string and will blithely
//accept malformed modes (e.g. whose tokens are out of order or include conflicting tokens).
+ (ADBHandleOptions) optionsForPOSIXAccessMode: (const char *)mode;

//Returns a POSIX mode string best representing the given options.
//Returns NULL if no suitable POSIX access mode could be determined.
+ (const char *) POSIXAccessModeForOptions: (ADBHandleOptions)options;


//Creates a file handle opened from the specified URL in the specified mode
//(or with the specified options bitmask).
+ (id) handleForURL: (NSURL *)URL
            options: (ADBHandleOptions)options
              error: (out NSError **)outError;

+ (id) handleForURL: (NSURL *)URL
               mode: (const char *)mode
              error: (out NSError **)outError;

- (id) initWithURL: (NSURL *)URL
           options: (ADBHandleOptions)options
             error: (out NSError **)outError;

- (id) initWithURL: (NSURL *)URL
              mode: (const char *)mode
             error: (out NSError **)outError;

//Wraps an existing stdlib file handle. If closeOnDealloc is YES, the instance will
//take control of the file handle and close it when the instance itself is deallocated.
- (id) initWithOpenFileHandle: (FILE *)handle
               closeOnDealloc: (BOOL)closeOnDealloc;

@end

//A concrete handle implementation that allows the contents of an NSData
//instance to be read from and seeked within using the FILE * API.
@interface ADBDataHandle : ADBSeekableAbstractHandle <ADBReadable>
{
    id _data;
}

+ (id) handleForData: (NSData *)data;
- (id) initWithData: (NSData *)data;

@end

//A mutable implementation of the above, allowing writing to NSMutableData instances.
@interface ADBWritableDataHandle : ADBDataHandle <ADBWritable>

+ (id) handleForData: (NSMutableData *)data;
- (id) initWithData: (NSMutableData *)data;

@end


#pragma mark - File handle wrappers

//A wrapper for a source handle, which treats the source as if it's
//divided into evenly-sized logical blocks with 0 or more bytes of padding
//at the start and end of each block. ADBBlockHandle thus allows uninterrupted
//sequential reads across blocks that may be separated by large gaps in the
//original handle.
//Note that the base class supports reading only. It must be subclassed to
//implement writing of block lead-in and lead-out areas.
@interface ADBBlockHandle : ADBSeekableAbstractHandle <ADBReadable>
{
    id <ADBReadable, ADBSeekable> _sourceHandle;
    NSUInteger _blockSize;
    NSUInteger _blockLeadIn;
    NSUInteger _blockLeadOut;
}

//Returns a new padded file handle with the specified logical block size, lead-in
//and lead-out.
+ (id) handleForHandle: (id <ADBReadable, ADBSeekable>)sourceHandle
      logicalBlockSize: (NSUInteger)blockSize
                leadIn: (NSUInteger)blockLeadIn
               leadOut: (NSUInteger)blockLeadOut;

- (id) initWithHandle: (id <ADBReadable, ADBSeekable>)sourceHandle
     logicalBlockSize: (NSUInteger)blockSize
               leadIn: (NSUInteger)blockLeadIn
              leadOut: (NSUInteger)blockLeadOut;

//Converts to and from and logical byte offsets, taking block padding into account.
- (long long) sourceOffsetForLogicalOffset: (long long)offset;
- (long long) logicalOffsetForSourceOffset: (long long)offset;

@end


//A wrapper for a source handle, which restricts access to a subregion of the
//original handle's data. All offsets and data access are relative to that subregion.
//Note that the base class supports reading only, since truncation and expansion of
//the subregion are not solvable in a generic way.
@interface ADBSubrangeHandle : ADBSeekableAbstractHandle <ADBReadable>
{
    id <ADBReadable, ADBSeekable> _sourceHandle;
    NSRange _range;
}

+ (id) handleForHandle: (id <ADBReadable, ADBSeekable>)sourceHandle range: (NSRange)range;
- (id) initWithHandle: (id <ADBReadable, ADBSeekable>)sourceHandle range: (NSRange)range;

//Convert to/from. These will return ADBOffsetUnknown if the specified offset is not
//representable in the corresponding space.
- (long long) sourceOffsetForLocalOffset: (long long)offset;
- (long long) localOffsetForSourceOffset: (long long)offset;

@end
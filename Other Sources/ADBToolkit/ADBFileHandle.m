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

#import "ADBFileHandle.h"


#pragma mark - ADBAbstractFileHandle

@interface ADBAbstractFileHandle ()

@property (retain, nonatomic) id handleCookie;

@end


@implementation ADBAbstractFileHandle
@synthesize handleCookie = _handleCookie;

//Wrapper functions for funopen()
int _ADBFileHandleClose(void *cookie);
int _ADBFileHandleRead(void *cookie, char *buffer, int length);
int _ADBFileHandleWrite(void *cookie, const char *buffer, int length);
fpos_t _ADBFileHandleSeek(void *cookie, fpos_t offset, int whence);

- (FILE *) fileHandleAdoptingOwnership: (BOOL)adopt
{
    if (!_handle)
    {
        if ([self conformsToProtocol: @protocol(ADBWritableFileHandle)])
        {
            _handle = funopen(self, _ADBFileHandleRead, _ADBFileHandleWrite, _ADBFileHandleSeek, _ADBFileHandleClose);
        }
        else
        {
            _handle = funopen(self, _ADBFileHandleRead, NULL, _ADBFileHandleSeek, _ADBFileHandleClose);
        }
    }
    
    if (adopt)
    {
        NSAssert(self.handleCookie == nil, @"File handle already adopted. Ownership cannot be passed multiple times.");

        //Keeping a strong reference to ourself as the handle cookie ensures that the instance
        //powering the FILE * handle will stay around until the handle is explicitly closed.
        self.handleCookie = self;
    }
    
    return _handle;
}

- (void) close
{
    self.handleCookie = nil;
    if (_handle)
    {
        FILE *oldHandle = _handle;
        _handle = NULL;
        
        //NOTE: this will loop if fclose() is called on our FILE * handle,
        //which is why we take care to clear our record of the handle so
        //that at least we won't loop more than once.
        //(We're calling fclose() again here to be defensive, since the -close
        //method may be called directly rather than by our funopen close handler:
        //when that's the case, any buffer flushing and other upstream shenanigans
        //that fclose() does would not otherwise occur.
        fclose(oldHandle);
    }
}

- (void) dealloc
{
    [self close];
    [super dealloc];
}


#pragma mark - funopen() wrapper functions

int _ADBFileHandleRead(void *cookie, char *buffer, int length)
{
    id <ADBFileHandle> handle = (id <ADBFileHandle>)cookie;
    NSUInteger bytesRead = length;
    NSError *readError;
    BOOL succeeded = [handle getBytes: &buffer length: &bytesRead error: &readError];
    
    if (succeeded)
    {
        return (int)bytesRead; //Consistency with required API implies truncation, unfortunately
    }
    else
    {
        //TODO: make an effort to convert standard NSCocoaErrorDomain constants
        //to a plausible errno value.
        if ([readError.domain isEqualToString: NSPOSIXErrorDomain])
            errno = readError.code;
        else
            errno = EIO;
        
        return -1;
    }
}

int _ADBFileHandleWrite(void *cookie, const char *buffer, int length)
{
    id <ADBWritableFileHandle> handle = (id <ADBWritableFileHandle>)cookie;
    NSError *writeError;
    BOOL succeeded = [handle writeBytes: buffer length: length error: &writeError];
    
    if (succeeded)
    {
        return length;
    }
    else
    {
        //TODO: make an effort to convert standard NSCocoaErrorDomain constants
        //to a plausible errno value.
        if ([writeError.domain isEqualToString: NSPOSIXErrorDomain])
            errno = writeError.code;
        else
            errno = EIO;
        
        return -1;
    }
}

fpos_t _ADBFileHandleSeek(void *cookie, fpos_t offset, int whence)
{
    id <ADBFileHandle> handle = (id <ADBFileHandle>)cookie;
    NSError *seekError;
    BOOL succeeded = [handle seekToOffset: offset relativeTo: whence error: &seekError];
    if (succeeded)
    {
        return handle.offset;
    }
    else
    {
        //TODO: make an effort to convert standard NSCocoaErrorDomain constants
        //to a plausible errno value.
        if ([seekError.domain isEqualToString: NSPOSIXErrorDomain])
            errno = seekError.code;
        else
            errno = EIO;
        
        return -1;
    }
}

int _ADBFileHandleClose(void *cookie)
{
    id <ADBFileHandle> handle = (id <ADBFileHandle>)cookie;
    [handle close];
    return 0;
}

@end


#pragma mark - ADBIndependentlySeekableFileHandle

@implementation ADBIndependentlySeekableFileHandle

@synthesize offset = _offset;

- (BOOL) seekToOffset: (long long)offset
           relativeTo: (ADBFileHandleSeekLocation)location
                error: (out NSError **)outError
{
    long long newOffset;
    switch (location)
    {
        case ADBSeekFromCurrent:
            newOffset = self.offset + offset;
            break;
        case ADBSeekFromEnd:
            //TODO: raise an error if the end of the stream cannot be determined
            newOffset = self.maxOffset + offset;
            break;
        case ADBSeekFromStart:
        default:
            newOffset = offset;
            break;
    }
    
    if (newOffset < 0)
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: NSPOSIXErrorDomain
                                            code: EINVAL
                                        userInfo: nil];
        }
        return NO;
    }
    else
    {
        self.offset = newOffset;
        return YES;
    }
}

//Implement in subclasses
- (long long) maxOffset
{
    [self doesNotRecognizeSelector: _cmd];
    return ADBOffsetUnknown;
}

- (BOOL) isAtEnd
{
    return self.offset >= self.maxOffset;
}

@end



#pragma mark - ADBSimpleFileHandle


@implementation ADBSimpleFileHandle

- (id) initWithURL: (NSURL *)URL mode: (const char *)mode error: (NSError **)outError
{
    NSAssert(URL != nil, @"A URL must be provided.");
    
    const char *rep = URL.path.fileSystemRepresentation;
    FILE *handle = fopen(rep, mode);
    
    if (handle)
    {
        return [self initWithOpenFileHandle: handle closeOnDealloc: YES];
    }
    else
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: NSPOSIXErrorDomain
                                            code: errno
                                        userInfo: @{ NSURLErrorKey: URL }];
        }
        
        [self release];
        return nil;
    }
}

- (id) initWithOpenFileHandle: (FILE *)handle closeOnDealloc: (BOOL)closeOnDealloc
{
    self = [self init];
    if (self)
    {
        _handle = handle;
        _closeOnDealloc = closeOnDealloc;
    }
    return self;
}

- (BOOL) getBytes: (void *)buffer length: (inout unsigned long long *)numBytes error: (out NSError **)outError
{
    NSAssert(_handle != NULL, @"Attempted to read after handle was closed.");
    
    NSAssert(buffer != NULL, @"No buffer provided.");
    NSAssert(numBytes != NULL, @"No length pointer provided.");
    
    unsigned long bytesToRead = (unsigned long)*numBytes;
    size_t bytesRead = fread(buffer, 1, bytesToRead, _handle);
    if (bytesRead < bytesToRead)
    {
        //A partial read may just indicate that we reached the end of the file:
        //check for an actual error.
        NSInteger errorCode = ferror(_handle);
        if (errorCode != 0)
        {
            if (outError)
            {
                *outError = [NSError errorWithDomain: NSPOSIXErrorDomain
                                                code: errorCode
                                            userInfo: nil];
            }
            return NO;
        }
    }
    
    *numBytes = bytesRead;
    return YES;
}

- (long long) offset
{
    NSAssert(_handle != NULL, @"Attempted to check offset after handle was closed.");
    return ftello(_handle);
}

- (long long) maxOffset
{
    NSAssert(_handle != NULL, @"Attempted to check offset after handle was closed.");
    
    long long endOffset, currentOffset;
    flockfile(_handle);
        currentOffset = ftello(_handle);
        fseeko(_handle, 0, SEEK_END);
        endOffset = ftello(_handle);
        fseeko(_handle, currentOffset, SEEK_SET);
    funlockfile(_handle);
    
    return endOffset;
}


- (BOOL) isAtEnd
{
    NSAssert(_handle != NULL, @"Attempted to check offset after handle was closed.");
    return feof(_handle);
}

- (BOOL) writeBytes: (const void *)buffer length: (NSUInteger)numBytes error: (out NSError **)outError
{
    NSAssert(_handle != NULL, @"Attempted to write after handle was closed.");
    
    NSAssert(buffer != NULL, @"No buffer provided.");
    
    size_t bytesWritten = fwrite(buffer, 1, numBytes, _handle);
    if (bytesWritten < numBytes)
    {
        NSInteger errorCode = ferror(_handle);
        
        if (outError)
        {
            *outError = [NSError errorWithDomain: NSPOSIXErrorDomain
                                            code: errorCode
                                        userInfo: nil];
        }
        return NO;
    }
    
    return YES;
}

- (BOOL) seekToOffset: (long long)offset
           relativeTo: (ADBFileHandleSeekLocation)location
                error: (out NSError **)outError
{
    NSAssert(_handle != NULL, @"Attempted to seek after handle was closed.");
    
    off_t finalOffset = fseeko(_handle, offset, location);
    if (finalOffset != 0)
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: NSPOSIXErrorDomain
                                            code: errno
                                        userInfo: nil];
        }
        return NO;
    }
    else return YES;
}

- (FILE *) fileHandleAdoptingOwnership: (BOOL)adopt
{
    if (adopt)
    {
        NSAssert(_closeOnDealloc == YES, @"File handle already adopted. Ownership cannot be passed multiple times.");
        _closeOnDealloc = NO;
    }
    return _handle;
}

- (void) close
{
    if (_handle)
    {
        fclose(_handle);
        _handle = NULL;
    }
}
- (void) dealloc
{
    if (_closeOnDealloc)
        [self close];
    
    _handle = NULL;
    
    [super dealloc];
}

@end


#pragma mark - ADBDataHandle

@interface ADBDataHandle ()

@property (retain, nonatomic) id data;
@property (assign, nonatomic) long long offset;

@end

@implementation ADBDataHandle
@synthesize data = _data;
@synthesize offset = _offset;

- (id) initWithData: (NSData *)data
{
    NSAssert(data != nil, @"No data provided.");
    self = [self init];
    if (self)
    {
        self.data = data;
    }
    return self;
}

- (void) close
{
    self.data = nil;
    [super close];
}

- (void) dealloc
{
    [self close];
    [super dealloc];
}

- (BOOL) getBytes: (void *)buffer
           length: (inout NSUInteger *)numBytes
            error: (out NSError **)outError
{
    NSData *data = self.data;
    NSAssert(data != nil, @"Attempted to read after handle was closed.");
    
    NSAssert(buffer != NULL, @"No buffer provided.");
    NSAssert(numBytes != NULL, @"No length pointer provided.");
    
    NSUInteger bytesToRead = *numBytes;
    NSUInteger offset = (NSUInteger)self.offset;
    NSRange range = NSMakeRange(offset, MAX(bytesToRead, data.length - offset));
    
    if (range.location < data.length)
    {
        [data getBytes: buffer range: range];
        self.offset += range.length;
        *numBytes = range.length;
    }
    else
    {
        *numBytes = 0;
    }
    
    return YES;
}

- (long long) maxOffset
{
    return [self.data length];
}

@end

@implementation ADBWritableDataHandle

//Reimplemented just to recast the data parameter to be mutable.
- (id) initWithData: (NSMutableData *)data
{
    return [super initWithData: data];
}

- (BOOL) writeBytes: (const void *)buffer
             length: (NSUInteger)numBytes
              error: (out NSError **)outError
{
    NSMutableData *data = self.data;

    NSAssert(data, @"Attempted to read after handle was closed.");
    NSAssert(buffer != NULL, @"No buffer provided.");

    NSRange range = NSMakeRange((NSUInteger)self.offset, numBytes);
    NSUInteger bytesNeeded = range.location + range.length;
    if (bytesNeeded > data.length)
        data.length = bytesNeeded;
    
    [data replaceBytesInRange: range withBytes: buffer length: numBytes];
    self.offset += numBytes;
    return YES;
}

@end


#pragma mark - ADBPaddedFileHandle

@interface ADBPaddedFileHandle ()

@property (retain, nonatomic) id <ADBFileHandle> sourceHandle;
@property (assign, nonatomic) NSUInteger blockSize;
@property (assign, nonatomic) NSUInteger blockLeadIn;
@property (assign, nonatomic) NSUInteger blockLeadOut;
@property (readonly, nonatomic) NSUInteger rawBlockSize;

@end


@implementation ADBPaddedFileHandle
@synthesize sourceHandle = _sourceHandle;
@synthesize blockSize = _blockSize;
@synthesize blockLeadIn = _blockLeadIn;
@synthesize blockLeadOut = _blockLeadOut;

- (id) initWithSourceHandle: (id<ADBFileHandle>)sourceHandle
           logicalBlockSize: (NSUInteger)blockSize
                     leadIn: (NSUInteger)blockLeadIn
                    leadOut: (NSUInteger)blockLeadOut
{
    NSAssert(sourceHandle != nil, @"No source handle provided.");
    
    if (blockLeadIn == 0 && blockLeadOut == 0)
    {
        [self release];
        return [sourceHandle retain];
    }
    else
    {
        self = [self init];
        if (self)
        {
            self.sourceHandle = sourceHandle;
            self.blockSize = blockSize;
            self.blockLeadIn = blockLeadIn;
            self.blockLeadOut = blockLeadOut;
        }
        return self;
    }
}

- (void) close
{
    [super close];
    //TODO: should we close the source handle as well?
    self.sourceHandle = nil;
}

- (void) dealloc
{
    self.sourceHandle = nil;
    [super dealloc];
}

#pragma mark - Offset conversion

- (NSUInteger) rawBlockSize
{
    return _blockLeadIn + _blockLeadOut + _blockSize;
}

- (long long) logicalOffsetForSourceOffset: (long long)offset
{
    if (offset == ADBOffsetUnknown)
        return ADBOffsetUnknown;
    
    unsigned long long rawBlockSize = self.rawBlockSize;
    unsigned long long block = (offset - _blockLeadIn) / rawBlockSize;
    unsigned long long offsetInBlock = (offset - _blockLeadIn) % rawBlockSize;
    
    return (block * _blockSize) + offsetInBlock;
}

- (long long) sourceOffsetForLogicalOffset: (long long)offset
{
    if (offset == ADBOffsetUnknown)
        return ADBOffsetUnknown;
    
    unsigned long long block = offset / _blockSize;
    unsigned long long offsetInBlock = offset % _blockSize;
    
    return (block * self.rawBlockSize) + offsetInBlock + _blockLeadIn;
}


#pragma mark - Data access

- (BOOL) getBytes: (void *)buffer length: (inout NSUInteger *)numBytes error: (out NSError **)outError
{
    NSAssert(self.sourceHandle != nil, @"Attempted to read after handle closed.");
    
    NSAssert(buffer != NULL, @"No buffer provided.");
    NSAssert(numBytes != NULL, @"No length pointer provided.");
    
    NSUInteger bytesRead = 0, bytesToRead = *numBytes;
    
    @synchronized(self.sourceHandle)
    {
        while (bytesRead < bytesToRead)
        {
            unsigned long long sourceOffset = [self sourceOffsetForLogicalOffset: self.offset];
            BOOL sought = [self.sourceHandle seekToOffset: sourceOffset relativeTo: ADBSeekFromStart error: outError];
            if (!sought)
                return NO;
            
            //Read until the end of the block or until we've got all the bytes we wanted, whichever comes first.
            NSUInteger offsetWithinBlock = self.offset % self.blockSize;
            NSUInteger chunkSize = MIN(bytesToRead - bytesRead, self.blockSize - offsetWithinBlock);
            
            NSUInteger bytesReadInChunk = chunkSize;
            void *bufferOffset = &buffer[bytesRead];
            
            BOOL readBytes = [self.sourceHandle getBytes: bufferOffset length: &bytesReadInChunk error: outError];
            if (readBytes)
            {
                bytesRead += bytesReadInChunk;
                self.offset += bytesReadInChunk;
                
                //Reading finished without getting all the bytes we expected, meaning we've hit the end of the file.
                if (bytesReadInChunk < chunkSize)
                    break;
            }
            else
            {
                return NO;
            }
        }
    }
    return YES;
}

- (long long) maxOffset
{
    return self.sourceHandle.maxOffset;
}

@end


#pragma mark - ADBFileRangeHandle

@interface ADBFileRangeHandle ()

@property (retain, nonatomic) id <ADBFileHandle> sourceHandle;
@property (assign, nonatomic) NSRange range;

@end

@implementation ADBFileRangeHandle
@synthesize sourceHandle = _sourceHandle;
@synthesize range = _range;

- (id) initWithSourceHandle: (id<ADBFileHandle>)sourceHandle range: (NSRange)range
{
    self = [self init];
    if (self)
    {
        self.sourceHandle = sourceHandle;
        self.range = range;
    }
    return self;
}

- (void) close
{
    [super close];
    self.sourceHandle = nil;
}

- (void) dealloc
{
    self.sourceHandle = nil;
    [super dealloc];
}


- (long long) sourceOffsetForLocalOffset: (long long)offset
{
    if (offset == ADBOffsetUnknown)
        return ADBOffsetUnknown;
    
    return offset + self.range.location;
}

- (long long) localOffsetForSourceOffset: (long long)offset
{
    if (offset == ADBOffsetUnknown || offset < self.range.location)
        return ADBOffsetUnknown;
    
    return offset - self.range.location;
}

- (long long) maxOffset
{
    //TODO: clamp this to the max offset of the source handle?
    return self.range.location + self.range.length;
}

- (BOOL) getBytes: (void *)buffer
           length: (inout NSUInteger *)numBytes
            error: (out NSError **)outError
{
    NSAssert(self.sourceHandle != nil, @"Attempted to read after handle was closed.");
    
    NSAssert(buffer != NULL, @"No buffer provided.");
    NSAssert(numBytes != NULL, @"No length pointer provided.");
    
    if (self.offset >= self.maxOffset)
    {
        *numBytes = 0;
        return YES;
    }
    
    NSUInteger bytesToRead = *numBytes;
    bytesToRead = MIN(bytesToRead, (NSUInteger)(self.maxOffset - self.offset));
    
    @synchronized(self.sourceHandle)
    {
        BOOL sought = [self.sourceHandle seekToOffset: self.offset relativeTo: ADBSeekFromStart error: outError];
        if (!sought)
            return NO;
        
        NSUInteger bytesRead = bytesToRead;
        BOOL read = [self.sourceHandle getBytes: buffer length: &bytesRead error: outError];
        if (read)
        {
            self.offset += bytesRead;
            *numBytes = bytesRead;
            return YES;
        }
        else
        {
            return NO;
        }
    }
}

- (BOOL) seekToOffset: (long long)offset relativeTo: (ADBFileHandleSeekLocation)location error: (out NSError **)outError
{
    NSAssert(self.sourceHandle != nil, @"Attempted to seek after handle closed.");
    
    long long newOffset;
    switch (location)
    {
        case ADBSeekFromCurrent:
            newOffset = self.offset + offset;
            break;
            
        case ADBSeekFromEnd:
            newOffset = self.maxOffset + offset;
            
        case ADBSeekFromStart:
        default:
            newOffset = offset;
            break;
    }
    
    if (newOffset < 0)
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: NSPOSIXErrorDomain
                                            code: EINVAL
                                        userInfo: nil];
        }
        return NO;
    }
    else
    {
        self.offset = newOffset;
        return YES;
    }
}

@end
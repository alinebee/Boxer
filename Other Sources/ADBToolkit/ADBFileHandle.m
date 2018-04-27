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

//Basic implementations of NSData accessors for ADBReadable and ADBWritable instances.
//TODO: apply these in a less gross way than categories on NSObject.
@interface NSObject (ADBHandleDataReadImplementations)

- (NSData *) dataWithMaxLength: (NSUInteger)numBytes error: (out NSError **)outError;
- (NSData *) availableDataWithError: (out NSError **)outError;
- (BOOL) writeData: (NSData *)data bytesWritten: (out NSUInteger *)bytesWritten error: (out NSError **)outError;

@end

@implementation NSObject (ADBHandleDataReadImplementations)

- (NSData *) dataWithMaxLength: (NSUInteger)numBytes error: (out NSError **)outError
{
    NSAssert1([self conformsToProtocol: @protocol(ADBReadable)], @"%@ called on non-readable instance.", NSStringFromSelector(_cmd));

    NSUInteger bytesRead;
    char *buf = malloc(numBytes * sizeof(char));
    BOOL read = [(id <ADBReadable>)self readBytes: buf maxLength: numBytes bytesRead: &bytesRead error: outError];
    if (read)
    {
        return [NSData dataWithBytesNoCopy: buf length: bytesRead];
    }
    else
    {
        free(buf);
        return nil;
    }
}

- (NSData *) availableDataWithError: (out NSError **)outError
{
    NSAssert1([self conformsToProtocol: @protocol(ADBReadable)], @"%@ called on non-readable instance.", NSStringFromSelector(_cmd));
    
    NSUInteger blockSize = BUFSIZ;
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity: blockSize];
    
    char buf[blockSize];
    while (YES)
    {
        NSUInteger bytesReadInChunk;
        BOOL read = [(id <ADBReadable>)self readBytes: buf
                                            maxLength: blockSize
                                            bytesRead: &bytesReadInChunk
                                                error: outError];
        
        if (read)
        {
            if (bytesReadInChunk > 0)
            {
                [data appendBytes: buf length: bytesReadInChunk];
            }
            
            if (bytesReadInChunk < blockSize)
            {
                break;
            }
        }
        else
        {
            return nil;
        }
    }
    return data;
}

- (BOOL) writeData: (NSData *)data bytesWritten: (out NSUInteger *)bytesWritten error: (out NSError **)outError
{
    NSAssert1([self conformsToProtocol: @protocol(ADBWritable)], @"%@ called on non-readable instance.", NSStringFromSelector(_cmd));

    return [(id <ADBWritable>)self writeBytes: data.bytes
                                       length: data.length
                                 bytesWritten: bytesWritten
                                        error: outError];
}

@end


#pragma mark -

@interface ADBAbstractHandle ()

@property (strong, nonatomic) id handleCookie;

@end


@implementation ADBAbstractHandle
@synthesize handleCookie = _handleCookie;

//Wrapper functions for funopen()
int _ADBHandleClose(void *cookie);
int _ADBHandleRead(void *cookie, char *buffer, int length);
int _ADBHandleWrite(void *cookie, const char *buffer, int length);
fpos_t _ADBHandleSeek(void *cookie, fpos_t offset, int whence);

- (FILE *) fileHandleAdoptingOwnership: (BOOL)adopt
{
    if (!_handle)
    {
        int (*readFunc)(void *, char *, int) = NULL;
        int (*writeFunc)(void *, const char *, int) = NULL;
        fpos_t (*seekFunc)(void *, fpos_t, int) = NULL;
        int (*closeFunc)(void *) = NULL;
        
        if ([self conformsToProtocol: @protocol(ADBReadable)])
            readFunc = _ADBHandleRead;
        
        if ([self conformsToProtocol: @protocol(ADBWritable)])
            writeFunc = _ADBHandleWrite;
        
        if ([self conformsToProtocol: @protocol(ADBSeekable)])
            seekFunc = _ADBHandleSeek;
        
        if ([self conformsToProtocol: @protocol(ADBFileHandleAccess)])
            closeFunc = _ADBHandleClose;
        
        
        _handle = funopen((__bridge const void *)(self), readFunc, writeFunc, seekFunc, closeFunc);
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
}


#pragma mark - funopen() wrapper functions

int _ADBHandleRead(void *cookie, char *buffer, int length)
{
    id <ADBReadable> handle = (__bridge id <ADBReadable>)cookie;
    NSUInteger bytesRead;
    NSError *readError;
    BOOL succeeded = [handle readBytes: &buffer maxLength: length bytesRead: &bytesRead error: &readError];
    
    if (succeeded)
    {
        //Consistency with POSIX read() API implies truncation of the result, unfortunately
        return (int)MAX(bytesRead, (NSUInteger)INT_MAX);
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

int _ADBHandleWrite(void *cookie, const char *buffer, int length)
{
    id <ADBWritable> handle = (__bridge id <ADBWritable>)cookie;
    NSError *writeError;
    NSUInteger bytesWritten;
    BOOL succeeded = [handle writeBytes: buffer length: length bytesWritten: &bytesWritten error: &writeError];
    
    if (succeeded)
    {
        //Consistency with POSIX read() API implies truncation of the result, unfortunately
        return (int)MAX(bytesWritten, (NSUInteger)INT_MAX);
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

fpos_t _ADBHandleSeek(void *cookie, fpos_t offset, int whence)
{
    id <ADBSeekable> handle = (__bridge id <ADBSeekable>)cookie;
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

int _ADBHandleClose(void *cookie)
{
    id <ADBFileHandleAccess> handle = (__bridge id <ADBFileHandleAccess>)cookie;
    [handle close];
    return 0;
}

@end


#pragma mark -

@implementation ADBSeekableAbstractHandle

@synthesize offset = _offset;

- (BOOL) seekToOffset: (long long)offset
           relativeTo: (ADBHandleSeekLocation)location
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



#pragma mark -

@implementation ADBFileHandle

+ (ADBHandleOptions) optionsForPOSIXAccessMode: (const char *)mode
{
    ADBHandleOptions options = 0;
    NSUInteger i, numChars = strlen(mode);
    
    for (i=0; i<numChars; i++)
    {
        char c = mode[i];
        switch (c)
        {
            case 'r':
                options = ADBOpenForReading;
                break;
            case 'w':
                options = ADBOpenForWriting | ADBCreateIfMissing | ADBTruncate;
                break;
            case 'a':
                options = ADBOpenForWriting | ADBCreateIfMissing | ADBAppend;
                break;
            case '+':
                options |= (ADBOpenForReading | ADBOpenForWriting);
                break;
            case 'x':
                if (options & (ADBOpenForWriting | ADBCreateIfMissing))
                {
                    options &= ~ADBCreateIfMissing;
                    options |= ADBCreateAlways;
                }
                break;
        }
    }
    
    return options;
}

+ (const char *) POSIXAccessModeForOptions: (ADBHandleOptions)options
{
    //Complain about required and mutually exclusive options.
    NSAssert((options & (ADBOpenForReading | ADBOpenForWriting)) > 0,
             @"At least one of ADBOpenForReading and ADBOpenForWriting must be specified.");
    
    NSAssert((options & ADBTruncate) == 0 || (options & ADBAppend) == 0,
             @"ADBTruncate and ADBAppend cannot be specified together.");
    
    NSAssert((options & ADBCreateIfMissing) == 0 || (options & ADBCreateAlways) == 0,
             @"ADBCreateIfMissing and ADBCreateAlways cannot be specified together.");
    
    
    //Known POSIX access modes arranged in descending order of specificity.
    //This lets us do a best fit for options that may not exactly match one of our known modes.
    ADBHandleOptions optionMasks[10] = {
        ADBPOSIXModeAPlusX,
        ADBPOSIXModeAX,
        ADBPOSIXModeAPlus,
        ADBPOSIXModeA,
        ADBPOSIXModeWPlusX,
        ADBPOSIXModeWX,
        ADBPOSIXModeWPlus,
        ADBPOSIXModeRPlus,
        ADBPOSIXModeW,
        ADBPOSIXModeR,
    };
    const char * modes[10] = {
        "a+x",
        "ax",
        "a+",
        "a",
        "w+x",
        "wx",
        "w+",
        "r+",
        "w",
        "r",
    };
    
    NSUInteger i, numModes = 10;
    for (i=0; i<numModes; i++)
    {
        ADBHandleOptions mask = optionMasks[i];
        if ((options & mask) == mask)
            return modes[i];
    }
    
    //If we got this far, no mode would fit: a programming error if ever we saw one.
    NSAssert1(NO, @"No POSIX access mode is suitable for the specified options: %llu", (unsigned long long)options);
    
    return NULL;
}


+ (id) handleForURL: (NSURL *)URL mode: (const char *)mode error: (out NSError **)outError
{
    return [[self alloc] initWithURL: URL mode: mode error: outError];
}

+ (id) handleForURL: (NSURL *)URL options: (ADBHandleOptions)options error:(out NSError **)outError
{
    return [(ADBFileHandle*)[self alloc] initWithURL: URL options: options error: outError];
}

- (id) initWithURL: (NSURL *)URL options:(ADBHandleOptions)options error:(out NSError **)outError
{
    const char *mode = [self.class POSIXAccessModeForOptions: options];
    return [self initWithURL: URL mode: mode error: outError];
}

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


//IMPLEMENTATION NOTE: ADBFileHandle will blithely mix fread() and fwrite() calls without introducing
//the intervening fseek() or fflush() mandated by ANSI C. Such a limitation does not exist in the BSD
//implementations of those functions so we don't need to anymore, but this means the code below is
//not portable to other platforms (as if Objective C code would be otherwise.)
- (BOOL) readBytes: (void *)buffer
         maxLength: (NSUInteger)numBytes
         bytesRead: (out NSUInteger *)outBytesRead
             error: (out NSError **)outError
{
    NSAssert(_handle != NULL, @"Attempted to read after handle was closed.");
    
    NSAssert(buffer != NULL, @"No buffer provided.");
    NSAssert(outBytesRead != NULL, @"No length pointer provided.");
    
    NSUInteger bytesRead = fread(buffer, 1, (unsigned long)numBytes, _handle);
    *outBytesRead = bytesRead;
    
    if (bytesRead < numBytes)
    {
        //A partial read may indicate an error or just that we reached the end of the file.
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
    
    return YES;
}

- (BOOL) writeBytes: (const void *)buffer
             length: (NSUInteger)numBytes
       bytesWritten: (out NSUInteger *)outBytesWritten
              error: (out NSError **)outError
{
    NSAssert(_handle != NULL, @"Attempted to write after handle was closed.");
    
    NSAssert(buffer != NULL, @"No buffer provided.");
    
    size_t bytesWritten = fwrite(buffer, 1, numBytes, _handle);
    if (outBytesWritten)
        *outBytesWritten = bytesWritten;
    
    if (bytesWritten < numBytes)
    {
        if (outError)
        {
            NSInteger errorCode = ferror(_handle);
            *outError = [NSError errorWithDomain: NSPOSIXErrorDomain
                                            code: errorCode
                                        userInfo: nil];
        }
        return NO;
    }
    
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

- (BOOL) seekToOffset: (long long)offset
           relativeTo: (ADBHandleSeekLocation)location
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
}

@end


#pragma mark -

@interface ADBDataHandle ()

@property (strong, nonatomic) id data;
@property (assign, nonatomic) long long offset;

@end

@implementation ADBDataHandle
@synthesize data = _data;
@dynamic offset;

+ (id) handleForData: (NSData *)data
{
    return [[self alloc] initWithData: data];
}

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
}

- (BOOL) readBytes: (void *)buffer
         maxLength: (NSUInteger)numBytes
         bytesRead: (out NSUInteger *)outBytesRead
             error: (out NSError **)outError
{
    NSData *data = self.data;
    NSAssert(data != nil, @"Attempted to read after handle was closed.");
    
    NSAssert(buffer != NULL, @"No buffer provided.");
    NSAssert(outBytesRead != NULL, @"No length pointer provided.");
    
    NSUInteger offset = (NSUInteger)self.offset, maxOffset = (NSUInteger)self.maxOffset;
    NSRange range = NSMakeRange(offset, MIN(numBytes, maxOffset - offset));
    
    if (range.location < data.length)
    {
        [data getBytes: buffer range: range];
        self.offset += range.length;
        *outBytesRead = range.length;
    }
    else
    {
        *outBytesRead = 0;
    }
    
    return YES;
}

- (NSData *) dataWithMaxLength: (NSUInteger)numBytes error: (out NSError **)outError
{
    if (self.isAtEnd)
    {
        return [NSData data];
    }
    else
    {
        NSUInteger offset = (NSUInteger)self.offset, maxOffset = (NSUInteger)self.maxOffset;
        NSRange range = NSMakeRange(offset, MIN(numBytes, maxOffset - offset));
        return [self.data subdataWithRange: range];
    }
}

- (NSData *) availableDataWithError: (out NSError **)outError
{
    if (self.isAtEnd)
    {
        return [NSData data];
    }
    else
    {
        NSUInteger offset = (NSUInteger)self.offset, maxOffset = (NSUInteger)self.maxOffset;
        NSRange range = NSMakeRange(offset, maxOffset - offset);
        return [self.data subdataWithRange: range];
    }
}

- (long long) maxOffset
{
    return [self.data length];
}

@end

@implementation ADBWritableDataHandle

//Reimplemented just to recast the data parameter to be mutable.
+ (id) handleForData: (NSMutableData *)data
{
    return [[self alloc] initWithData: data];
}

- (id) initWithData: (NSMutableData *)data
{
    return [super initWithData: data];
}

- (BOOL) writeBytes: (const void *)buffer
             length: (NSUInteger)numBytes
       bytesWritten: (out NSUInteger *)outBytesWritten
              error: (out NSError **)outError
{
    NSMutableData *data = self.data;

    NSAssert(data, @"Attempted to read after handle was closed.");
    NSAssert(buffer != NULL, @"No buffer provided.");

    //If the data instance isn't large enough to accommodate the new data, expand it at the end.
    //(Note that NSData -replaceBytesInRange:withBytes:length: can do this itself, but it expands
    //from the point of insertion which is inconsistent with our API.)
    NSRange range = NSMakeRange((NSUInteger)self.offset, numBytes);
    NSUInteger bytesNeeded = range.location + range.length;
    if (bytesNeeded > data.length)
        data.length = bytesNeeded;
    
    [data replaceBytesInRange: range withBytes: buffer length: numBytes];
    self.offset += numBytes;
    
    if (outBytesWritten)
        *outBytesWritten = numBytes;
    
    return YES;
}

- (BOOL) writeData: (NSData *)data bytesWritten: (out NSUInteger *)bytesWritten error: (out NSError **)outError
{
    return [self writeBytes: data.bytes
                     length: data.length
               bytesWritten: bytesWritten
                      error: outError];
}

@end


#pragma mark -

@interface ADBBlockHandle ()

@property (strong, nonatomic) id <ADBReadable, ADBSeekable> sourceHandle;
@property (assign, nonatomic) NSUInteger blockSize;
@property (assign, nonatomic) NSUInteger blockLeadIn;
@property (assign, nonatomic) NSUInteger blockLeadOut;
@property (readonly, nonatomic) NSUInteger rawBlockSize;

@end

@implementation ADBBlockHandle
@synthesize sourceHandle = _sourceHandle;
@synthesize blockSize = _blockSize;
@synthesize blockLeadIn = _blockLeadIn;
@synthesize blockLeadOut = _blockLeadOut;

+ (id) handleForHandle: (id <ADBReadable, ADBSeekable>)sourceHandle
      logicalBlockSize: (NSUInteger)blockSize
                leadIn: (NSUInteger)blockLeadIn
               leadOut: (NSUInteger)blockLeadOut
{
    return [[self alloc] initWithHandle: sourceHandle
                       logicalBlockSize: blockSize
                                 leadIn: blockLeadIn
                                leadOut: blockLeadOut];
}

- (id) initWithHandle: (id <ADBReadable, ADBSeekable>)sourceHandle
     logicalBlockSize: (NSUInteger)blockSize
               leadIn: (NSUInteger)blockLeadIn
              leadOut: (NSUInteger)blockLeadOut
{
    NSAssert(sourceHandle != nil, @"No source handle provided.");
    
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

- (void) close
{
    [super close];
    //TODO: should we close the source handle as well?
    self.sourceHandle = nil;
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
    if (rawBlockSize == _blockSize)
        return offset;
    
    unsigned long long offsetInBlock = (offset - _blockLeadIn) % rawBlockSize;
    
    //Offset was located within padding region
    if (offsetInBlock >= _blockSize)
        return ADBOffsetUnknown;
        
    unsigned long long block = (offset - _blockLeadIn) / rawBlockSize;
    return (block * _blockSize) + offsetInBlock;
}

- (long long) sourceOffsetForLogicalOffset: (long long)offset
{
    if (offset == ADBOffsetUnknown)
        return ADBOffsetUnknown;
    
    unsigned long long rawBlockSize = self.rawBlockSize;
    if (rawBlockSize == _blockSize)
        return offset;
    
    unsigned long long block = offset / _blockSize;
    unsigned long long offsetInBlock = offset % _blockSize;
    
    return (block * rawBlockSize) + offsetInBlock + _blockLeadIn;
}


#pragma mark - Data access

- (BOOL) readBytes: (void *)buffer
         maxLength: (NSUInteger)numBytes
         bytesRead: (out NSUInteger *)outBytesRead
             error: (out NSError **)outError
{
    NSAssert(self.sourceHandle != nil, @"Attempted to read after handle closed.");
    
    //If we have no padding, the source handle can deal with the read directly.
    if (self.blockLeadIn == 0 && self.blockLeadOut == 0)
    {
        BOOL sought = [self.sourceHandle seekToOffset: self.offset relativeTo: ADBSeekFromStart error: outError];
        if (sought)
            return [self.sourceHandle readBytes: buffer maxLength: numBytes bytesRead: outBytesRead error: outError];
        else
            return NO;
    }
    
    NSAssert(buffer != NULL, @"No buffer provided.");
    NSAssert(outBytesRead != NULL, @"No length pointer provided.");
    
    NSUInteger bytesRead = 0;
    *outBytesRead = 0;
    
    @synchronized(self.sourceHandle)
    {
        while (bytesRead < numBytes)
        {
            unsigned long long sourceOffset = [self sourceOffsetForLogicalOffset: self.offset];
            BOOL sought = [self.sourceHandle seekToOffset: sourceOffset relativeTo: ADBSeekFromStart error: outError];
            if (!sought)
            {
                return NO;
            }
            
            //Read until the end of the block or until we've got all the bytes we wanted, whichever comes first.
            NSUInteger offsetWithinBlock = self.offset % self.blockSize;
            NSUInteger chunkSize = MIN(numBytes - bytesRead, self.blockSize - offsetWithinBlock);
            
            void *bufferOffset = &buffer[bytesRead];
            
            NSUInteger bytesReadInChunk;
            BOOL readBytes = [self.sourceHandle readBytes: bufferOffset
                                                maxLength: chunkSize
                                                bytesRead: &bytesReadInChunk
                                                    error: outError];
            
            if (readBytes)
            {
                self.offset += bytesReadInChunk;
                bytesRead += bytesReadInChunk;
                *outBytesRead = bytesRead;
                
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
    return [self logicalOffsetForSourceOffset: self.sourceHandle.maxOffset];
}

@end


#pragma mark -

@interface ADBSubrangeHandle ()

@property (strong, nonatomic) id <ADBReadable, ADBSeekable> sourceHandle;
@property (assign, nonatomic) NSRange range;

@end

@implementation ADBSubrangeHandle
@synthesize sourceHandle = _sourceHandle;
@synthesize range = _range;

+ (id) handleForHandle: (id <ADBReadable, ADBSeekable>)sourceHandle range: (NSRange)range
{
    return [[self alloc] initWithHandle: sourceHandle range: range];
}

- (id) initWithHandle: (id <ADBReadable, ADBSeekable>)sourceHandle range: (NSRange)range
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


- (long long) sourceOffsetForLocalOffset: (long long)offset
{
    if (offset == ADBOffsetUnknown)
        return ADBOffsetUnknown;
    
    return offset + self.range.location;
}

- (long long) localOffsetForSourceOffset: (long long)offset
{
    if (offset == ADBOffsetUnknown || offset < (long long)self.range.location)
        return ADBOffsetUnknown;
    
    return offset - self.range.location;
}

- (long long) maxOffset
{
    return self.range.length;
}

- (BOOL) readBytes: (void *)buffer
         maxLength: (NSUInteger)numBytes
         bytesRead: (out NSUInteger *)outBytesRead
             error: (out NSError **)outError
{
    NSAssert(self.sourceHandle != nil, @"Attempted to read after handle was closed.");
    
    NSAssert(buffer != NULL, @"No buffer provided.");
    NSAssert(outBytesRead != NULL, @"No length pointer provided.");
    
    *outBytesRead = 0;
    
    if (self.offset >= self.maxOffset)
    {
        return YES;
    }
    
    numBytes = MIN(numBytes, (NSUInteger)(self.maxOffset - self.offset));
    
    @synchronized(self.sourceHandle)
    {
        long long sourceOffset = [self sourceOffsetForLocalOffset: self.offset];
        
        BOOL sought = [self.sourceHandle seekToOffset: sourceOffset relativeTo: ADBSeekFromStart error: outError];
        if (!sought)
        {
            return NO;
        }
        
        NSUInteger bytesRead;
        BOOL read = [self.sourceHandle readBytes: buffer maxLength: numBytes bytesRead: &bytesRead error: outError];
        if (read)
        {
            self.offset += bytesRead;
            *outBytesRead = bytesRead;
            return YES;
        }
        else
        {
            return NO;
        }
    }
}

@end

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

#import "ADBISOImagePrivate.h"


#pragma mark -
#pragma mark Date helper macros

//Converts the digits of an ISO extended date format (e.g. {'1','9','9','0'})
//into a proper integer (e.g. 1990).
int extdate_to_int(uint8_t *digits, int length)
{
    //Convert the unterminated char array to a str
    char buf[5];
    strncpy(buf, (const char *)digits, MIN(length, 4));
    buf[length] = '\0';
    
    //Convert the str to an integer
    return atoi(buf);
}



@implementation ADBISOImage
@synthesize sourceURL = _sourceURL;
@synthesize volumeName = _volumeName;
@synthesize imageHandle = _imageHandle;
@synthesize pathCache = _pathCache;

+ (NSDate *) _dateFromDateTime: (ADBISODateTime)dateTime
{
    struct tm timeStruct;
    timeStruct.tm_year     = dateTime.year;
    timeStruct.tm_mon      = dateTime.month - 1;
    timeStruct.tm_mday     = dateTime.day;
    timeStruct.tm_hour     = dateTime.hour;
    timeStruct.tm_min      = dateTime.minute;
    timeStruct.tm_sec      = dateTime.second;
    timeStruct.tm_gmtoff   = dateTime.gmtOffset * 15 * 60;
    
    time_t epochtime = mktime(&timeStruct);
    
    return [NSDate dateWithTimeIntervalSince1970: epochtime];
}

+ (NSDate *) _dateFromExtendedDateTime: (ADBISOExtendedDateTime)dateTime
{
    struct tm timeStruct;
    timeStruct.tm_year     = extdate_to_int(dateTime.year, 4);
    timeStruct.tm_mon      = extdate_to_int(dateTime.month, 2) - 1;
    timeStruct.tm_mday     = extdate_to_int(dateTime.day, 2);
    timeStruct.tm_hour     = extdate_to_int(dateTime.hour, 2);
    timeStruct.tm_min      = extdate_to_int(dateTime.minute, 2);
    timeStruct.tm_sec      = extdate_to_int(dateTime.second, 2);
    timeStruct.tm_gmtoff   = dateTime.gmtOffset * 15 * 60;
    
    time_t epochtime = mktime(&timeStruct);
    
    return [NSDate dateWithTimeIntervalSince1970: epochtime];
}

#pragma mark -
#pragma mark Initalization and cleanup

+ (id) imageWithContentsOfURL: (NSURL *)URL
                        error: (NSError **)outError
{
    return [[(ADBISOImage *)[self alloc] initWithContentsOfURL: URL error: outError] autorelease];
}

- (id) init
{
    self = [super init];
    if (self)
    {
        _sectorSize = ADBISODefaultSectorSize;
        _rawSectorSize = ADBISODefaultSectorSize;
        _leadInSize = ADBISOLeadInSize;
    }
    return self;
}

- (id) initWithContentsOfURL: (NSURL *)URL
                       error: (NSError **)outError
{
    self = [self init];
    if (self)
    {
        self.sourceURL = URL;
        BOOL loaded = [self _loadImageAtURL: URL error: outError];
        if (!loaded)
        {
            [self release];
            self = nil;
        }
    }
    return self;
}

- (void) dealloc
{
    self.sourceURL = nil;
    self.volumeName = nil;
    self.imageHandle = nil;
    [super dealloc];
}


#pragma mark -
#pragma mark Public API

- (NSDictionary *) attributesOfFileAtPath: (NSString *)path
                                    error: (NSError **)outError
{
    ADBISOFileEntry *entry = [self _fileEntryAtPath: path error: outError];
    return entry.attributes;
}

- (NSData *) contentsOfFileAtPath: (NSString *)path
                            error: (NSError **)outError
{
    ADBISOFileEntry *entry = [self _fileEntryAtPath: path error: outError];
    
    if (entry.isDirectory)
    {
        if (outError)
        {
            NSURL *fileURL = [self.sourceURL URLByAppendingPathComponent: path];
            NSDictionary *info = @{ NSURLErrorKey: fileURL };
            //TODO: check what error code Cocoa's own file-read methods use when you pass them a directory.
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                            code: NSFileReadCorruptFileError
                                        userInfo: info];
        }
        return nil;
    }
    return entry.contents;
}

- (id <ADBFilesystemEnumerator>) enumeratorAtPath: (NSString *)path
                                            error: (NSError **)outError
{
    NSAssert(NO, @"Not yet implemented.");
    return nil;
}


#pragma mark - Low-level filesystem API

- (unsigned long long) _fileOffsetForSector: (NSUInteger)sector
{
    return (sector * _rawSectorSize) + _leadInSize;
}

- (unsigned long long) _seekToSector: (NSUInteger)sector
{
    unsigned long long offset = [self _fileOffsetForSector: sector];
    [self.imageHandle seekToFileOffset: offset];
    return offset;
}

- (NSData *) _readDataFromSectors: (NSUInteger)numSectors
{
    NSUInteger i;
    
    //Read the data in chunks of one sector each, allowing for any between-sector padding.
    NSMutableData *data = [NSMutableData dataWithCapacity: numSectors * _sectorSize];
    for (i=0; i < numSectors; i++)
    {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        NSData *chunk = [self.imageHandle readDataOfLength: _sectorSize];
        [data appendData: chunk];
        
        //Skip over any extra padding snuggled between each proper sector
        //(Needed for BIN/CUE images, which have 304 bytes of checksum data for each sector.)
        if (_rawSectorSize > _sectorSize)
        {
            NSUInteger paddingSize = _rawSectorSize - _sectorSize;
            [self.imageHandle seekToFileOffset: self.imageHandle.offsetInFile + paddingSize];
        }
        
        [pool drain];
    }
    return data;
}

- (NSData *) _readDataFromSectorRange: (NSRange)range
{
    [self _seekToSector: range.location];
    return [self _readDataFromSectors: range.length];
}


- (BOOL) _loadImageAtURL: (NSURL *)URL
                   error: (NSError **)outError
{
    //Attempt to open the image at the source path
    self.imageHandle = [[NSFileHandle fileHandleForReadingFromURL: URL
                                                            error: outError] retain];
    
    //If the image couldn't be loaded, bail out now
    if (!self.imageHandle) return NO;
    
    //Determine the overall length of the image file
    [self.imageHandle seekToEndOfFile];
    _imageSize = [self.imageHandle offsetInFile];
    
    //Search the volume descriptors to find the primary descriptor
    BOOL foundDescriptor = [self _getPrimaryVolumeDescriptor: &_primaryVolumeDescriptor
                                                       error: outError];
    
    //If we didn't find a primary descriptor amongst the volume descriptors, fail out 
    if (!foundDescriptor) return NO;
    
    //Parse the volume name from the primary descriptor
    self.volumeName = [[[NSString alloc] initWithBytes: _primaryVolumeDescriptor.volumeID
                                                length: ADBISOVolumeIdentifierLength
                                              encoding: NSASCIIStringEncoding] autorelease];
    
    //If we got this far, then we succeeded in loading the image
    return YES;
}

- (BOOL) _getPrimaryVolumeDescriptor: (ADBISOPrimaryVolumeDescriptor *)descriptor
                               error: (NSError **)outError
{
    NSUInteger sector = ADBISOVolumeDescriptorSectorOffset;
    unsigned long long sectorOffset;
    uint8_t type;
    do
    {
        sectorOffset = [self _seekToSector: sector];
        [[self.imageHandle readDataOfLength: sizeof(uint8_t)] getBytes: &type];
        
        if (type == ADBISOVolumeDescriptorTypePrimary)
        {
            //If we found the primary descriptor, then rewind back to the start and read in the whole thing.
            [self.imageHandle seekToFileOffset: sectorOffset];
            [[self.imageHandle readDataOfLength: sizeof(ADBISOPrimaryVolumeDescriptor)] getBytes: &descriptor];
            return YES;
        }
        
        sector += 1;
    }
    //Stop once we find the volume descriptor terminator, or if we seek beyond the end of the image
    while ((type != ADBISOVolumeDescriptorTypeSetTerminator) && (sectorOffset < _imageSize));
    
    //If we got this far without finding a primary volume descriptor, then this is an invalid/incomplete ISO image.
    if (outError)
    {
        NSDictionary *info = @{ NSURLErrorKey: self.sourceURL };
        *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                        code: NSFileReadCorruptFileError
                                    userInfo: info];
    }
    return NO;
}

- (ADBISOFileEntry *) _fileEntryAtPath: (NSString *)path
                                 error: (NSError **)outError
{
    ADBISODirectoryRecord record;
    BOOL succeeded = [self _getDirectoryRecord: &record atPath: path error: outError];
    if (succeeded)
    {
        return [ADBISOFileEntry entryFromDirectoryRecord: record
                                                 inImage: self];
    }
    else return nil;
}

- (BOOL) _getDirectoryRecord: (ADBISODirectoryRecord *)record
                      atPath: (NSString *)path
                       error: (NSError **)outError
{
    NSUInteger sectorOffset = [self _offsetOfDirectoryRecordForPath: path];
    if (sectorOffset == NSNotFound) //Path does not exist
    {
        if (outError)
        {
            NSURL *fileURL = [self.sourceURL URLByAppendingPathComponent: path];
            NSDictionary *info = @{ NSURLErrorKey: fileURL };
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                            code: NSFileReadNoSuchFileError
                                        userInfo: info];
        }
        return NO;
    }
    
    [self.imageHandle seekToFileOffset: sectorOffset];
    [[self.imageHandle readDataOfLength: sizeof(ADBISODirectoryRecord)] getBytes: &record];
    
    return YES;
}

- (NSUInteger) _offsetOfDirectoryRecordForPath: (NSString *)path
{
    NSNumber *offset = [self.pathCache objectForKey: path];
    if (offset)
        return offset.unsignedIntegerValue;
    else
        return NSNotFound;
}

- (NSDictionary *) pathCache
{
    if (!_pathCache)
    {
        [self _populatePathCache];
    }
    return [[_pathCache retain] autorelease];
}

- (void) _populatePathCache
{
    NSRange pathTableRange;
    
#if defined(__BIG_ENDIAN__)
    pathTableRange.location    = _primaryVolumeDescriptor.pathTableLocationBigEndian;
    pathTableRange.length      = _primaryVolumeDescriptor.pathTableSizeBigEndian;
#else
    pathTableRange.location    = _primaryVolumeDescriptor.pathTableLocationLittleEndian;
    pathTableRange.length      = _primaryVolumeDescriptor.pathTableSizeLittleEndian;
#endif
    
    //Now then, let's pull in the path table bit by bit
    
    //IMPLEMENT PATH TABLE PARSING HERE
}
@end



@implementation ADBISOFileEntry
@synthesize fileName = _fileName;
@synthesize fileSize = _fileSize;
@synthesize creationDate = _creationDate;
@synthesize parentImage = _parentImage;

+ (id) entryFromDirectoryRecord: (ADBISODirectoryRecord)record
                        inImage: (ADBISOImage *)image
{
    BOOL isDirectory = (record.fileFlags & ADBISOFileIsDirectory);
    Class entryClass = isDirectory ? [ADBISODirectoryEntry class] : [ADBISOFileEntry class];
    return [[[entryClass alloc] initWithDirectoryRecord: record inImage: image] autorelease];
}

- (id) initWithDirectoryRecord: (ADBISODirectoryRecord)record
                       inImage: (ADBISOImage *)image
{
    self = [self init];
    if (self)
    {
        //Note: just assignment, not copying, as our parent image may cache
        //file entries and that would result in a retain cycle.
        _parentImage = image;
        
        //Parse the record to determine file size, name and other such things
        [self _loadFromDirectoryRecord: record];
    }
    return self;
}

- (void) dealloc
{
    self.fileName = nil;
    self.creationDate = nil;
    
    [super dealloc];
}

- (void) _loadFromDirectoryRecord: (ADBISODirectoryRecord)record
{
#if defined(__BIG_ENDIAN__)
    _sectorRange.location    = record.extentLocationBigEndian;
    _sectorRange.length      = record.dataLengthBigEndian;
#else
    _sectorRange.location    = record.extentLocationLittleEndian;
    _sectorRange.length      = record.dataLengthLittleEndian;
#endif
    
    //Parse the filename from the record
    NSString *identifier = [[NSString alloc] initWithBytes: record.identifier
                                                    length: record.identifierLength
                                                  encoding: NSASCIIStringEncoding];
    
    //ISO9660 filenames are stored in the format "FILENAME.EXE;1", where the last
    //component marks the revision of the file (for multi-session discs I guess.)
    self.fileName = [[identifier componentsSeparatedByString: @";"] objectAtIndex: 0];
    [identifier release];
    
    self.creationDate = [ADBISOImage _dateFromDateTime: record.recordingTime];
}

- (BOOL) isDirectory
{
    return NO;
}

- (NSData *) contents
{
    return [self.parentImage _readDataFromSectorRange: _sectorRange];
}

- (NSDictionary *) attributes
{
    NSDictionary *attrs = @{
                            NSFileType: (self.isDirectory ? NSFileTypeDirectory : NSFileTypeRegular),
                            NSFileCreationDate: self.creationDate,
                            NSFileModificationDate: self.creationDate,
                            NSFileSize: @(self.fileSize),
                            };
    return attrs;
}

@end


@implementation ADBISODirectoryEntry

- (BOOL) isDirectory
{
    return YES;
}

- (NSArray *) subpaths
{
    //IMPLEMENT ME
    NSAssert(NO, @"Not yet implemented.");
    return nil;
}

- (NSData *) contents
{
    NSAssert(NO, @"Attempted to retrieve contents of directory.");
    return nil;
}
@end


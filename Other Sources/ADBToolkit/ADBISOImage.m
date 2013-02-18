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
#import "NSString+ADBPaths.h"

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
@synthesize sectorSize = _sectorSize;
@synthesize rawSectorSize = _rawSectorSize;
@synthesize leadInSize = _leadInSize;

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
    if (_handle)
    {
        fclose(_handle);
        _handle = NULL;
    }
    
    self.sourceURL = nil;
    self.volumeName = nil;
    self.imageHandle = nil;
    self.pathCache = nil;
    [super dealloc];
}


#pragma mark -
#pragma mark Public API

- (BOOL) fileExistsAtPath: (NSString *)path isDirectory: (BOOL *)isDir
{
    ADBISOFileEntry *entry = [self _fileEntryAtPath: path error: NULL];
    if (entry)
    {
        if (isDir)
            *isDir = entry.isDirectory;
        return YES;
    }
    else
    {
        if (isDir)
            *isDir = NO;
        return NO;
    }
}

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
            
            //TODO: check what error Cocoa's own file-read methods produce when you pass them a directory.
            *outError = [NSError errorWithDomain: NSPOSIXErrorDomain
                                            code: EISDIR
                                        userInfo: info];
        }
        return nil;
    }
    return [entry contentsWithError: outError];
}

- (id <ADBFilesystemEnumerator>) enumeratorAtPath: (NSString *)path
                                            error: (NSError **)outError
{
    NSAssert(NO, @"Not yet implemented.");
    return nil;
}

- (NSArray *) contentsOfDirectoryAtPath: (NSString *)path
                                  error: (NSError **)outError
{
    ADBISODirectoryEntry *entry = (ADBISODirectoryEntry *)[self _fileEntryAtPath: path error: outError];
    if (entry && entry.isDirectory)
    {
        NSArray *subentries = [entry subentriesWithError: outError includingOlderVersions: NO];
        if (!subentries)
            return nil;
        
        NSMutableArray *subpaths = [NSMutableArray arrayWithCapacity: subentries.count - 2];
        
        for (ADBISOFileEntry *subentry in subentries)
        {
            //The first two entries correspond to . and .. and should be skipped.
            if ([subentry.fileName isEqualToString: @"\0"] || [subentry.fileName isEqualToString: @"\1"])
                continue;
            
            NSString *subpath = [path stringByAppendingPathComponent: subentry.fileName];
            [subpaths addObject: subpath];
        }
        
        [subpaths sortUsingSelector: @selector(caseInsensitiveCompare:)];
        return subpaths;
    }
    else
    {
        return nil;
    }
}

- (NSArray *)subpathsOfDirectoryAtPath: (NSString *)path
                                 error: (NSError **)outError
{
    ADBISODirectoryEntry *entry = (ADBISODirectoryEntry *)[self _fileEntryAtPath: path error: outError];
    
    if (entry && entry.isDirectory)
    {
        NSArray *subentries = [entry subentriesWithError: outError includingOlderVersions: NO];
        if (!subentries)
            return nil;
        
        NSMutableArray *subpaths = [NSMutableArray arrayWithCapacity: subentries.count];
        [subpaths sortUsingSelector: @selector(caseInsensitiveCompare:)];
        
        for (ADBISOFileEntry *subentry in subentries)
        {
            //The first two entries correspond to . and .. and should be skipped.
            if ([subentry.fileName isEqualToString: @"\0"] || [subentry.fileName isEqualToString: @"\1"])
                continue;
            
            NSString *subpath = [path stringByAppendingPathComponent: subentry.fileName];
            if (![subpaths containsObject: subpath])
            {
                [subpaths addObject: subpath];
                
                //FIXME: EDGE CASE: a directory replaced by a later version with different contents
                if (subentry.isDirectory)
                {
                    NSArray *subsubpaths = [self subpathsOfDirectoryAtPath: subpath error: outError];
                    if (subpaths != nil)
                    {
                        [subpaths addObjectsFromArray: subsubpaths];
                    }
                    else
                    {
                        return nil;
                    }
                }
            }
        }
        
        [subpaths sortUsingSelector: @selector(caseInsensitiveCompare:)];
        return subpaths;
    }
    else
    {
        return nil;
    }
}


#pragma mark - Low-level filesystem API

- (uint32_t) _byteOffsetForSector: (uint32_t)sector
{
    return (sector * _rawSectorSize) + _leadInSize;
}

- (uint32_t) _sectorForByteOffset: (uint32_t)byteOffset
{
    return (byteOffset - _leadInSize) / _rawSectorSize;
}

- (uint32_t) _sectorOffsetForByteOffset: (uint32_t)byteOffset
{
    return (byteOffset - _leadInSize) % _rawSectorSize;
}

- (unsigned long long) _seekToSector: (NSUInteger)sector
{
    unsigned long long offset = [self _byteOffsetForSector: sector];
    [self.imageHandle seekToFileOffset: offset];
    return offset;
}

//IMPLEMENTATION NOTE: the length of the requested range is expected to be in logical
//bytes without sector padding; but the location is expected to be a 'raw' byte offset
//that takes into account sector padding and lead-in.
- (BOOL) _getBytes: (void *)buffer range: (NSRange)range error: (out NSError **)outError
{
    NSUInteger offset = range.location;
    NSUInteger bytesToRead = range.length;
    NSUInteger sectorPadding = _rawSectorSize - _sectorSize;
    NSUInteger bytesRead = 0;
    
    while (bytesRead < bytesToRead)
    {
        //If there is no sector padding then we can read the bytes in one go straight across sector boundaries.
        NSUInteger chunkSize = bytesToRead - bytesRead;
        
        //Otherwise we'll have to read up to the edge of the sector and then skip over the padding to the next sector.
        if (sectorPadding > 0)
        {
            NSUInteger offsetWithinSector = [self _sectorOffsetForByteOffset: offset];
            NSAssert1(offsetWithinSector < _sectorSize, @"Requested byte offset falls within sector padding: %lu", (unsigned long)offset);
            
            chunkSize = MIN(chunkSize, _sectorSize - offsetWithinSector);
        }
        
        BOOL seeked = (fseek(_handle, offset, SEEK_SET) == 0);
        NSAssert1(seeked, @"Could not seek to offset %u", offset);
        if (!seeked)
        {
            if (outError)
            {
                NSInteger errorCode = errno;
                NSDictionary *info = @{ NSURLErrorKey: self.sourceURL };
                *outError = [NSError errorWithDomain: NSPOSIXErrorDomain
                                                code: errorCode
                                            userInfo: info];
            }
            return NO;
        }
        
        void *bufferOffset = &buffer[bytesRead];
        size_t bytesReadInChunk = fread(bufferOffset, 1, chunkSize, _handle);
        if (bytesReadInChunk < chunkSize)
        {
            NSAssert2(NO, @"Could not read %u bytes from offset %u", chunkSize, offset);
            if (outError)
            {
                NSDictionary *info = @{ NSURLErrorKey: self.sourceURL };
                NSInteger errorCode = ferror(_handle);
                //We encountered an honest-to-god POSIX error occurred while reading
                if (errorCode != 0)
                {
                    *outError = [NSError errorWithDomain: NSPOSIXErrorDomain
                                                    code: errorCode
                                                userInfo: info];
                }
                //We didn't receive as many bytes as we were expecting, indicating a truncated file
                if (feof(_handle))
                {
                    *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                                    code: NSFileReadCorruptFileError
                                                userInfo: info];
                }
                
            }
            return NO;
        }
        
        bytesRead += bytesReadInChunk;
        
        //If we still have bytes remaining after this chunk, then we must be at the edge of a sector:
        //Jump across into the next sector and continue.
        if (bytesRead < bytesToRead)
        {
            offset += chunkSize + sectorPadding;
        }
    }
    return YES;
}

- (NSData *) _dataInRange: (NSRange)range error: (out NSError **)outError;
{
    NSMutableData *data = [[NSMutableData alloc] initWithLength: range.length];
    BOOL populated = [self _getBytes: data.mutableBytes range: range error: outError];
    
    if (populated)
    {
        return [data autorelease];
    }
    else
    {
        [data release];
        return nil;
    }
}


- (BOOL) _loadImageAtURL: (NSURL *)URL
                   error: (NSError **)outError
{
    self.sourceURL = URL;
    
    //Attempt to open the image at the source path
    self.imageHandle = [NSFileHandle fileHandleForReadingFromURL: URL error: outError];
    
    _handle = fopen(URL.path.fileSystemRepresentation, "r");
    
    //If the image couldn't be loaded, bail out now
    if (!self.imageHandle) return NO;
    
    //Search the volume descriptors to find the primary descriptor
    BOOL foundDescriptor = [self _getPrimaryVolumeDescriptor: &_primaryVolumeDescriptor
                                                       error: outError];
    
    //If we didn't find a primary descriptor amongst the volume descriptors, fail out
    if (!foundDescriptor) return NO;
    
    //Parse the volume name from the primary descriptor
    self.volumeName = [[[NSString alloc] initWithBytes: _primaryVolumeDescriptor.volumeID
                                                length: ADBISOVolumeIdentifierLength
                                              encoding: NSASCIIStringEncoding] autorelease];
    
    //Prepare the path cache starting with the root directory file entry
    ADBISODirectoryRecord rootDirectoryRecord;
    memcpy(&rootDirectoryRecord, &_primaryVolumeDescriptor.rootDirectoryRecord, ADBISORootDirectoryRecordLength);
    ADBISOFileEntry *rootDirectory = [ADBISOFileEntry entryFromDirectoryRecord: rootDirectoryRecord inImage: self];
    
    self.pathCache = [NSMutableDictionary dictionaryWithObject: rootDirectory forKey: @"/"];
    
    //If we got this far, then we succeeded in loading the image.
    return YES;
}

- (BOOL) _getPrimaryVolumeDescriptor: (ADBISOPrimaryVolumeDescriptor *)descriptor
                               error: (NSError **)outError
{
    //Start off at the beginning of the ISO's header, 16 sectors into the file.
    NSUInteger sectorIndex = ADBISOVolumeDescriptorSectorOffset;
    
    //Walk through the header of the ISO volume looking for the sector that contains
    //the primary volume descriptor. Each volume descriptor occupies an entire sector,
    //and the type of the descriptor is marked by the starting byte.
    while (YES)
    {
        uint8_t type;
        NSUInteger offset = (NSUInteger)[self _byteOffsetForSector: sectorIndex];
        
        NSRange descriptorTypeRange = NSMakeRange(offset, sizeof(uint8_t));
        BOOL readType = [self _getBytes: &type range: descriptorTypeRange error: outError];
        //Bail out if there was a read error or we hit the end of the file
        //(_getBytes:range:error: will have populated outError with the reason.)
        if (!readType)
            return NO;
        
        //We found the primary descriptor, read in the whole thing.
        if (type == ADBISOVolumeDescriptorTypePrimary)
        {
            NSRange descriptorRange = NSMakeRange(offset, sizeof(ADBISOPrimaryVolumeDescriptor));
            return [self _getBytes: descriptor range: descriptorRange error: outError];
        }
        //If we hit the end of the descriptors without finding a primary volume descriptor,
        //this indicates an invalid/incomplete ISO image.
        else if (type == ADBISOVolumeDescriptorTypeSetTerminator)
        {
            if (outError)
            {
                NSDictionary *info = @{ NSURLErrorKey: self.sourceURL };
                *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                                code: NSFileReadCorruptFileError
                                            userInfo: info];
            }
            return NO;
        }
        
        sectorIndex += 1;
    }
}

- (ADBISOFileEntry *) _fileEntryAtPath: (NSString *)path
                                 error: (out NSError **)outError
{
    //IMPLEMENTATION NOTE: should we uppercase files for saner comparison?
    //The ISO-9660 format mandates that filenames should
    
    NSAssert1(path != nil, @"No path provided to %@.", NSStringFromSelector(_cmd));
    
    //Normalize the path to be rooted in the root directory.
    if (![path hasPrefix: @"/"])
        path = [NSString stringWithFormat: @"/%@", path];
    
    //If we have a matching entry for this path, return it immediately.
    ADBISOFileEntry *matchingEntry = [self.pathCache objectForKey: path];
    
    if (!matchingEntry)
    {
        //Otherwise, scan the parent entry (note recursion.)
        NSString *parentPath = path.stringByDeletingLastPathComponent;
        if (![parentPath isEqualToString: path])
        {
            ADBISODirectoryEntry *parentEntry = (ADBISODirectoryEntry *)[self _fileEntryAtPath: parentPath error: outError];
            
            if (parentEntry)
            {
                if (parentEntry.isDirectory)
                {
                    NSArray *siblingEntries = [parentEntry subentriesWithError: outError includingOlderVersions: NO];
                    if (!siblingEntries)
                        return nil;
                    
                    //Add the siblings into the cache and pluck out the one that matches us, if any
                    for (ADBISOFileEntry *sibling in siblingEntries)
                    {
                        //The first two entries correspond to . and .. and should be skipped.
                        if ([sibling.fileName isEqualToString: @"\0"] || [sibling.fileName isEqualToString: @"\1"])
                            continue;
                            
                        NSString *siblingPath = [parentPath stringByAppendingPathComponent: sibling.fileName];
                        [self.pathCache setObject: sibling forKey: siblingPath];
                        
                        if ([siblingPath isEqualToString: path])
                            matchingEntry = sibling;
                    }
                }
            }
        }
    }
    
    if (matchingEntry)
    {
        return matchingEntry;
    }
    else
    {
        NSAssert1(NO, @"Path not found: %@", path);
        if (outError)
        {
            NSDictionary *info = @{ NSURLErrorKey: [self.sourceURL URLByAppendingPathComponent: path] };
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileNoSuchFileError userInfo: info];
        }
        return nil;
    }
}

- (ADBISOFileEntry *) _fileEntryAtOffset: (uint32_t)byteOffset error: (out NSError **)outError
{
    //The record size is the first byte of the file entry, which tells us how many bytes in total to parse in for the entry.
    uint8_t recordSize;
    BOOL gotRecordSize = [self _getBytes: &recordSize range: NSMakeRange(byteOffset, sizeof(uint8_t)) error: outError];
    if (gotRecordSize)
    {
        //Reported record size was too small, this may indicate a corrupt file record.
        if (recordSize < ADBISODirectoryRecordMinLength)
        {
            if (outError)
            {
                NSDictionary *info = @{ NSURLErrorKey: self.sourceURL };
                *outError = [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileReadCorruptFileError userInfo: info];
            }
            return nil;
        }
            
        NSRange recordRange = NSMakeRange(byteOffset, recordSize);
        ADBISODirectoryRecord record;
        
        BOOL succeeded = [self _getBytes: &record range: recordRange error: outError];
        if (succeeded)
        {
            return [ADBISOFileEntry entryFromDirectoryRecord: record
                                                     inImage: self];
        }
        else return nil;
    }
    else return nil;
}

- (NSArray *) _fileEntriesInRange: (NSRange)range error: (out NSError **)outError
{
    NSUInteger offset = range.location;
    NSUInteger bytesToRead = range.length;
    NSUInteger readBytes = 0;
    NSUInteger sectorPadding = _rawSectorSize - _sectorSize;
    
    NSMutableArray *entries = [NSMutableArray array];
    while (readBytes < bytesToRead)
    {
        NSUInteger offsetWithinSector = [self _sectorOffsetForByteOffset: offset];
        NSAssert1(offsetWithinSector <= _sectorSize, @"Requested byte offset falls within sector padding: %lu", (unsigned long)offset);
        
        NSUInteger bytesRemainingInSector = _sectorSize - offsetWithinSector;
        
        BOOL skipToNextSector = NO;
        
        //If there's not enough space remaining in the sector to fit another entry in, automatically skip to the next sector.
        if (bytesRemainingInSector < ADBISODirectoryRecordMinLength)
        {
            skipToNextSector = YES;
        }
        //Otherwise, check how long the next record is reported to be.
        else
        {
            uint8_t recordSize = 0;
            BOOL gotRecordSize = [self _getBytes: &recordSize range: NSMakeRange(offset, sizeof(uint8_t)) error: outError];
            if (!gotRecordSize)
            {
                return nil;
            }
            
            //Check the reported size of the next record. If it's zero, this should mean we've hit the
            //zeroed-out region at the end of a sector that didn't have enough space to accommodate another record.
            if (recordSize == 0)
            {
                skipToNextSector = YES;
            }
            
            //If the record indicates it would go over the end of the sector, treat this as a malformed record.
            else if (recordSize > bytesRemainingInSector)
            {
                NSAssert1(NO, @"Reported length of record would go over sector boundary: %lu", (unsigned long)recordSize);

                if (outError)
                {
                    NSDictionary *info = @{ NSURLErrorKey: self.sourceURL };
                    *outError = [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileReadCorruptFileError userInfo: info];
                }
                return nil;
            }
            
            //Otherwise, keep reading the rest of the record data from this sector.
            else
            {
                ADBISODirectoryRecord record;
                NSRange recordRange = NSMakeRange(offset, recordSize);
                BOOL retrievedRecord = [self _getBytes: &record range: recordRange error: outError];
                if (retrievedRecord)
                {
                    ADBISOFileEntry *entry = [ADBISOFileEntry entryFromDirectoryRecord: record inImage: self];
                    [entries addObject: entry];
                    
                    offset += recordSize;
                    readBytes += recordSize;
                }
                else
                {
                    return nil;
                }
            }
        }
        
        if (skipToNextSector)
        {
            readBytes += bytesRemainingInSector;
            offset += bytesRemainingInSector + sectorPadding;
        }
    }
    
    return entries;
}

@end



@implementation ADBISOFileEntry
@synthesize fileName = _fileName;
@synthesize version = _version;
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
        
        //If this record has extended attributes, they will be recorded at the start of the file extent
        //and the actual file data will be shoved into the next sector beyond this.
        NSUInteger extendedAttributeSectors = 0;
        if (record.extendedAttributeLength > 0)
            extendedAttributeSectors = ceilf(record.extendedAttributeLength / (float)image.sectorSize);
            
#if defined(__BIG_ENDIAN__)
        _dataRange.location    = (NSUInteger)[image _byteOffsetForSector: record.extentLBALocationBigEndian + extendedAttributeSectors];
        _dataRange.length      = record.extentDataLengthBigEndian;
#else
        _dataRange.location    = (NSUInteger)[image _byteOffsetForSector: record.extentLBALocationLittleEndian + extendedAttributeSectors];
        _dataRange.length      = record.extentDataLengthLittleEndian;
#endif
        
        //Parse the filename from the record
        NSString *identifier = [[NSString alloc] initWithBytes: record.identifier
                                                        length: record.identifierLength
                                                      encoding: NSASCIIStringEncoding];
        
        if (self.isDirectory)
        {
            self.fileName = identifier;
        }
        else
        {
            //ISO9660 filenames are stored in the format "FILENAME.EXE;1",
            //where the last component marks the version number of the file.
            NSArray *identifierComponents = [identifier componentsSeparatedByString: @";"];
            
            self.fileName   = [identifierComponents objectAtIndex: 0];
            
            //Some ISOs dispense with the version number altogether,
            //even though it's required by the spec.
            if (identifierComponents.count > 1)
            {
                self.version = [(NSString *)[identifierComponents objectAtIndex: 1] integerValue];
            }
            else
            {
                self.version = 1;
            }
            //Under ISO9660 spec, filenames will always have a file-extension dot even
            //if they have no extension. Strip off the trailing dot now.
            //CONFIRM: is this consistent with what ISO9660 consumers expect?
            if ([self.fileName hasSuffix: @"."])
                self.fileName = self.fileName.stringByDeletingPathExtension;
        }
        
        [identifier release];
        
        
        self.creationDate = [ADBISOImage _dateFromDateTime: record.recordingTime];
    }
    return self;
}

- (void) dealloc
{
    self.fileName = nil;
    self.creationDate = nil;
    
    [super dealloc];
}

- (BOOL) isDirectory
{
    return NO;
}

- (uint32_t) fileSize
{
    return _dataRange.length;
}

- (NSData *) contentsWithError: (NSError **)outError
{
    return [self.parentImage _dataInRange: _dataRange error: outError];
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
@synthesize cachedSubentries = _cachedSubentries;

- (void) dealloc
{
    self.cachedSubentries = nil;
    [super dealloc];
}

- (BOOL) isDirectory
{
    return YES;
}

- (NSArray *) subentriesWithError: (out NSError **)outError
           includingOlderVersions: (BOOL)includeOlderVersions
{
    //Populate the records the first time they are needed.
    if (!self.cachedSubentries)
    {
        self.cachedSubentries = [[_parentImage _fileEntriesInRange: _dataRange error: outError] retain];
    }
    
    if (includeOlderVersions)
    {
        return self.cachedSubentries;
    }
    else
    {
        //Filter the entries to eliminate older versions of the same filename.
        //TODO: should we cache this?
        NSMutableDictionary *subentriesByFilename = [[NSMutableDictionary alloc] initWithCapacity: self.cachedSubentries.count];
        for (ADBISOFileEntry *entry in self.cachedSubentries)
        {
            ADBISOFileEntry *existingEntry = [subentriesByFilename objectForKey: entry.fileName];
            if (!existingEntry || existingEntry.version < entry.version)
                [subentriesByFilename setObject: entry forKey: entry.fileName];
        }
        
        return subentriesByFilename.allValues;
    }
}

- (NSData *) contentsWithError: (NSError **)outError
{
    NSAssert(NO, @"Attempted to retrieve contents of directory.");
    return nil;
}
@end


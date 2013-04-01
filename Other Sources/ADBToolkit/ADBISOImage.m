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
#import "ADBFileHandle.h"
#import "NSURL+ADBFilesystemHelpers.h"

#pragma mark - Constants

const ADBISOFormat ADBISOFormatUnknown        = { 0, 0, 0 };
const ADBISOFormat ADBISOFormatAudio          = { 2352, 0, 0 };       //Audio track sector layout
const ADBISOFormat ADBISOFormatMode1          = { 2048, 16, 288 };    //Typical sector layout for BIN+CUE images
const ADBISOFormat ADBISOFormatMode1Unpadded  = { 2048, 0, 0 };       //Typical sector layout for ISO and CDR images
const ADBISOFormat ADBISOFormatMode2          = { 2336, 16, 0 };      //VCD sector layout (no error correction)

const ADBISOFormat ADBISOFormatXAMode2Form1   = { 2048, 24, 280 };
const ADBISOFormat ADBISOFormatXAMode2Form2   = { 2324, 24, 4 };

#pragma mark - Date helpers

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

@synthesize volumeName = _volumeName;
@synthesize pathCache = _pathCache;
@synthesize format = _format;
@synthesize handle = _handle;


#pragma mark - Class helper methods

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

+ (ADBISOFormat) _formatOfISOAtURL: (NSURL *)URL error: (out NSError **)outError
{
    ADBFileHandle *handle = [ADBFileHandle handleForURL: URL options: ADBOpenForReading error: outError];
    if (handle)
    {
        ADBISOFormat format = [self _formatOfISOInHandle: handle error: outError];
        [handle close];
        return format;
    }
    else
    {
        return ADBISOFormatUnknown;
    }
}

+ (ADBISOFormat) _formatOfISOInHandle: (id <ADBReadable, ADBSeekable>)handle error: (out NSError **)outError
{
    NSAssert(handle, @"No handle provided!");

    //Ordered by commonness, with the standard 2048-unpadded-sector ISO format first.
    ADBISOFormat formats[6] = {
        ADBISOFormatMode1Unpadded,
        ADBISOFormatMode1,
        ADBISOFormatMode2,
        ADBISOFormatAudio,
        
        ADBISOFormatXAMode2Form1,
        ADBISOFormatXAMode2Form2,
    };
    
    NSUInteger i, numFormats = 6;
    const char *comparison = "CD001";
    NSUInteger numBytes = strlen(comparison);
    char *magicBytes[5];
    
    for (i=0; i<numFormats; i++)
    {
        ADBISOFormat format = formats[i];
        NSUInteger rawSectorSize = format.sectorSize + format.sectorLeadIn + format.sectorLeadOut;
        NSUInteger firstDescriptorOffset = (rawSectorSize * ADBISOVolumeDescriptorSectorOffset) + format.sectorLeadIn;
        NSUInteger magicByteOffset = firstDescriptorOffset + 1;
        
        BOOL sought = [handle seekToOffset: magicByteOffset relativeTo: ADBSeekFromStart error: outError];
        if (!sought)
            return ADBISOFormatUnknown;
        
        NSUInteger bytesRead;
        BOOL readBytes = [handle readBytes: magicBytes maxLength: numBytes bytesRead: &bytesRead error: outError];
        if (!readBytes)
            return ADBISOFormatUnknown;
        
        if (bytesRead == numBytes)
        {
            BOOL magicBytesFound = (bcmp(magicBytes, comparison, 5) == 0);
            if (magicBytesFound)
                return format;
        }
        //Truncated file: throw back the error below
        else
        {
            break;
        }
    }
    
    //If we got this far, we could not determine the handle.
    if (outError)
    {
        *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                        code: NSFileReadCorruptFileError
                                    userInfo: NULL];
    }
    return ADBISOFormatUnknown;
}


#pragma mark - Initalization and cleanup

+ (id) imageWithContentsOfURL: (NSURL *)URL
                        error: (NSError **)outError
{
    return [[(ADBISOImage *)[self alloc] initWithContentsOfURL: URL error: outError] autorelease];
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
    if ([self.handle respondsToSelector: @selector(close)])
    {
        [(id)self.handle close];
    }
    self.handle = nil;
    
    self.baseURL = nil;
    self.volumeName = nil;
    self.pathCache = nil;
    [super dealloc];
}


#pragma mark - ADBFilesystemPathAccess API

- (BOOL) fileExistsAtPath: (NSString *)path isDirectory: (BOOL *)isDir
{
    path = path.stringByStandardizingPath; //Clear up . and .. path entries
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

//Currently, filetype determination relies entirely on the path extension.
- (NSString *) typeOfFileAtPath: (NSString *)path
{
    NSString *extension = path.pathExtension;
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)extension, NULL);
    return [(NSString *)UTI autorelease];
}

- (NSString *) typeOfFileAtPath: (NSString *)path matchingTypes: (NSSet *)comparisonUTIs
{
    NSString *UTI = [self typeOfFileAtPath: path];
    if (UTI)
    {
        for (NSString *comparisonUTI in comparisonUTIs)
        {
            if (UTTypeConformsTo((CFStringRef)UTI, (CFStringRef)comparisonUTI))
                return comparisonUTI;
        }
    }
    return nil;
}

- (BOOL) fileAtPath: (NSString *)path conformsToType: (NSString *)comparisonUTI
{
    NSString *UTI = [self typeOfFileAtPath: path];
    return (UTI != nil && UTTypeConformsTo((CFStringRef)UTI, (CFStringRef)comparisonUTI));
}


- (NSDictionary *) attributesOfFileAtPath: (NSString *)path
                                    error: (out NSError **)outError
{
    ADBISOFileEntry *entry = [self _fileEntryAtPath: path error: outError];
    return entry.attributes;
}

- (NSData *) contentsOfFileAtPath: (NSString *)path
                            error: (out NSError **)outError
{
    ADBISOFileEntry *entry = [self _fileEntryAtPath: path error: outError];
    
    if (entry.isDirectory)
    {
        if (outError)
        {
            NSDictionary *info = @{ NSFilePathErrorKey: path };
            
            //TODO: check what error Cocoa's own file-read methods produce when you pass them a directory.
            *outError = [NSError errorWithDomain: NSPOSIXErrorDomain
                                            code: EISDIR
                                        userInfo: info];
        }
        return nil;
    }
    return [entry contentsWithError: outError];
}

- (id <ADBFileHandleAccess, ADBReadable, ADBSeekable>) fileHandleAtPath: (NSString *)path
                                                                options: (ADBHandleOptions)options
                                                                  error: (out NSError **)outError;
{
    //TODO: make this an error instead?
    NSAssert(options == ADBOpenForReading, @"The only supported file mode for ISO filesystems is ADBOpenForReading.");
    
    ADBISOFileEntry *entry = [self _fileEntryAtPath: path error: outError];
    if (entry)
    {
        return [entry handleWithError: outError];
    }
    else
    {
        return NULL;
    }
}

- (FILE *) openFileAtPath: (NSString *)path
                   inMode: (const char *)accessMode
                    error: (out NSError **)outError
{
    ADBHandleOptions options = [ADBFileHandle optionsForPOSIXAccessMode: accessMode];
    return [[self fileHandleAtPath: path options: options error: outError] fileHandleAdoptingOwnership: YES];
}


- (NSError *) _readOnlyVolumeErrorForPath: (NSString *)path
{
    return [NSError errorWithDomain: NSCocoaErrorDomain
                               code: NSFileWriteVolumeReadOnlyError
                           userInfo: @{ NSFilePathErrorKey: path }];
}

- (BOOL) removeItemAtPath: (NSString *)path error: (out NSError **)outError
{
    if (outError)
        *outError = [self _readOnlyVolumeErrorForPath: path];
    return NO;
}

- (BOOL) copyItemAtPath: (NSString *)fromPath toPath: (NSString *)toPath error: (out NSError **)outError
{
    if (outError)
        *outError = [self _readOnlyVolumeErrorForPath: toPath];
    return NO;
}

- (BOOL) moveItemAtPath: (NSString *)fromPath toPath: (NSString *)toPath error: (out NSError **)outError
{
    if (outError)
        *outError = [self _readOnlyVolumeErrorForPath: fromPath];
    return NO;
}

- (BOOL) createDirectoryAtPath: (NSString *)path
   withIntermediateDirectories: (BOOL)createIntermediates
                         error: (out NSError **)outError
{
    if (outError)
        *outError = [self _readOnlyVolumeErrorForPath: path];
    return NO;
}

- (ADBISOEnumerator *) enumeratorAtPath: (NSString *)path
                                options: (NSDirectoryEnumerationOptions)mask
                           errorHandler: (ADBFilesystemPathErrorHandler)errorHandler
{
    return [[[ADBISOEnumerator alloc] initWithPath: path
                                       parentImage: self
                                           options: mask
                                      errorHandler: errorHandler] autorelease];
}


#pragma mark - Low-level filesystem API

- (uint32_t) _logicalOffsetForSector: (uint32_t)sector
{
    return sector * self.format.sectorSize;
}

- (uint32_t) _sectorForLogicalOffset: (uint32_t)offset
{
    return offset / self.format.sectorSize;
}

- (uint32_t) _logicalOffsetWithinSector: (uint32_t)offset
{
    return offset % self.format.sectorSize;
}

- (BOOL) _getBytes: (void *)buffer atLogicalRange: (NSRange)range error: (out NSError **)outError
{
    @synchronized(self.handle)
    {
        BOOL sought = [self.handle seekToOffset: range.location relativeTo: ADBSeekFromStart error: outError];
        if (!sought)
            return NO;
        
        NSUInteger bytesRead;
        BOOL read = [self.handle readBytes: buffer
                                 maxLength: range.length
                                 bytesRead: &bytesRead
                                     error: outError];
        
        //Treat truncated files as corrupt and an error condition.
        if (read && (bytesRead < range.length))
        {
            if (outError)
            {
                *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                                code: NSFileReadCorruptFileError
                                            userInfo: @{ NSURLErrorKey: self.baseURL }];
            }
            return NO;
        }
        else return read;
    }
}

- (NSData *) _dataInRange: (NSRange)range error: (out NSError **)outError;
{
    NSMutableData *data = [[NSMutableData alloc] initWithLength: range.length];
    BOOL populated = [self _getBytes: data.mutableBytes atLogicalRange: range error: outError];
    
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
    self.baseURL = URL;
    
    ADBFileHandle *rawHandle = [ADBFileHandle handleForURL: URL mode: "r" error: outError];
    if (!rawHandle)
        return NO;
    
    //Attempt to determine the format of the ISO.
    self.format = [self.class _formatOfISOInHandle: rawHandle error: outError];
    
    if (self.format.sectorSize == 0) //ADBISOUnknownFormat
        return NO;
    
    //If the ISO format has padding before or after each sector, then wrap the raw file handle
    //in a padding-aware handle to make reading easier.
    if (self.format.sectorLeadIn == 0 && self.format.sectorLeadOut == 0)
    {
        self.handle = rawHandle;
    }
    else
    {
        self.handle = [ADBBlockHandle handleForHandle: rawHandle
                                     logicalBlockSize: self.format.sectorSize
                                               leadIn: self.format.sectorLeadIn
                                              leadOut: self.format.sectorLeadOut];
    }
    
    //Search the volume descriptors to find the primary descriptor
    ADBISOPrimaryVolumeDescriptor descriptor;
    
    BOOL foundDescriptor = [self _getPrimaryVolumeDescriptor: &descriptor
                                                       error: outError];
    if (!foundDescriptor)
        return NO;
    
    //If we got this far, then we succeeded in loading the image. Hurrah!
    //Get on with parsing out whatever other info interests us from the primary volume descriptor.
    self.volumeName = [[[NSString alloc] initWithBytes: descriptor.volumeID
                                                length: ADBISOVolumeIdentifierLength
                                              encoding: NSASCIIStringEncoding] autorelease];
    
    //Prepare the path cache starting with the root directory file entry.
    ADBISODirectoryRecord rootDirectoryRecord;
    memcpy(&rootDirectoryRecord, &descriptor.rootDirectoryRecord, ADBISORootDirectoryRecordLength);
    ADBISOFileEntry *rootDirectory = [ADBISOFileEntry entryFromDirectoryRecord: rootDirectoryRecord inImage: self];
    
    self.pathCache = [NSMutableDictionary dictionaryWithObject: rootDirectory forKey: @"/"];
    
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
        NSUInteger offset = [self _logicalOffsetForSector: sectorIndex];
        
        NSRange descriptorTypeRange = NSMakeRange(offset, sizeof(uint8_t));
        BOOL readType = [self _getBytes: &type atLogicalRange: descriptorTypeRange error: outError];
        
        //Bail out if there was a read error or we hit the end of the file
        //(_getBytes:range:error: will have populated outError with the reason.)
        if (!readType)
            return NO;
        
        //We found the primary descriptor, read in the whole thing.
        if (type == ADBISOVolumeDescriptorTypePrimary)
        {
            NSRange descriptorRange = NSMakeRange(offset, sizeof(ADBISOPrimaryVolumeDescriptor));
            return [self _getBytes: descriptor atLogicalRange: descriptorRange error: outError];
        }
        //If we hit the end of the descriptors without finding a primary volume descriptor,
        //this indicates an invalid/incomplete ISO image.
        else if (type == ADBISOVolumeDescriptorTypeSetTerminator)
        {
            if (outError)
            {
                NSDictionary *info = @{ NSURLErrorKey: self.baseURL };
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
    //The ISO-9660 format mandates that filenames can only contain uppercase characters,
    //but some nonstandard ISOs contain lowercase filenames which can cause problems for
    //file lookups.
    
    NSAssert1(path != nil, @"No path provided to %@.", NSStringFromSelector(_cmd));
    
    //Normalize the path to be rooted in the root directory.
    if (![path hasPrefix: @"/"])
        path = [NSString stringWithFormat: @"/%@", path];
    
    //If the path ends in a slash, strip it off - our paths are cached without trailing slashes.
    if (path.length > 1 && [path hasSuffix: @"/"])
        path = [path substringToIndex: path.length - 1];
    
    //If we have a matching entry for this path, return it immediately.
    ADBISOFileEntry *matchingEntry = [self.pathCache objectForKey: path];
    
    //Otherwise, walk backwards through the parent directories looking for one that is in the cache.
    //Once we find one, add its children to the cache under their respective paths: and so on back up
    //to the originally requsted path.
    if (!matchingEntry)
    {
        NSString *parentPath = path.stringByDeletingLastPathComponent;
        if (![parentPath isEqualToString: path])
        {
            //Note recursion.
            ADBISODirectoryEntry *parentEntry = (ADBISODirectoryEntry *)[self _fileEntryAtPath: parentPath error: outError];
            
            //If our parent is a file, not a directory, then we'll fail out without a matching entry.
            if (parentEntry != (id)[NSNull null] && parentEntry.isDirectory)
            {   
                NSArray *siblingEntries = [parentEntry subentriesWithError: outError];
                if (!siblingEntries)
                    return nil;
                
                //Add the siblings into the cache and pluck out the one that matches us, if any
                for (ADBISOFileEntry *sibling in siblingEntries)
                {
                    NSString *siblingPath = [parentPath stringByAppendingPathComponent: sibling.fileName];
                    [self.pathCache setObject: sibling forKey: siblingPath];
                    
                    if ([siblingPath isEqualToString: path])
                        matchingEntry = sibling;
                }
            }
        }
    }
    
    if (matchingEntry && matchingEntry != (id)[NSNull null])
    {
        return matchingEntry;
    }
    else
    {
        //If no matching entry was found, record a null in the table so that we don't have to do an expensive
        //lookup again for something we know isn't there.
        if (!matchingEntry)
        {
            [self.pathCache setObject: [NSNull null] forKey: path];
        }
        
        if (outError)
        {
            NSDictionary *info = @{ NSFilePathErrorKey: path };
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileNoSuchFileError userInfo: info];
        }
        return nil;
    }
}

- (NSArray *) _fileEntriesInRange: (NSRange)range error: (out NSError **)outError
{
    NSData *entryData = [self _dataInRange: range error: outError];
    if (!entryData)
        return nil;
    
    NSMutableArray *entries = [NSMutableArray array];
    NSUInteger bytesToParse = entryData.length;
    NSUInteger index = 0;
    NSUInteger sectorSize = self.format.sectorSize;
    NSUInteger offsetFromSectorBoundary = range.location % sectorSize;
    
    while (index < bytesToParse)
    {
        NSUInteger bytesRemainingInSector = sectorSize - ((offsetFromSectorBoundary + index) % sectorSize);
        
        uint8_t recordSize = 0;
        [entryData getBytes: &recordSize range: NSMakeRange(index, sizeof(uint8_t))];
        
        //Check the reported size of the next record. If it's zero, this should mean we've hit the
        //zeroed-out region at the end of a sector that didn't have enough space to accommodate another record.
        if (recordSize == 0)
        {
            index += bytesRemainingInSector;
            continue;
        }
        
        //If the size indicates this is too short to be a record, or too long to fit in the sector, treat this as a malformed record.
        else if (recordSize < ADBISODirectoryRecordMinLength || recordSize > bytesRemainingInSector)
        {
            if (outError)
            {
                NSDictionary *info = @{ NSURLErrorKey: self.baseURL };
                *outError = [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileReadCorruptFileError userInfo: info];
            }
            return nil;
        }
        
        else
        {
            ADBISODirectoryRecord record;
            [entryData getBytes: &record range: NSMakeRange(index, recordSize)];
            
            ADBISOFileEntry *entry = [ADBISOFileEntry entryFromDirectoryRecord: record inImage: self];
            [entries addObject: entry];
                
            index += recordSize;
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
@synthesize hidden = _hidden;
@synthesize dataRange = _dataRange;

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
        self.parentImage = image;
        
        //If this record has extended attributes, they will be recorded at the start of the file extent
        //and the actual file data will be shoved into the next sector beyond this.
        NSUInteger numExtendedAttributeSectors = 0;
        if (record.extendedAttributeLength > 0)
            numExtendedAttributeSectors = ceilf(record.extendedAttributeLength / (float)image.format.sectorSize);
            
#if defined(__BIG_ENDIAN__)
        _dataRange.location    = (NSUInteger)[image _logicalOffsetForSector: record.extentLBALocationBigEndian + numExtendedAttributeSectors];
        _dataRange.length      = record.extentDataLengthBigEndian;
#else
        _dataRange.location    = (NSUInteger)[image _logicalOffsetForSector: record.extentLBALocationLittleEndian + numExtendedAttributeSectors];
        _dataRange.length      = record.extentDataLengthLittleEndian;
#endif
        
        if (record.identifierLength == 0)
            self.fileName = @""; //Should never occur
        else if (record.identifierLength == 1 && record.identifier[0] == '\0')
            self.fileName = @".";
        else if (record.identifierLength == 1 && record.identifier[0] == '\1')
            self.fileName = @"..";
        else
        {
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
        }
        
        self.creationDate = [ADBISOImage _dateFromDateTime: record.recordingTime];
        self.hidden = (record.fileFlags & ADBISOFileIsHidden) == ADBISOFileIsHidden;
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

- (ADBSubrangeHandle *) handleWithError: (out NSError **)outError
{
    return [ADBSubrangeHandle handleForHandle: self.parentImage.handle
                                        range: _dataRange];
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

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ (%@)", self.class, self.fileName];
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
{
    //Populate the records the first time they are needed.
    if (!self.cachedSubentries)
    {
        NSArray *subEntries = [self.parentImage _fileEntriesInRange: _dataRange error: outError];
        if (subEntries)
        {
            //Filter the entries to eliminate older versions of the same filename,
            //and to strip out . and .. entries.
            NSMutableDictionary *subentriesByFilename = [NSMutableDictionary dictionaryWithCapacity: subEntries.count];
            for (ADBISOFileEntry *entry in subEntries)
            {
                if ([entry.fileName isEqualToString: @"."] || [entry.fileName isEqualToString: @".."])
                {
                    continue;
                }
                
                //Strip out older versions of files, preserving only the latest recorded versions.
                ADBISOFileEntry *existingEntry = [subentriesByFilename objectForKey: entry.fileName];
                if (!existingEntry || existingEntry.version < entry.version)
                    [subentriesByFilename setObject: entry forKey: entry.fileName];
            }
            
            //The ISO will have (should have) ordered the entries by filename, but our NSDictionary
            //will have mixed them up again. Sort them again as a courtesy.
            NSComparator sortByFilename = ^NSComparisonResult(ADBISOFileEntry *file1, ADBISOFileEntry *file2) {
                return [file1.fileName caseInsensitiveCompare: file2.fileName];
            };
            self.cachedSubentries = [subentriesByFilename.allValues sortedArrayUsingComparator: sortByFilename];
        }
    }
    
    return self.cachedSubentries;
}

- (NSData *) contentsWithError: (NSError **)outError
{
    if (outError)
    {
        *outError = [NSError errorWithDomain: NSPOSIXErrorDomain
                                        code: EISDIR
                                    userInfo: nil];
    }
    return nil;
}

- (ADBSubrangeHandle *) handleWithError: (out NSError **)outError
{
    if (outError)
    {
        *outError = [NSError errorWithDomain: NSPOSIXErrorDomain
                                        code: EISDIR
                                    userInfo: nil];
    }
    return nil;
}

@end


@implementation ADBISOEnumerator
@synthesize parentImage = _parentImage;
@synthesize currentDirectoryPath = _currentDirectoryPath;
@synthesize errorHandler = _errorHandler;
@synthesize enumerationOptions = _enumerationOptions;

- (id) initWithPath: (NSString *)path
        parentImage: (ADBISOImage *)image
            options: (NSDirectoryEnumerationOptions)enumerationOptions
       errorHandler: (ADBFilesystemPathErrorHandler)errorHandler
{
    NSError *error = nil;
    NSArray *topLevelEntries = nil;
    ADBISODirectoryEntry *entryAtPath = (ADBISODirectoryEntry *)[image _fileEntryAtPath: path error: &error];
    if (entryAtPath)
    {
        if (entryAtPath.isDirectory)
        {
            topLevelEntries = [entryAtPath subentriesWithError: &error];
        }
        else
        {
            topLevelEntries = @[];
        }
    }
    
    if (topLevelEntries)
    {
        self = [self initWithRootNodes: topLevelEntries];
        
        if (self)
        {
            self.currentDirectoryPath = path;
            self.parentImage = image;
            self.errorHandler = errorHandler;
            _enumerationOptions = enumerationOptions;
        }
    }
    else
    {
        errorHandler(path, error);
        [self release];
        self = nil;
    }
    return self;
}

- (void) dealloc
{
    self.parentImage = nil;
    self.currentDirectoryPath = nil;
    self.errorHandler = nil;
    
    [super dealloc];
}

#pragma mark - ADBFilesystemPathEnumeration protocol implementations

- (id <ADBFilesystemPathAccess>) filesystem
{
    return self.parentImage;
}

- (NSDictionary *) fileAttributes
{
    return [(ADBISOFileEntry *)self.currentNode attributes];
}

#pragma mark - ADBTreeEnumerator callbacks

- (BOOL) shouldEnumerateNode: (ADBISOFileEntry *)node
{
    if ((self.enumerationOptions & NSDirectoryEnumerationSkipsHiddenFiles) && node.isHidden)
    {
        return NO;
    }
    else
    {
        return YES;
    }
}

- (BOOL) shouldEnumerateChildrenOfNode: (ADBISOFileEntry *)node
{
    if (!node.isDirectory)
        return NO;
    
    if (_skipDescendants || self.enumerationOptions & NSDirectoryEnumerationSkipsSubdirectoryDescendants)
    {
        return NO;
    }
    
    //Don't enumerate the children of hidden file entries either.
    if (![self shouldEnumerateNode: node])
        return NO;
    
    return YES;
}

- (NSArray *) childrenForNode: (ADBISODirectoryEntry *)node
{
    NSError *retrievalError = nil;
    NSArray *children = [node subentriesWithError: &retrievalError];
    if (!children)
    {
        //Ask our error handler whether to continue after a failure
        //to parse a directory. If not, cancel the enumeration immediately.
        BOOL shouldContinue = YES;
        if (self.errorHandler)
        {
            //FIXME: this path lookup assumes that the node being checked
            //is always the current node, but this is an implementation detail
            //of ADBTreeEnumerator's nextObject method and not guaranteed.
            NSString *pathForEntry = self.pathForCurrentNode;
            shouldContinue = self.errorHandler(pathForEntry, retrievalError);
        }
        
        if (!shouldContinue)
        {
            self.exhausted = YES;
        }
    }
    
    return children;
}

- (id) nextObject
{
    ADBISOFileEntry *nextEntry = [super nextObject];
    
    //Clear the skipDescendants flag after each iteration:
    //it should only apply to the very last path that was returned.
    _skipDescendants = NO;
    
    if (nextEntry)
    {
        NSString *pathForEntry = self.pathForCurrentNode;
        
        //Cache every entry that we traverse into our parent image's path cache to speed up path access later.
        [self.parentImage.pathCache setObject: nextEntry forKey: pathForEntry];
        
        return pathForEntry;
    }
    else
    {
        return nil;
    }
}

- (void) skipDescendants
{
    _skipDescendants = YES;
}


#pragma mark - Entry-to-path conversions

- (NSString *) pathForCurrentNode
{
    ADBISOFileEntry *entry = self.currentNode;
    if (entry == nil)
    {
        return nil;
    }
    else
    {
        return [self.currentDirectoryPath stringByAppendingPathComponent: entry.fileName];
    }
}

- (void) pushLevel: (NSArray *)nodesInLevel
{
    //Only update the directory path when adding levels above root: we'll be
    //receiving the canonical path for the root directory later on in the constructor,
    //after the root nodes have already been placed.
    if (self.level > 0)
    {
        ADBISODirectoryEntry *currentNode = self.currentNode;
        self.currentDirectoryPath = [self.currentDirectoryPath stringByAppendingPathComponent: currentNode.fileName];
    }
    
    [super pushLevel: nodesInLevel];
}

- (void) popLevel
{
    self.currentDirectoryPath = [self.currentDirectoryPath stringByDeletingLastPathComponent];
    [super popLevel];
}

@end
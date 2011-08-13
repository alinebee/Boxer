/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXISOImagePrivate.h"


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



@implementation BXISOImage
@synthesize sourcePath, volumeName;


+ (NSDate *) _dateFromDateTime: (BXISODateTime)dateTime
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

+ (NSDate *) _dateFromExtendedDateTime: (BXISOExtendedDateTime)dateTime
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

+ (id) imageFromContentsOfFile: (NSString *)path
                         error: (NSError **)outError
{
    id image = [[self alloc] initWithContentsOfFile: path error: outError];
    return [image autorelease];
}

- (id) init
{
    if ((self = [super init]))
    {
        sectorSize = BXISODefaultSectorSize;
        rawSectorSize = BXISODefaultSectorSize;
        leadInSize = BXISOLeadInSize;
    }
    return self;
}

- (id) initWithContentsOfFile: (NSString *)path
                        error: (NSError **)outError
{
    if ((self = [self init]))
    {
        sourcePath = [path copy];
        BOOL loaded = [self _loadImageAtPath: path error: outError];
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
    [sourcePath release], sourcePath = nil;
    [volumeName release], volumeName = nil;
    [imageHandle release], imageHandle = nil;
    
    [super dealloc];
}


#pragma mark -
#pragma mark Public API

- (NSDictionary *) attributesOfFileAtPath: (NSString *)path
                                    error: (NSError **)outError
{
    BXISOFileEntry *entry = [self _fileEntryAtPath: path error: outError];
    
    if (entry)
    {
        NSMutableDictionary *attrs = [NSMutableDictionary dictionaryWithCapacity: 4];
        
        BOOL isDirectory = [entry isKindOfClass: [BXISODirectoryEntry class]];
        NSString *fileType = isDirectory ? NSFileTypeDirectory : NSFileTypeRegular;
        
        [attrs setObject: fileType forKey: NSFileType];
        [attrs setObject: [entry creationDate] forKey: NSFileCreationDate];
        [attrs setObject: [entry creationDate] forKey: NSFileModificationDate];
        [attrs setObject: [NSNumber numberWithUnsignedLongLong: [entry fileSize]] forKey: NSFileSize];
        
        
        return attrs;
    }
    else return nil;
}

- (NSData *) contentsOfFileAtPath: (NSString *)path
                            error: (NSError **)outError
{
    BXISOFileEntry *entry = [self _fileEntryAtPath: path error: outError];
    if ([entry isKindOfClass: [BXISODirectoryEntry class]])
    {
        //TODO: populate error, we cannot read file data from a directory.
        return nil;
    }
    return [entry contents];
}

- (id <BXFilesystemEnumeration>) enumeratorAtPath: (NSString *)path
                                            error: (NSError **)outError
{
    NSAssert(NO, @"Not yet implemented.");
    return nil;
}


#pragma mark -
#pragma mark Low-level filesystem API

- (unsigned long long) _fileOffsetForSector: (NSUInteger)sector
{
    return (sector * rawSectorSize) + leadInSize;
}

- (unsigned long long) _seekToSector: (NSUInteger)sector
{
    unsigned long long offset = [self _fileOffsetForSector: sector];
    [imageHandle seekToFileOffset: offset];
    return offset;
}

- (NSData *) _readDataFromSectors: (NSUInteger)numSectors
{
    NSUInteger i;
    
    //Read the data in chunks of one sector each, allowing for any between-sector padding.
    NSMutableData *data = [NSMutableData dataWithCapacity: numSectors * sectorSize];
    for (i=0; i < numSectors; i++)
    {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        NSData *chunk = [imageHandle readDataOfLength: sectorSize];
        [data appendData: chunk];
        
        //Skip over any extra padding snuggled between each proper sector
        //(Needed for BIN/CUE images, which have 304 bytes of checksum data for each sector.)
        if (rawSectorSize > sectorSize)
        {
            NSUInteger paddingSize = rawSectorSize - sectorSize;
            [imageHandle seekToFileOffset: [imageHandle offsetInFile] + paddingSize];
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


- (BOOL) _loadImageAtPath: (NSString *)path
                    error: (NSError **)outError
{
    //Attempt to open the image at the source path
    imageHandle = [[NSFileHandle fileHandleForReadingFromURL: [NSURL fileURLWithPath: path]
                                                       error: outError] retain];
    
    //If the image couldn't be loaded, bail out now
    if (!imageHandle) return NO;
    
    //Determine the overall length of the image file
    [imageHandle seekToEndOfFile];
    imageSize = [imageHandle offsetInFile];
    
    //Search the volume descriptors to find the primary descriptor
    BOOL foundDescriptor = [self _getPrimaryVolumeDescriptor: &primaryVolumeDescriptor
                                                       error: outError];
    
    //If we didn't find a primary descriptor amongst the volume descriptors, fail out 
    if (!foundDescriptor) return NO;
    
    //Parse the volume name from the primary descriptor
    volumeName = [[NSString alloc] initWithBytes: primaryVolumeDescriptor.volumeID
                                          length: BXISOVolumeIdentifierLength
                                        encoding: NSASCIIStringEncoding];
    
    //If we got this far, then we succeeded in loading the image
    return YES;
}

- (BOOL) _getPrimaryVolumeDescriptor: (BXISOPrimaryVolumeDescriptor *)descriptor
                               error: (NSError **)outError
{
    NSUInteger sector = BXISOVolumeDescriptorSectorOffset;
    unsigned long long sectorOffset;
    uint8_t type;
    do
    {
        sectorOffset = [self _seekToSector: sector];
        [[imageHandle readDataOfLength: sizeof(uint8_t)] getBytes: &type];
        
        if (type == BXISOVolumeDescriptorTypePrimary)
        {
            //If we found the primary descriptor, then reewind back to the start and read in the whole thing.
            [imageHandle seekToFileOffset: sectorOffset];
            [[imageHandle readDataOfLength: sizeof(BXISOPrimaryVolumeDescriptor)] getBytes: &descriptor];
            return YES;
        }
        
        sector += 1;
    }
    //Stop once we find the volume descriptor terminator, or if we seek beyond the end of the image
    while ((type != BXISOVolumeDescriptorTypeSetTerminator) && (sectorOffset < imageSize));
    
    //TODO: populate an error here, as if we get here then this is an invalid/incomplete ISO image.
    return NO;
}

- (BXISOFileEntry *) _fileEntryAtPath: (NSString *)path
                                error: (NSError **)outError
{
    BXISODirectoryRecord record;
    BOOL succeeded = [self _getDirectoryRecord: &record atPath: path error: outError];
    if (succeeded)
    {
        return [BXISOFileEntry entryFromDirectoryRecord: record
                                                inImage: self];
    }
    else return nil;
}

- (BOOL) _getDirectoryRecord: (BXISODirectoryRecord *)record
                      atPath: (NSString *)path
                       error: (NSError **)outError
{
    NSUInteger sectorOffset = [self _offsetOfDirectoryRecordForPath: path];
    if (sectorOffset == NSNotFound) //Path does not exist
    {
        //TODO: populate outError
        return NO;
    }
    
    return YES;
}

- (NSUInteger) _offsetOfDirectoryRecordForPath: (NSString *)path
{
    //Populate the path lookup table the first time we need it
    if (!pathCache)
    {
        [self _populatePathCache];
    }
    
    NSNumber *offset = [pathCache objectForKey: path];
    if (offset) return [offset unsignedIntegerValue];
    else return NSNotFound;
}

- (void) _populatePathCache
{
    NSRange pathTableRange;
    
#if defined(__BIG_ENDIAN__)
    pathTableRange.location    = primaryVolumeDescriptor.pathTableLocationBigEndian;
    pathTableRange.length      = primaryVolumeDescriptor.pathTableSizeBigEndian;
#else
    pathTableRange.location    = primaryVolumeDescriptor.pathTableLocationLittleEndian;
    pathTableRange.length      = primaryVolumeDescriptor.pathTableSizeLittleEndian;
#endif
    
    //Now then, let's pull in the path table bit by bit
    NSUInteger offset;
    
    
    
}
@end



@implementation BXISOFileEntry
@synthesize fileName, fileSize, creationDate, parentImage;

+ (id) entryFromDirectoryRecord: (BXISODirectoryRecord)record
                        inImage: (BXISOImage *)image
{
    BOOL isDirectory = (record.fileFlags & BXISOFileIsDirectory);
    Class entryClass = isDirectory ? [BXISODirectoryEntry class] : [BXISOFileEntry class];
    return [[entryClass alloc] initWithDirectoryRecord: record inImage: image];
}

- (id) initWithDirectoryRecord: (BXISODirectoryRecord)record
                       inImage: (BXISOImage *)image
{
    if ((self = [self init]))
    {
        //Note: just assignment, not copying, as our parent image may cache
        //file entries and that would result in a retain cycle.
        parentImage = image;
        
        //Parse the record to determine file size, name and other such things
        [self _loadFromDirectoryRecord: record];
    }
    return self;
}

- (void) dealloc
{
    [fileName release], fileName = nil;
    [creationDate release], creationDate = nil;
    
    [super dealloc];
}

- (void) _loadFromDirectoryRecord: (BXISODirectoryRecord)record
{
#if defined(__BIG_ENDIAN__)
    sectorRange.location    = record.extentLocationBigEndian;
    sectorRange.length      = record.dataLengthBigEndian;
#else
    sectorRange.location    = record.extentLocationLittleEndian;
    sectorRange.length      = record.dataLengthLittleEndian;
#endif
    
    //Parse the filename from the record
    NSString *identifier = [[NSString alloc] initWithBytes: record.identifier
                                                    length: record.identifierLength
                                                  encoding: NSASCIIStringEncoding];
    
    //ISO9660 filenames are stored in the format "FILENAME.EXE;1", where the last
    //component marks the revision of the file (for multi-session discs I guess.)
    fileName = [[identifier componentsSeparatedByString: @";"] objectAtIndex: 0];
    [identifier release];
    
    creationDate = [[BXISOImage _dateFromDateTime: record.recordingTime] retain];
}

- (NSData *) contents
{
    return [parentImage _readDataFromSectorRange: sectorRange];
}

@end


@implementation BXISODirectoryEntry

- (NSArray *) subpaths
{
    NSAssert(NO, @"Not yet implemented.");
    return nil;
}

- (NSData *) contents
{
    NSAssert(NO, @"Not yet implemented.");
    return nil;
}
@end


/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//This header defines private constants and structs used by BXBinCueParser and its helper classes.


#import "BXISOImage.h"


#pragma mark -
#pragma mark Private method declarations

@class BXISOFileEntry;
@class BXISODirectoryEntry;

@interface BXISOImage ()

#pragma mark -
#pragma mark Private helper class methods

//Returns autoreleased NSDate instances created from the date and time
//data in the specified ISO-format date struct.
+ (NSDate *) _dateFromExtendedDateTime: (BXISOExtendedDateTime) dateTime;
+ (NSDate *) _dateFromDateTime: (BXISODateTime) dateTime;


//Opens the image at the specified path for reading and reads in its header data.
//Returns NO and populates outError if there was an error loading the image.
- (BOOL) _loadImageAtPath: (NSString *)path
                    error: (NSError **)outError;


//Finds the primary volume descriptor and loads it into descriptor. Returns NO
//and populates outError if no primary volume descriptor can be found.
- (BOOL) _getPrimaryVolumeDescriptor: (BXISOPrimaryVolumeDescriptor *)descriptor
                               error: (NSError **)outError;


- (BXISOFileEntry *) _fileEntryAtPath: (NSString *)path
                                error: (NSError **)outError;

//Populates entry with the directory entry record for the file at the specified path.
//Returns NO and populates outError if the path could not be located.
- (BOOL) _getDirectoryRecord: (BXISODirectoryRecord *)record
                      atPath: (NSString *)path
                       error: (NSError **)outError;

//Returns the sector offset at which the directory record for the specified path can be found.
- (NSUInteger) _offsetOfDirectoryRecordForPath: (NSString *)path;



//Returns the byte offset for the specified sector.
- (unsigned long long) _fileOffsetForSector: (NSUInteger)sector;

//Move the file pointer to the start of the specified sector.
//Returns the byte offset of that sector.
- (unsigned long long) _seekToSector: (NSUInteger)sector;

//Reads data from the current byte offset for the specified number of sectors.
//USAGE NOTE: this should be used in combination with _seekToSector, not with
//NSFileHandle seekToFileOffset. Sector data should always be read from and
//up to even sector boundaries.
- (NSData *) _readDataFromSectors: (NSUInteger)numSectors;

//Returns the raw data at the specified sector range.
- (NSData *) _readDataFromSectorRange: (NSRange)range;

//Populate a cache of all paths in the image filesystem.
- (void) _populatePathCache;
@end



//A class abstractly representing a file or directory within the image.
//Used internally by BXISOImage and subclasses, and not exposed by the public API.
@interface BXISOFileEntry : NSObject
{
    unsigned long long fileSize;
    NSRange sectorRange;
    NSString *fileName;
    BXISOImage *parentImage;
    NSDate *creationDate;
}

#pragma mark -
#pragma mark Properties

//Returns the filename of the entry. File entries are not path-aware.
@property (readonly, nonatomic) NSString *fileName;

//Returns the filesize in bytes of the file at the specified path.
@property (readonly, nonatomic) unsigned long long fileSize;

//The byte contents of this file.
@property (readonly, nonatomic) NSData *contents;

//The image in which this file is located.
@property (readonly, nonatomic) BXISOImage *parentImage;

//The date at which the file was written to the image.
@property (readonly, nonatomic) NSDate *creationDate;


#pragma mark -
#pragma mark Methods

//Returns an autoreleased file entry constructed from the specified record taken from
//the specified ISO image.
+ (id) entryFromDirectoryRecord: (BXISODirectoryRecord)record
                        inImage: (BXISOImage *)image;

- (id) initWithDirectoryRecord: (BXISODirectoryRecord)record
                       inImage: (BXISOImage *)image;

- (void) _loadFromDirectoryRecord: (BXISODirectoryRecord)record;

@end


@interface BXISODirectoryEntry : BXISOFileEntry

//Overridden to raise an NSNotImplemented exception.
@property (readonly, nonatomic) NSData *contents;

//An array of BXISOFileEntry and BXISODirectoryEntry objects
//for all files within this directory.
@property (readonly, nonatomic) NSArray *subpaths;

@end
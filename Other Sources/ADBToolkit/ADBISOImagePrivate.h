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

//This header defines private constants and structs used by ADBISOImage and its related classes.


#import "ADBISOImage.h"


#pragma mark -
#pragma mark Private method declarations

@class ADBISOFileEntry;
@class ADBISODirectoryEntry;

@interface ADBISOImage ()

#pragma mark -
#pragma mark Private helper class methods

//Returns autoreleased NSDate instances created from the date and time
//data in the specified ISO-format date struct.
+ (NSDate *) _dateFromExtendedDateTime: (ADBISOExtendedDateTime) dateTime;
+ (NSDate *) _dateFromDateTime: (ADBISODateTime) dateTime;


//Opens the image at the specified path for reading and reads in its header data.
//Returns NO and populates outError if there was an error loading the image.
- (BOOL) _loadImageAtPath: (NSString *)path
                    error: (NSError **)outError;


//Finds the primary volume descriptor and loads it into descriptor. Returns NO
//and populates outError if no primary volume descriptor can be found.
- (BOOL) _getPrimaryVolumeDescriptor: (ADBISOPrimaryVolumeDescriptor *)descriptor
                               error: (NSError **)outError;


- (ADBISOFileEntry *) _fileEntryAtPath: (NSString *)path
                                 error: (NSError **)outError;

//Populates entry with the directory entry record for the file at the specified path.
//Returns NO and populates outError if the path could not be located.
- (BOOL) _getDirectoryRecord: (ADBISODirectoryRecord *)record
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
//Used internally by ADBISOImage and subclasses, and not exposed by the public API.
@interface ADBISOFileEntry : NSObject
{
    unsigned long long fileSize;
    NSRange sectorRange;
    NSString *fileName;
    ADBISOImage *parentImage;
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
@property (readonly, nonatomic) ADBISOImage *parentImage;

//The date at which the file was written to the image.
@property (readonly, nonatomic) NSDate *creationDate;


#pragma mark -
#pragma mark Methods

//Returns an autoreleased file entry constructed from the specified record taken from
//the specified ISO image.
+ (id) entryFromDirectoryRecord: (ADBISODirectoryRecord)record
                        inImage: (ADBISOImage *)image;

- (id) initWithDirectoryRecord: (ADBISODirectoryRecord)record
                       inImage: (ADBISOImage *)image;

- (void) _loadFromDirectoryRecord: (ADBISODirectoryRecord)record;

@end


@interface ADBISODirectoryEntry : ADBISOFileEntry

//Overridden to raise an NSNotImplemented exception.
@property (readonly, nonatomic) NSData *contents;

//An array of ADBISOFileEntry and ADBISODirectoryEntry objects
//for all files within this directory.
@property (readonly, nonatomic) NSArray *subpaths;

@end
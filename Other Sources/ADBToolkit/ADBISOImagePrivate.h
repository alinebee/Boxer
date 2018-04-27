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
#import "ADBFilesystem.h"

#pragma mark - Private method declarations

@class ADBISOFileEntry;
@class ADBISODirectoryEntry;

@interface ADBISOImage ()

@property (copy, nonatomic) NSString *volumeName;
@property (assign, nonatomic) ADBISOFormat format;

@property (strong, nonatomic) id <ADBReadable, ADBSeekable> handle;

@property (strong, nonatomic) NSMutableDictionary *pathCache;


#pragma mark - Private helper class methods

/// Autodetects the format of the ISO at the specified location.
/// This is done by scanning for strings at known offsets in each
/// of the formats in turn until one matches. Returns ADBISOFormatUnknown
/// and populates outError if there was a read error or the format could
/// not be determined.
+ (ADBISOFormat) _formatOfISOAtURL: (NSURL *)URL error: (out NSError **)outError;
+ (ADBISOFormat) _formatOfISOInHandle: (id <ADBReadable, ADBSeekable>)handle error: (out NSError **)outError;


/// Returns autoreleased @c NSDate instances created from the date and time
/// data in the specified ISO-format date struct.
+ (NSDate *) _dateFromExtendedDateTime: (ADBISOExtendedDateTime) dateTime;
+ (NSDate *) _dateFromDateTime: (ADBISODateTime) dateTime;


//Opens the image at the specified path for reading and reads in its header data.
//Returns NO and populates outError if there was an error loading the image.
//Called by initWithContentsOfURL:error:.
- (BOOL) _loadImageAtURL: (NSURL *)URL
                   error: (out NSError **)outError;

//Finds the primary volume descriptor and loads it into descriptor. Returns NO
//and populates outError if no primary volume descriptor can be found.
//Called by _loadImageAtURL:error:.
- (BOOL) _getPrimaryVolumeDescriptor: (ADBISOPrimaryVolumeDescriptor *)descriptor
                               error: (out NSError **)outError;

//Returns a file entry which can be used for reading file data
//(or, in the case of directory entries, reading subpaths.)
- (ADBISOFileEntry *) _fileEntryAtPath: (NSString *)path
                                 error: (out NSError **)outError;

//Returns an array of file entries parsed from the specified range of the image.
//This takes into account the ISO9660 format's conventions for storing directory records:
//They are packed together tightly in sectors but a single record will not span multiple sectors.
- (NSArray *) _fileEntriesInRange: (NSRange)range error: (out NSError **)outError;

//Populates buffer with the data at the specified range. Ranges that span sector boundaries will
//take into account sector padding. Note that the requested range is expected to be in logical bytes,
//without sector padding or lead-in. These will be handled automatically by the function itself.
- (BOOL) _getBytes: (void *)buffer atLogicalRange: (NSRange)range error: (out NSError **)outError;

//Methods to convert back and forth from byte offsets to sectors.
- (uint32_t) _logicalOffsetForSector: (uint32_t)sector;
- (uint32_t) _sectorForLogicalOffset: (uint32_t)offset;
- (uint32_t) _logicalOffsetWithinSector: (uint32_t)offset;

//Returns an NSData object populated with the data at the specified range.
//Returns nil and populates outError on error (including requesting a range beyond the end of the file.)
- (NSData *) _dataInRange: (NSRange)range error: (out NSError **)outError;

@end



//A class abstractly representing a file or directory within the image.
//Used internally by ADBISOImage and subclasses, and not exposed by the public API.
@class ADBSubrangeHandle;
@interface ADBISOFileEntry : NSObject
{
    NSRange _dataRange;
    NSString *_fileName;
    NSUInteger _version;
    __unsafe_unretained ADBISOImage *_parentImage;
    NSDate *_creationDate;
    BOOL _hidden;
}

#pragma mark -
#pragma mark Properties

//Returns the filename of the entry. File entries are not path-aware.
@property (copy, nonatomic) NSString *fileName;

//The ISO9660 version of this file.
@property (assign, nonatomic) NSUInteger version;

//Returns the filesize in bytes of the file at the specified path.
@property (readonly, nonatomic) uint32_t fileSize;

//Whether this file is marked as hidden in its metadata.
@property (assign, nonatomic, getter=isHidden) BOOL hidden;

//The standard file attributes of this file.
//Equivalent to the output of NSFileManager's attributesOfFileAtPath:.
@property (weak, readonly, nonatomic) NSDictionary<NSFileAttributeKey,id> *attributes;

//The image in which this file is located.
@property (assign, nonatomic) ADBISOImage *parentImage;

//The date at which the file was written to the image.
@property (copy, nonatomic) NSDate *creationDate;

//Whether this file record represents a directory. Returns NO for ADBISOFileEntry
//instances, YES for ADBISODirectoryEntry instances.
@property (readonly, nonatomic) BOOL isDirectory;

//The area of the parent image where this file's data is located.
@property (readonly, nonatomic) NSRange dataRange;

#pragma mark -
#pragma mark Methods

//Returns an autoreleased file entry constructed from the specified record taken from
//the specified ISO image.
+ (id) entryFromDirectoryRecord: (ADBISODirectoryRecord)record
                        inImage: (ADBISOImage *)image;

- (id) initWithDirectoryRecord: (ADBISODirectoryRecord)record
                       inImage: (ADBISOImage *)image;

//Returns the contents of this file. Returns nil and populates outError
//if the contents could not be read.
- (NSData *) contentsWithError: (out NSError **)outError;

- (ADBSubrangeHandle *) handleWithError: (out NSError **)outError;

@end


@interface ADBISODirectoryEntry : ADBISOFileEntry
{
    NSArray *_cachedSubentries;
}
//Populated by subrecordsWithError: the first time it is needed.
@property (strong, nonatomic) NSArray *cachedSubentries;

//Returns an array of ADBISOFileEntry and ADBISODirectoryEntry objects
//for all files within this directory (except the spurious . and .. entries.)
//Returns nil and populates outError if the records could not be read.
- (NSArray *) subentriesWithError: (out NSError **)outError;

@end


@interface ADBISOEnumerator : ADBTreeEnumerator <ADBFilesystemPathEnumeration>
{
    NSString *_currentDirectoryPath;
    BOOL _skipDescendants;
    NSDirectoryEnumerationOptions _enumerationOptions;
    ADBFilesystemPathErrorHandler _errorHandler;
}

//The image which this enumerator is iterating.
@property (unsafe_unretained, nonatomic) ADBISOImage *parentImage;

//The filesystem path of the directory we are currently iterating, relative to the root of the image.
@property (copy, nonatomic) NSString *currentDirectoryPath;

//The error handler to call when we encounter errors traversing the directory structure.
@property (copy, nonatomic) ADBFilesystemPathErrorHandler errorHandler;

//The enumeration options provided when the enumerator was created.
@property (readonly, nonatomic) NSDirectoryEnumerationOptions enumerationOptions;

- (id) initWithPath: (NSString *)path
        parentImage: (ADBISOImage *)image
            options: (NSDirectoryEnumerationOptions)enumerationOptions
       errorHandler: (ADBFilesystemPathErrorHandler)errorHandler;

@end

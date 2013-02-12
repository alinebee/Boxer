/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//This header defines constants and structures used internally by BXISOImage and its subclasses.
//They are not used by BXISOImage's public API.


#define BXISODefaultSectorSize 2048
#define BXBINCUERawSectorSize 2532

#define BXISOLeadInSize 0
#define BXBINCUELeadInSize 16

#define BXISOVolumeDescriptorSectorOffset 0x10
#define BXISOVolumeDescriptorSize BXISODefaultSectorSize

#define BXISOVolumeIdentifierLength 32


enum {
    BXISOFileIsHidden               = 1 << 0,
    BXISOFileIsDirectory            = 1 << 1,
    BXISOFileIsAssociated           = 1 << 2,
    BXISOFileExtendedMetadata       = 1 << 3,
    BXISOFileExtendedPermissions    = 1 << 4,
    BXISOFileFlagReserved1          = 1 << 5,
    BXISOFileFlagReserved2          = 1 << 6,
    BXISOFileSpansMultipleExtents   = 1 << 7
};
typedef uint8_t BXISODirectoryEntryOptions;


enum {
    BXISOVolumeDescriptorTypeBootRecord     = 0,
    BXISOVolumeDescriptorTypePrimary        = 1,
    BXISOVolumeDescriptorTypeSupplementary  = 2,
    BXISOVolumeDescriptorTypePartition      = 3,
    BXISOVolumeDescriptorTypeSetTerminator  = 255
};
typedef uint8_t BXISOVolumeDescriptorType;


#pragma mark -
#pragma mark ISO file structure definitions

typedef struct {
	uint8_t year;       //From 0-99: add 1900 to get full year
	uint8_t month;      //From 1-12
	uint8_t day;        //From 1-31
	uint8_t hour;       //From 0-23
	uint8_t minute;     //From 0-59
	uint8_t second;     //From 0-59
	int8_t gmtOffset;   //From -48 to +52 in 15-minute intervals
} __attribute__ ((packed)) BXISODateTime;


//Note that unlike BXISODateTime, these fields are stored as char
//arrays without null terminators.
typedef struct {
	uint8_t year[4];        //e.g. {'1','9','0','0')
	uint8_t month[2];       //e.g. {'1','2'}
	uint8_t day[2];         //e.g. {'3','1'}
	uint8_t hour[2];        //e.g. {'2','3'}
	uint8_t minute[2];      //e.g. {'5','9'}
	uint8_t second[2];      //e.g. {'5','9'}
	uint8_t hsecond[2];     //e.g. {'9','9'}
	int8_t gmtOffset;       //From -48 to +52 in 15-minute intervals
} __attribute__ ((packed)) BXISOExtendedDateTime;


typedef struct {
	uint8_t type;           //Always 0x01.
	uint8_t identifier[5];  //Always 'CD001'.
	uint8_t version;        //Always 0x01.
    
	uint8_t unused1[1];
    
	uint8_t systemID[32];
	uint8_t volumeID[BXISOVolumeIdentifierLength];
    
	uint8_t unused2[8];
    
	//Specified as the number of logical blocks in the volume:
    //see logicalBlockSize below.
	uint32_t volumeSpaceSizeLittleEndian;   
    uint32_t volumeSpaceSizeBigEndian;
    
	uint8_t unused3[32];
    
	uint16_t volumeSetSizeLittleEndian;
	uint16_t volumeSetSizeBigEndian;
    
	uint16_t volumeSequenceNumberLittleEndian;
	uint16_t volumeSequenceNumberBigEndian;
    
	uint16_t logicalBlockSizeLittleEndian;
	uint16_t logicalBlockSizeBigEndian;
    
	uint32_t pathTableSizeLittleEndian;
	uint32_t pathTableSizeBigEndian;
    
	uint32_t pathTableLocationLittleEndian;
	uint32_t optionalPathTableLocationLittleEndian;
	uint32_t pathTableLocationBigEndian;
	uint32_t optionalPathTableLocationBigendian;
    
	uint8_t rootDirectoryEntry[34];
    
    uint8_t volumeSetIdentifier[128];
    uint8_t publisherIdentifier[128];
    uint8_t preparerIdentifier[128];
    uint8_t applicationIdentifier[128];
    
    uint8_t copyrightFileName[37];
    uint8_t abstractFileName[37];
    uint8_t bibliographicFileName[37];
    
    BXISOExtendedDateTime creationTime;
    BXISOExtendedDateTime modificationTime;
    BXISOExtendedDateTime expirationTime;
    BXISOExtendedDateTime effectiveTime;
    
    uint8_t fileStructureVersion;   //Always 0x01.
    uint8_t unused4[1];
    uint8_t applicationData[512];
    uint8_t unused5[653];
} __attribute__ ((packed)) BXISOPrimaryVolumeDescriptor;


typedef struct {
	uint8_t recordLength;
	uint8_t extendedAttributeLength;
	uint32_t extentLocationLittleEndian;
	uint32_t extentLocationBigEndian;
	uint32_t dataLengthLittleEndian;
	uint32_t dataLengthBigEndian;
    
    BXISODateTime recordingTime;
	
    BXISODirectoryEntryOptions fileFlags;
    
	uint8_t fileUnitSize;
	uint8_t interleaveGapSize;
	uint16_t volumeSequenceNumberLittleEndian;
	uint16_t volumeSeqeunceNumberBigEndian;
    
	uint8_t identifierLength;
	
    uint8_t identifier[222];
    
} __attribute__ ((packed)) BXISODirectoryRecord;

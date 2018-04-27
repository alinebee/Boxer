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


//This header defines constants and structures used internally by ADBISOImage
//and its subclasses. They are not exposed by ADBISOImage's public API.


#define ADBISOVolumeDescriptorSectorOffset 0x10
#define ADBISOVolumeDescriptorSize 2048

#define ADBISOVolumeIdentifierLength 32

#define ADBISODirectoryRecordMinLength 34
#define ADBISORootDirectoryRecordLength 34

typedef NS_OPTIONS(uint8_t, ADBISODirectoryRecordOptions) {
    ADBISOFileIsHidden               = 1 << 0,
    ADBISOFileIsDirectory            = 1 << 1,
    ADBISOFileIsAssociated           = 1 << 2,
    ADBISOFileExtendedMetadata       = 1 << 3,
    ADBISOFileExtendedPermissions    = 1 << 4,
    ADBISOFileFlagReserved1          = 1 << 5,
    ADBISOFileFlagReserved2          = 1 << 6,
    ADBISOFileSpansMultipleExtents   = 1 << 7
};


typedef NS_ENUM(uint8_t, ADBISOVolumeDescriptorType) {
    ADBISOVolumeDescriptorTypeBootRecord     = 0,
    ADBISOVolumeDescriptorTypePrimary        = 1,
    ADBISOVolumeDescriptorTypeSupplementary  = 2,
    ADBISOVolumeDescriptorTypePartition      = 3,
    ADBISOVolumeDescriptorTypeSetTerminator  = 255
};


#pragma mark -
#pragma mark ISO file structure definitions

typedef struct {
	uint8_t year;       //!< From 0-99: add 1900 to get full year
	uint8_t month;      //!< From 1-12
	uint8_t day;        //!< From 1-31
	uint8_t hour;       //!< From 0-23
	uint8_t minute;     //!< From 0-59
	uint8_t second;     //!< From 0-59
	int8_t gmtOffset;   //!< From -48 to +52 in 15-minute intervals
} __attribute__ ((packed)) ADBISODateTime;


/// Note that unlike ADBISODateTime, these fields are stored as char
/// arrays without null terminators.
typedef struct {
	uint8_t year[4];        //!< e.g. {'1','9','0','0')
	uint8_t month[2];       //!< e.g. {'1','2'}
	uint8_t day[2];         //!< e.g. {'3','1'}
	uint8_t hour[2];        //!< e.g. {'2','3'}
	uint8_t minute[2];      //!< e.g. {'5','9'}
	uint8_t second[2];      //!< e.g. {'5','9'}
	uint8_t hsecond[2];     //!< e.g. {'9','9'}
	int8_t gmtOffset;       //!< From -48 to +52 in 15-minute intervals
} __attribute__ ((packed)) ADBISOExtendedDateTime;


typedef struct {
	uint8_t type;           //!< Always 0x01.
	uint8_t identifier[5];  //!< Always 'CD001'.
	uint8_t version;        //!< Always 0x01.
    
	uint8_t unused1[1];
    
	uint8_t systemID[32];
	uint8_t volumeID[ADBISOVolumeIdentifierLength];
    
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
    
	uint32_t pathTableLBALocationLittleEndian;
	uint32_t optionalPathTableLBALocationLittleEndian;
	uint32_t pathTableLBALocationBigEndian;
	uint32_t optionalPathTableLBALocationBigendian;
    
	uint8_t rootDirectoryRecord[ADBISORootDirectoryRecordLength];
    
    uint8_t volumeSetIdentifier[128];
    uint8_t publisherIdentifier[128];
    uint8_t preparerIdentifier[128];
    uint8_t applicationIdentifier[128];
    
    uint8_t copyrightFileName[37];
    uint8_t abstractFileName[37];
    uint8_t bibliographicFileName[37];
    
    ADBISOExtendedDateTime creationTime;
    ADBISOExtendedDateTime modificationTime;
    ADBISOExtendedDateTime expirationTime;
    ADBISOExtendedDateTime effectiveTime;
    
    uint8_t fileStructureVersion;   //Always 0x01.
    uint8_t unused4[1];
    uint8_t applicationData[512];
    uint8_t unused5[653];
} __attribute__ ((packed)) ADBISOPrimaryVolumeDescriptor;


typedef struct {
	uint8_t recordLength;
	uint8_t extendedAttributeLength;
	uint32_t extentLBALocationLittleEndian;
	uint32_t extentLBALocationBigEndian;
	uint32_t extentDataLengthLittleEndian;
	uint32_t extentDataLengthBigEndian;
    
    ADBISODateTime recordingTime;
	
    ADBISODirectoryRecordOptions fileFlags;
    
	uint8_t fileUnitSize;
	uint8_t interleaveGapSize;
	uint16_t volumeSequenceNumberLittleEndian;
	uint16_t volumeSeqeunceNumberBigEndian;
    
	uint8_t identifierLength;
	
    uint8_t identifier[222];
    
} __attribute__ ((packed)) ADBISODirectoryRecord;


typedef struct {
    NSUInteger sectorSize;
    NSUInteger sectorLeadIn;
    NSUInteger sectorLeadOut;
} ADBISOFormat;

//q.v. http://en.wikipedia.org/wiki/CD-ROM#Extensions for details of these track modes.
extern const ADBISOFormat ADBISOFormatUnknown;
extern const ADBISOFormat ADBISOFormatAudio;
extern const ADBISOFormat ADBISOFormatMode1;
extern const ADBISOFormat ADBISOFormatMode1Unpadded;    //!< Typical sector layout for ISO and CDR images
extern const ADBISOFormat ADBISOFormatMode2;            //!< VCD sector layout (no error correction)

extern const ADBISOFormat ADBISOFormatXAMode2Form1;
extern const ADBISOFormat ADBISOFormatXAMode2Form2;

/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//This header defines constants and structures used for parsing the headers of executable files.

/// Original DOS EXE type retained by all executables.
#define BXDOSExecutableMarker			0x5A4D //MZ in little-endian

/// Windows EXE types: unlikely to be DOS-compatible but can
/// be found in some hybrid DOS/Windows EXEs and DOS extenders.
#define BX16BitNewExecutableMarker		0x454E //NE
#define BX32BitPortableExecutableMarker	0x4550 //PE

/// OS/2 EXE types, also used by some DOS extenders.
#define BX16BitLinearExecutableMarker	0x454C //LE
#define BX32BitLinearExecutableMarker	0x584C //LX

/// Very rare EXE/VXD types that are never DOS-compatible.
#define BXW3ExecutableMarker			0x3357 //W3
#define BXW4ExecutableMarker			0x3457 //W4

/// Page size in bytes. Used for calculating expected filesize.
#define BXExecutablePageSize					512

/// Expected address of relocation table in new-style executables.
#define BXExtendedExecutableRelocationAddress	0x40

/// Expected new-header lengths for NE and PE executables.
#define BX16BitNewExecutableHeaderLength		64
#define BX32BitPortableExecutableHeaderLength	24

/// The maximum expected length for a "This program is for Windows only"
/// warning stub program in a Windows or OS/2 (NE, PE, LE or LX) executable.
/// Stubs larger than this will be assumed to contain a legitimate DOS program
/// alongside the windows program, so the entire executable will be considered
/// DOS-compatible.
/// (This is a liberal guess: stubs of length 128 and 256 and 3584 have
/// been found so far, and it's unlikely that a legitimate DOS-compatible EXE
/// file with one of those extended types will be smaller than 3.5kb.)
#define BXMaxWarningStubLength 3584


/// Original DOS header format, with extended data.
/// q.v.: http://www.delphidabbler.com/articles?article=8&part=2
/// http://www.fileformat.info/format/exe/corion-mz.htm
typedef struct {
	uint16_t typeMarker;				//!< Filetype marker (always "MZ" for executables)
    uint16_t lastPageSize;			//!< Bytes on last page of file
    uint16_t numPages;				//!< Pages in file
    uint16_t numRelocations;			//!< Relocations
    uint16_t numHeaderParagraphs;		//!< Size of header in paragraphs
	uint16_t minExtraParagraphs;		//!< Minimum extra paragraphs needed
	uint16_t maxExtraParagraphs;		//!< Maximum extra paragraphs needed
    uint16_t ssValue;					//!< Initial (relative) SS value
    uint16_t spValue;					//!< Initial SP value
    uint16_t checksum;				//!< Checksum
    uint16_t ipValue;					//!< Initial IP value
    uint16_t csValue;					//!< Initial (relative) CS value
    uint16_t relocationTableAddress;	//!< Address of relocation table (always 0x40 for new-style executables)
    uint16_t overlayNumber;			//!< Overlay number
	
	//The rest of these are part of an extended header present in new-style executables
    uint16_t reserved[4];				//!< Reserved
    uint16_t oemIdentifier;			//!< OEM identifier (for oemInfo)
    uint16_t oemInfo;					//!< OEM info (oemIdentifier-specific)
    uint16_t reserved2[10];			//!< Reserved
    uint32_t newHeaderAddress;			//!< File address of new exe header
} __attribute__ ((packed)) BXDOSExecutableHeader;


//IMPLEMENTATION NOTE: the packed attribute tells GCC not to pad the struct's layout to fit
//convenient boundaries. This is necessary as we will be pouring data directly into the struct,
//and padding would break the field alignment.

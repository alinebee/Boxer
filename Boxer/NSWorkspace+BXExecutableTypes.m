/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 This code is adapted from code that is copyright (c) 2010 Jef Wambacq (jefwambacq@gmail.com)
 
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "NSWorkspace+BXExecutableTypes.h"
#import "RegexKitLite.h"


#pragma mark -
#pragma mark Internal constants and types

NSString * const BXExecutableTypesErrorDomain = @"BXExecutableTypesErrorDomain";


//Original DOS EXE type
#define BXDOSExecutableMarker			0x5A4D //MZ in little-endian

//Windows EXE types and unlikely to be DOS-compatible
#define BX16BitNewExecutableMarker		0x454E //NE
#define BX32BitPortableExecutableMarker	0x4550 //PE

//OS/2 EXE types, but also used by some DOS extenders
#define BX16BitLinearExecutableMarker	0x454C //LE
#define BX32BitLinearExecutableMarker	0x584C //LX

//Very rare EXE/VXD types that are never DOS-compatible
#define BXW3ExecutableMarker			0x3357 //W3
#define BXW4ExecutableMarker			0x3457 //W4

#define BX16BitNewExecutableHeaderLength		13
#define BX32BitPortableExecutableHeaderLength	24

//The maximum expected length for a "This program is for Windows only"
//warning stub program in a Windows or OS/2 (NE, PE, LE or LX) executable.
//Stubs larger than this will be assumed to contain legitimate DOS programs,
//so the entire executable will be considered DOS-compatible.
//(This is a liberal guess: stubs of length 128 and 256 and 3584 have
//been found so far, and it's unlikely that a legitimate EXE file with
//one of those extended types will be smaller than 3.5kb.)
#define BXMaxWarningStubLength 3584

#define BXExecutablePageSize 512

//q.v.: http://www.delphidabbler.com/articles?article=8&part=2
typedef struct {	
    unsigned short typeMarker;				// Filetype marker (always "MZ" for executables)
    unsigned short lastPageSize;			// Bytes on last page of file
    unsigned short numPages;				// Pages in file
    unsigned short numRelocations;			// Relocations
    unsigned short numHeaderParagraphs;		// Size of header in paragraphs
	unsigned short minExtraParagraphs;		// Minimum extra paragraphs needed
	unsigned short maxExtraParagraphs;		// Maximum extra paragraphs needed
    unsigned short ssValue;					// Initial (relative) SS value
    unsigned short spValue;					// Initial SP value
    unsigned short checksum;				// Checksum
    unsigned short ipValue;					// Initial IP value
    unsigned short csValue;					// Initial (relative) CS value
    unsigned short relocationTableAddress;	// Address of relocation table
    unsigned short overlayNumber;			// Overlay number
    unsigned short reserved[4];				// Reserved
    unsigned short oemIdentifier;			// OEM identifier (for oemInfo)
    unsigned short oemInfo;					// OEM info (oemIdentifier-specific)
    unsigned short reserved2[10];			// Reserved
    unsigned long newHeaderAddress;			// File address of new exe header
} BXDOSExecutableHeader;


#pragma mark -
#pragma mark Implementation

@implementation NSWorkspace (BXExecutableTypes)

- (BXExecutableType) executableTypeAtPath: (NSString *)path error: (NSError **)outError
{	
	BXDOSExecutableHeader header;
	int headerSize = sizeof(BXDOSExecutableHeader);
	
	//Get the real size because the size in the DOS Header isn't always correct.
	unsigned long long realFileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath: path error: NULL] fileSize];
	
	//The file must be large enough to contain the entire DOS Header.
	if (realFileSize < (unsigned long long)headerSize)
	{
		if (outError)
		{
			*outError = [NSError errorWithDomain: BXExecutableTypesErrorDomain
											code: BXExecutableTruncated
										userInfo: nil];
		}
		return BXExecutableTypeUnknown;
	}
	
	
	NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath: path];
	
	//File could not be opened for reading, bail out
	if (!file)
	{
		if (outError)
		{
			*outError = [NSError errorWithDomain: BXExecutableTypesErrorDomain
											code: BXCouldNotReadExecutable
										userInfo: nil];
		}
		return BXExecutableTypeUnknown;
	}
	
	
	//Read the header data into our DOS header struct
	[[file readDataOfLength: headerSize] getBytes: &header];
	
	//Header is stored in big-endian format, so swap the bytes around to ensure correct comparisons.
	unsigned short typeMarker			= NSSwapLittleShortToHost(header.typeMarker);
	unsigned short numPages				= NSSwapLittleShortToHost(header.numPages);
	unsigned short lastPageSize			= NSSwapLittleShortToHost(header.lastPageSize);
	unsigned short relocationAddress	= NSSwapLittleShortToHost(header.relocationTableAddress);
	unsigned long newHeaderAddress		= NSSwapLittleLongToHost(header.newHeaderAddress);
	
	
	//DOS Headers always start with the MZ magic number marker:
	//if this is incorrect, then it's not a real executable.
	if (typeMarker != BXDOSExecutableMarker)
	{
		if (outError)
		{
			*outError = [NSError errorWithDomain: BXExecutableTypesErrorDomain
											code: BXNotAnExecutable
										userInfo: nil];
		}
		return BXExecutableTypeUnknown;
	}
	
	//Calculate what size the DOS header thinks the executable is:
	//this may legally differ from the actual file size.
	unsigned long long expectedFileSize = (numPages * BXExecutablePageSize);
	if (lastPageSize > 0)
		expectedFileSize += (lastPageSize - BXExecutablePageSize);
	
	//If file is shorter than the DOS header thinks it is, or the
	//relocation table offset is out of range, it means the executable
	//has been truncated and we cannot meaningfully determine the type.
	if (realFileSize < expectedFileSize  || expectedFileSize < relocationAddress)
	{
		if (outError)
		{
			*outError = [NSError errorWithDomain: BXExecutableTypesErrorDomain
											code: BXExecutableTruncated
										userInfo: nil];
		}
		return BXExecutableTypeUnknown;
	}
	
	//New header offset is out of range: assume this is a DOS executable
	if (realFileSize < newHeaderAddress) return BXExecutableTypeDOS;

	
	//Read in the new-style executable type from the start of the new header address
	[file seekToFileOffset: newHeaderAddress];
	unsigned short newTypeMarker = 0;
	[[file readDataOfLength: sizeof(unsigned short)] getBytes: &newTypeMarker];
	
	newTypeMarker = NSSwapLittleShortToHost(newTypeMarker);
	
	switch (newTypeMarker)
	{
		case BX16BitNewExecutableMarker:			
		case BX32BitPortableExecutableMarker:
			//Stub area is unusually large, assume it's a DOS EXE
			if (newHeaderAddress > BXMaxWarningStubLength)
				return BXExecutableTypeDOS;
			
			unsigned long minHeaderLength = (newTypeMarker == BX32BitPortableExecutableMarker) ? BX32BitPortableExecutableHeaderLength : BX16BitNewExecutableHeaderLength;
			
			//Malformed: not long enough to accomodate new header, assume it's a DOS EXE
			if (realFileSize < (newHeaderAddress + minHeaderLength))
				return BXExecutableTypeDOS;

			//Otherwise, assume it's Windows
			return BXExecutableTypeWindows;
		
		case BX16BitLinearExecutableMarker:
		case BX32BitLinearExecutableMarker:
			//Stub area is unusually large, assume it's a DOS EXE
			if (newHeaderAddress > BXMaxWarningStubLength)
				return BXExecutableTypeDOS;
			
			//Otherwise, assume it's OS/2
			return BXExecutableTypeOS2;

		case BXW3ExecutableMarker:
		case BXW4ExecutableMarker:
			//These are esoteric and only used for weird-ass Windows 3.x drivers and the like
			return BXExecutableTypeWindows;
			
		default:
			return BXExecutableTypeDOS;
	}
}

- (BOOL) isCompatibleExecutableAtPath: (NSString *)filePath
{
	//Automatically assume .COM and .BAT files are DOS-compatible
	NSSet *dosOnlyTypes = [NSSet setWithObjects: @"com.microsoft.msdos-executable", @"com.microsoft.batch-file", nil];
	if ([self file: filePath matchesTypes: dosOnlyTypes])
		 return YES;
	
	return [self executableTypeAtPath: filePath error: NULL] == BXExecutableTypeDOS;
}

@end

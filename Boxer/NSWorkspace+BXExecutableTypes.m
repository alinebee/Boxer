/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 This code is adapted from code that is copyright (c) 2010 Jef Wambacq (jefwambacq@gmail.com)
 
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "NSWorkspace+BXExecutableTypes.h"
#import "RegexKitLite.h"


#pragma mark -
#pragma mark Internal constants and types

NSString * const BXExecutableTypesErrorDomain = @"BXExecutableTypesErrorDomain";


//Original DOS EXE type retained by all executables.
#define BXDOSExecutableMarker			0x5A4D //MZ in little-endian

//Windows EXE types: unlikely to be DOS-compatible but can
//be found in some hybrid DOS/Windows EXEs and DOS extenders.
#define BX16BitNewExecutableMarker		0x454E //NE
#define BX32BitPortableExecutableMarker	0x4550 //PE

//OS/2 EXE types, also used by some DOS extenders.
#define BX16BitLinearExecutableMarker	0x454C //LE
#define BX32BitLinearExecutableMarker	0x584C //LX

//Very rare EXE/VXD types that are never DOS-compatible.
#define BXW3ExecutableMarker			0x3357 //W3
#define BXW4ExecutableMarker			0x3457 //W4

//Page size in bytes. Used for calculating expected filesize.
#define BXExecutablePageSize					512

//Expected address of relocation table in new-style executables.
#define BXExtendedExecutableRelocationAddress	0x40

//Expected new-header lengths for NE and PE executables.
#define BX16BitNewExecutableHeaderLength		64
#define BX32BitPortableExecutableHeaderLength	24

//The maximum expected length for a "This program is for Windows only"
//warning stub program in a Windows or OS/2 (NE, PE, LE or LX) executable.
//Stubs larger than this will be assumed to contain legitimate DOS programs,
//so the entire executable will be considered DOS-compatible.
//(This is a liberal guess: stubs of length 128 and 256 and 3584 have
//been found so far, and it's unlikely that a legitimate EXE file with
//one of those extended types will be smaller than 3.5kb.)
#define BXMaxWarningStubLength 3584


//Original DOS header format, with extended data.
//q.v.: http://www.delphidabbler.com/articles?article=8&part=2
//http://www.fileformat.info/format/exe/corion-mz.htm
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
    unsigned short relocationTableAddress;	// Address of relocation table (always 0x40 for new-style executables)
    unsigned short overlayNumber;			// Overlay number
	
	//The rest of these are part of an extended header present in new-style executables
    unsigned short reserved[4];				// Reserved
    unsigned short oemIdentifier;			// OEM identifier (for oemInfo)
    unsigned short oemInfo;					// OEM info (oemIdentifier-specific)
    unsigned short reserved2[10];			// Reserved
    unsigned long newHeaderAddress;			// File address of new exe header
} __attribute__ ((packed)) BXDOSExecutableHeader;

//IMPLEMENTATION NOTE: the packed attribute tells GCC not to pad the struct's layout to fit
//convenient boundaries. This is necessary as we will be pouring data directly into the struct,
//and padding would break the field alignment.


#pragma mark -
#pragma mark Implementation

@implementation NSWorkspace (BXExecutableTypes)

- (BXExecutableType) executableTypeAtPath: (NSString *)path error: (NSError **)outError
{	
	BXDOSExecutableHeader header;
	int headerSize = sizeof(BXDOSExecutableHeader);
	
	unsigned long long realFileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath: path error: NULL] fileSize];
	
	//The file must be large enough to contain the entire DOS header.
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
	
	//Read the header data into our DOS header struct.
	[[file readDataOfLength: headerSize] getBytes: &header];
	
	//Header is stored in little-endian format, so swap the bytes around on PowerPC systems to ensure correct comparisons.
	unsigned short typeMarker			= NSSwapLittleShortToHost(header.typeMarker);
	unsigned short numPages				= NSSwapLittleShortToHost(header.numPages);
	unsigned short lastPageSize			= NSSwapLittleShortToHost(header.lastPageSize);
	unsigned short relocationAddress	= NSSwapLittleShortToHost(header.relocationTableAddress);
	unsigned long newHeaderAddress		= NSSwapLittleLongToHost(header.newHeaderAddress);
	
	
	//DOS headers always start with the MZ type marker:
	//if this differs, then it's not a real executable.
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
	if (realFileSize < expectedFileSize || relocationAddress > expectedFileSize)
	{
		if (outError)
		{
			*outError = [NSError errorWithDomain: BXExecutableTypesErrorDomain
											code: BXExecutableTruncated
										userInfo: nil];
		}
		return BXExecutableTypeUnknown;
	}
	
	//The relocation table address should always be 64 for new-style executables:
	//if this differs, then this is a DOS-only executable.
	if (relocationAddress != BXExtendedExecutableRelocationAddress) return BXExecutableTypeDOS;
	
	//If the offset of the new-style executable header is 0 or out of range, assume this is a DOS executable.
	if (newHeaderAddress == 0 || (newHeaderAddress + sizeof(unsigned short) > realFileSize)) return BXExecutableTypeDOS;
	

	
	//Read in the 2-byte executable type marker from the start of the new-style header.
	unsigned short newTypeMarker = 0;
	[file seekToFileOffset: newHeaderAddress];
	[[file readDataOfLength: sizeof(unsigned short)] getBytes: &newTypeMarker];
	
	newTypeMarker = NSSwapLittleShortToHost(newTypeMarker);
	
	switch (newTypeMarker)
	{
		case BX16BitNewExecutableMarker:			
		case BX32BitPortableExecutableMarker:
			//Stub area is unusually large: assume it contains a legitimate DOS program.
			if (newHeaderAddress > BXMaxWarningStubLength)
				return BXExecutableTypeDOS;
			
			unsigned long minHeaderLength = (newTypeMarker == BX32BitPortableExecutableMarker) ? BX32BitPortableExecutableHeaderLength : BX16BitNewExecutableHeaderLength;
			
			//File is not long enough to accomodate expected header: assume the
			//type marker was just a coincidence, and this actually a DOS executable.
			if (realFileSize < (newHeaderAddress + minHeaderLength))
				return BXExecutableTypeDOS;

			//Otherwise, assume it's Windows.
			return BXExecutableTypeWindows;
		
		case BX16BitLinearExecutableMarker:
		case BX32BitLinearExecutableMarker:
			//Stub area is unusually large: assume it contains a legitimate DOS program.
			if (newHeaderAddress > BXMaxWarningStubLength)
				return BXExecutableTypeDOS;
			
			//Otherwise, assume it's OS/2.
			return BXExecutableTypeOS2;

		case BXW3ExecutableMarker:
		case BXW4ExecutableMarker:
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
	
	//If it is a .EXE file, perform a more rigorous compatibility check
	if ([self file: filePath matchesTypes: [NSSet setWithObject: @"com.microsoft.windows-executable"]])
		 return [self executableTypeAtPath: filePath error: NULL] == BXExecutableTypeDOS;
		
	//Otherwise, assume the file is incompatible
	return NO;
}

@end

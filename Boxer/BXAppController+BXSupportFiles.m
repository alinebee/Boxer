/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXAppController+BXSupportFiles.h"
#import "BXPathEnumerator.h"
#import "RegexKitLite.h"


@implementation BXAppController (BXSupportFiles)

+ (NSString *) supportPathCreatingIfMissing: (BOOL)createIfMissing
{
	NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex: 0];
	NSString *supportPath = [basePath stringByAppendingPathComponent: @"Boxer"];
	
	if (createIfMissing)
	{
		[[NSFileManager defaultManager] createDirectoryAtPath: supportPath
								  withIntermediateDirectories: YES
												   attributes: nil
														error: NULL];
	}
	return supportPath;
}

+ (NSString *) temporaryPathCreatingIfMissing: (BOOL)createIfMissing
{
	NSString *basePath = NSTemporaryDirectory();
	NSString *tempPath = [basePath stringByAppendingPathComponent: @"Boxer"];
	
	if (createIfMissing)
	{
		[[NSFileManager defaultManager] createDirectoryAtPath: tempPath
								  withIntermediateDirectories: YES
												   attributes: nil
														error: NULL];
	}
	return tempPath;
}

+ (NSString *) MT32ROMPathCreatingIfMissing: (BOOL)createIfMissing
{
	NSString *supportPath   = [self supportPathCreatingIfMissing: NO];
    NSString *ROMPath       = [supportPath stringByAppendingPathComponent: @"MT-32 ROMs"];
	
	if (createIfMissing)
	{
		[[NSFileManager defaultManager] createDirectoryAtPath: ROMPath
								  withIntermediateDirectories: YES
												   attributes: nil
														error: NULL];
	}
	return ROMPath;
}


//The user may have put the ROM files into the folder themselves,
//so we can't rely on them having a consistent naming scheme.
//Instead, return the first file that matches a flexible filename pattern.
+ (NSString *) _pathToMT32ROMMatchingPattern: (NSString *)pattern
{
    NSString *ROMPath = [self MT32ROMPathCreatingIfMissing: NO];
    
    BXPathEnumerator *enumerator = [BXPathEnumerator enumeratorAtPath: ROMPath];
    [enumerator setSkipSubdirectories: YES];
    [enumerator setSkipHiddenFiles: YES];
    [enumerator setSkipPackageContents: YES];
    for (NSString *filePath in enumerator)
    {
        NSString *fileName = [filePath lastPathComponent];
        if ([fileName isMatchedByRegex: pattern
                               options: RKLCaseless
                               inRange: NSMakeRange(0, [fileName length])
                                 error: nil])
        {
            return filePath;
        }
    }
    return nil;
}

+ (NSString *) pathToMT32ControlROM
{
    return [self _pathToMT32ROMMatchingPattern: @"control"];
}

+ (NSString *) pathToMT32PCMROM
{
    return [self _pathToMT32ROMMatchingPattern: @"pcm"];
}

+ (BOOL) _importMT32ROMFromPath: (NSString *)sourcePath
                         toName: (NSString *)fileName
                          error: (NSError **)outError
{
    NSString *basePath = [self MT32ROMPathCreatingIfMissing: YES];
    NSString *destinationPath = [basePath stringByAppendingPathComponent: fileName];
    
    NSFileManager *manager = [[NSFileManager alloc] init];
    
    BOOL succeeded = [manager copyItemAtPath: sourcePath
                                      toPath: destinationPath
                                       error: outError];
    
    [manager release];
    return succeeded;
}

+ (BOOL) importMT32ControlROM: (NSString *)ROMPath
                        error: (NSError **)outError
{
    return [self _importMT32ROMFromPath: ROMPath toName: @"Control.rom" error: outError];
}

+ (BOOL) importMT32PCMROM: (NSString *)ROMPath
                    error: (NSError **)outError
{
    return [self _importMT32ROMFromPath: ROMPath toName: @"PCM.rom" error: outError];
}

@end

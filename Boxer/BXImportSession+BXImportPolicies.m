/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImportSession+BXImportPolicies.h"
#import "BXSession+BXFileManagement.h"
#import "NSWorkspace+BXMountedVolumes.h"
#import "NSWorkspace+BXFileTypes.h"
#import "RegexKitLite.h"
#import "NSString+BXPaths.h"

#import "BXGamebox.h"
#import "BXFileTypes.h"
#import "BXPathEnumerator.h"
#import "BXEmulatorConfiguration.h"



@implementation BXImportSession (BXImportPolicies)

#pragma mark -
#pragma mark Detecting installers and ignorable files

+ (NSSet *) installerPatterns
{
	static NSSet *patterns = nil;
	if (!patterns) patterns = [[NSSet alloc] initWithObjects:
							   @"inst",
							   @"setup",
							   @"config",
							   nil];
	return patterns;
}

+ (NSArray *) preferredInstallerPatterns
{
	static NSArray *patterns = nil;
	if (!patterns) patterns = [[NSArray alloc] initWithObjects:
							   @"^dosinst",
							   @"^install\\.",
							   @"^hdinstal\\.",
							   @"^setup\\.",
							   nil];
	return patterns;
}

+ (BOOL) isInstallerAtPath: (NSString *)path
{	
	NSString *fileName = path.lastPathComponent.lowercaseString;
	
	for (NSString *pattern in [self installerPatterns])
	{
		if ([fileName isMatchedByRegex: pattern]) return YES;
	}
	return NO;
}

+ (NSSet *) ignoredFilePatterns
{
	static NSSet *patterns = nil;
	if (!patterns) patterns = [[NSSet alloc] initWithObjects:
							   @"(^|/)directx",			//DirectX redistributables
							   @"(^|/)acrodos",			//Adobe acrobat reader for DOS
							   @"(^|/)acroread\\.exe$", //Adobe acrobat reader for Windows
							   @"(^|/)uvconfig\\.exe$",	//UniVBE detection program
							   @"(^|/)univbe",			//UniVBE program/redistributable folder
							   
							   @"(^|/)unins000\\.",					//GOG uninstaller files
							   @"(^|/)Graphic mode setup\\.exe$",	//GOG configuration programs
							   @"(^|/)gogwrap\\.exe$",				//GOG only knows what this one does
							   @"(^|/)dosbox(.*)/",					//Anything in a DOSBox-related subfolder
							   
							   @"(^|/)autorun",			//Windows CD-autorun stubs
							   @"(^|/)bootdisk\\.",		//Bootdisk makers
							   @"(^|/)readme\\.",		//Readme viewers
                               
                               @"(^|/)foo\\.bat",       //Backup script included by mistake
                                                        //on some Mac X-Wing CDROM editions
                               
                               @"(^|/)vinstall\\.bat",  //??
							   
							   @"(^|/)pkunzip\\.",		//Archivers
							   @"(^|/)pkunzjr\\.",
							   @"(^|/)arj\\.",
							   @"(^|/)lha\\.",
							   nil];
	return patterns;
}

+ (BOOL) isIgnoredFileAtPath: (NSString *)path
{
	NSRange matchRange = NSMakeRange(0, path.length);
	for (NSString *pattern in [self ignoredFilePatterns])
	{
		if ([path isMatchedByRegex: pattern
						   options: RKLCaseless
						   inRange: matchRange
							 error: NULL]) return YES;
	}
	return NO;
}

+ (BOOL) isInconclusiveDOSProgramAtPath: (NSString *)path
{
    //Ignore batch files when determining DOS-versus-Windowsness,
    //since a file-scripting utility may be included with an otherwise Windows game.
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSSet *inconclusiveFileTypes = [NSSet setWithObject: @"com.microsoft.batch-file"];
    return [workspace file: path matchesTypes: inconclusiveFileTypes];
}

#pragma mark -
#pragma mark Detecting files not to import

+ (NSSet *) junkFilePatterns
{
	static NSSet *patterns = nil;
	if (!patterns) patterns = [[NSSet alloc] initWithObjects:
							   @"(^|/)dosbox",						//Anything DOSBox-related
							   @"(^|/)goggame(.*)\\.dll",           //GOG launcher files
							   @"(^|/)unins000\\.",					//GOG uninstaller files
							   @"(^|/)Graphic mode setup\\.exe$",	//GOG configuration programs
							   @"(^|/)gogwrap\\.exe$",				//GOG only knows what this one does
                               @"(^|/)innosetup_license.txt",       //More GOG cruft
							   @"(^|/)gfw_high(.*)\\.ico$",         //GOG icon files
							   @"(^|/)support\\.ico$",
							   
							   @"\\.pif$",							//Windows PIF files
							   @"\\.conf$",							//DOSBox configuration files
							   nil];
	return patterns;
}

+ (BOOL) isJunkFileAtPath: (NSString *)path
{
	NSRange matchRange = NSMakeRange(0, path.length);
	for (NSString *pattern in [self junkFilePatterns])
	{
		if ([path isMatchedByRegex: pattern
						   options: RKLCaseless
						   inRange: matchRange
							 error: NULL]) return YES;
	}
	return NO;
}


#pragma mark -
#pragma mark Detecting whether a game is already installed

+ (NSSet *) playableGameTelltaleExtensions
{
	static NSSet *extensions = nil;
	if (!extensions) extensions = [[NSSet alloc] initWithObjects:
								   @"conf",		//DOSBox conf files indicate an already-installed game
								   @"iso",		//Likewise with mountable disc images
								   @"cue",
								   @"cdr",
								   @"inst",
								   @"harddisk",	//Boxer drive folders indicate a former Boxer gamebox
								   @"cdrom",
								   @"floppy",
								   nil];
	return extensions;
}

+ (NSSet *) playableGameTelltalePatterns
{
	static NSSet *patterns = nil;
	if (!patterns) patterns = [[NSSet alloc] initWithObjects:
							   @"^gfw_high\\.ico$",	//Indicates a GOG game
							   nil];
	return patterns;
}

+ (BOOL) isPlayableGameTelltaleAtPath: (NSString *)path
{
	NSString *fileName = path.lastPathComponent.lowercaseString;
	
	//Do a quick test first using just the extension
	if ([[self playableGameTelltaleExtensions] containsObject: fileName.pathExtension]) return YES;
	
	//Next, test against our filename patterns
	for (NSString *pattern in [self playableGameTelltalePatterns])
	{
		if ([fileName isMatchedByRegex: pattern]) return YES;
	}
	
	return NO;
}


#pragma mark -
#pragma mark Deciding how best to import a game

+ (BOOL) isCDROMSizedGameAtPath: (NSString *)path
{
	unsigned long long pathSize = 0;
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath: path];
	while (enumerator.nextObject)
	{
		pathSize += enumerator.fileAttributes.fileSize;
		if (pathSize > (NSUInteger)BXCDROMSizeThreshold) return YES;
	}
	return NO;
}

+ (NSString *) preferredSourcePathForPath: (NSString *)path
									error: (NSError **)outError
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	//If the chosen path was an audio CD, check if it has a corresponding data path and use that instead
	if ([[workspace volumeTypeForPath: path] isEqualToString: audioCDVolumeType])
	{
		NSString *dataVolumePath = [workspace dataVolumeOfAudioCD: path];
		if (dataVolumePath) return dataVolumePath;
	}
	
	//Otherwise, for now stick with the original path as it was provided
	//TODO: return the base volume path if the path was on a CD or floppy disk?
	//TODO: search for a preferred import folder based on game profile?
    //That would require us to know the profile in advance though,
    //which makes it the purview of BXInstallerScan instead.
	return path;
}


+ (NSString *) preferredInstallerFromPaths: (NSArray *)paths
{
	//Run through each filename pattern in order of priority, returning the first matching path
	for (NSString *pattern in [self preferredInstallerPatterns])
	{
		for (NSString *path in paths)
		{
            NSString *fileName = path.lastPathComponent;
			if ([fileName isMatchedByRegex: pattern
                                   options: RKLCaseless
                                   inRange: NSMakeRange(0, fileName.length)
                                     error: nil])
                return path;
		}
	}
	return nil;
}

+ (BOOL) shouldImportSourceFilesFromPath: (NSString *)path
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	//If the source path is a mountable image, it should be imported
	if ([workspace file: path matchesTypes: [BXFileTypes mountableImageTypes]]) return YES;
	
	//If the source path is on a CD, it should be imported
	if ([[workspace volumeTypeForPath: path] isEqualToString: dataCDVolumeType]) return YES;
	
	//If the source path looks CD-sized, it should be imported
	if ([self isCDROMSizedGameAtPath: path]) return YES;
	
	return NO;
}

+ (BOOL) shouldUseSubfolderForSourceFilesAtPath: (NSString *)basePath
{
	BXPathEnumerator *enumerator = [BXPathEnumerator enumeratorAtPath: basePath];
	enumerator.skipSubdirectories = YES;
	
	BOOL hasExecutables = NO;
	for (NSString *path in enumerator)
	{
		//This is an indication that the game is installed and playable;
		//break out immediately and don’t use a subfolder 
		if ([self isPlayableGameTelltaleAtPath: path]) return NO;
		
		//Otherwise, if the folder contains executables, it probably does need a subfolder
		//(but keep scanning in case we find a playable telltale.)
		else if ([self isExecutable: path]) hasExecutables = YES;
	}
	return hasExecutables;
}


+ (NSImage *) boxArtForGameAtPath: (NSString *)path
{
    NSString *iconPath = nil;
    
	//At the moment this is a very simple check for the existence of a Games For Windows
	//icon, included with GOG games.
    NSString *pattern = @"^gfw_high\\.ico$";
    BXPathEnumerator *enumerator = [BXPathEnumerator enumeratorAtPath: path];
    for (NSString *subPath in enumerator)
    {
        NSString *fileName = subPath.lastPathComponent;
        if ([fileName isMatchedByRegex: pattern
                               options: RKLCaseless
                               inRange: NSMakeRange(0, fileName.length)
                                 error: nil])
        {
            iconPath = subPath;
            break;
        }
    }
    
	if (iconPath)
	{
		NSImage *icon = [[[NSImage alloc] initByReferencingFile: iconPath] autorelease];
		
		//TWEAK: strip out the 16x16 and 32x32 versions from GOG icons 
		//as these are usually terrible 16-colour Windows 3.1 icons.
		//(We copy the representations array because it's bad form to modify
		//an array while traversing it)
		NSArray *reps = [icon.representations copy];
		for (NSImageRep *rep in reps)
		{
			NSSize size = rep.size;
			if (size.width <= 32.0f && size.height <= 32.0f) [icon removeRepresentation: rep];
		}
		[reps release];
		
		//Sanity check: if there are no representations left, forget about the icon
		if (!icon.representations.count) return nil;
		else return icon;
	}
	return nil;
}

+ (NSString *) nameForGameAtPath: (NSString *)path
{
	NSString *filename = path.lastPathComponent;
	
	//Strip any of our own file extensions from the path
	NSArray *strippedExtensions = [NSArray arrayWithObjects:
								   @"boxer",
								   @"cdrom",
								   @"floppy",
								   @"harddisk",
								   nil];
	
	NSString *extension	= filename.pathExtension.lowercaseString;
	if ([strippedExtensions containsObject: extension]) filename = filename.stringByDeletingPathExtension;
	
	//Remove content enclosed in parentheses and/or square brackets:
	//Ultima 8 (1994)(Origin Systems)[Rev.2.12] -> Ultima 8
	filename = [filename stringByReplacingOccurrencesOfRegex: @"[\\[\\(]+.*[\\]\\)]+" withString: @""];
	
	//Put a space before a set of numbers preceded by a letter:
	//ULTIMA8 -> ULTIMA 8
	filename = [filename stringByReplacingOccurrencesOfRegex: @"([a-zA-Z]+)(\\d+)"
															withString: @"$1 $2"];
	
	//Replace underscores with spaces:
	//ULTIMA_8 -> ULTIMA 8, ULTIMA-8 -> ULTIMA 8
    filename = [filename stringByReplacingOccurrencesOfRegex: @"[_-]" withString: @" "];
	
	//Trim the string and collapse all internal whitespace to single spaces:
	// Ultima   8  -> Ultima 8
	filename = [filename stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
	filename = [filename stringByReplacingOccurrencesOfRegex: @"\\s+" withString: @" "];
	
	//Format Roman numerals to uppercase, and everthing else into Title Case:
	//ultima viii -> Ultima VIII
	NSMutableArray *words = [[filename componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceCharacterSet]] mutableCopy];
	NSUInteger i, numWords = words.count;
	for (i=0; i<numWords; i++)
	{
		NSString *word = [words objectAtIndex: i];
		
		//Matches roman numerals from I->XIII; I know of no DOS-era games with more than 13 parts,
		//and restricting the regex prevents it matching real words inadvertently (like "mix")
		//TODO: expand this to match common acronyms as well
		if ([word isMatchedByRegex: @"^[Ii]?[XxVvIi][Ii]*$"])
			word = word.uppercaseString;
		else
			word = word.capitalizedString;
		
		[words replaceObjectAtIndex: i withObject: word];
	}
	filename = [words componentsJoinedByString: @" "];
	[words release];
	
	
	//If all these substitutions somehow ended up with an empty string, then fall back on the original filename
	if (!filename.length) filename = path.lastPathComponent;
	
	return filename;
}

+ (BXGamebox *) createGameboxAtPath: (NSString *)path
							  error: (NSError **)outError
{
	NSFileManager *manager = [NSFileManager defaultManager];
	
	NSString *extension	= path.pathExtension;
	NSString *basePath	= path.stringByDeletingPathExtension;
	
	//Check if a gamebox already exists at that location;
	//if so, append an incremented extension until we land on a name that isn't taken
	unsigned int suffix = 2;
	while ([manager fileExistsAtPath: path])
	{
		path = [[basePath stringByAppendingFormat: @" (%u)", suffix++] stringByAppendingPathExtension: extension];
	}
	
	NSDictionary *hideFileExtension = [NSDictionary dictionaryWithObject: [NSNumber numberWithBool: YES]
																  forKey: NSFileExtensionHidden];
	BOOL success = [manager createDirectoryAtPath: path
					  withIntermediateDirectories: NO
									   attributes: hideFileExtension
											error: outError];
	
	if (success)
	{
		BXGamebox *gamebox = [BXGamebox bundleWithPath: path];
		return gamebox;
	}
	else return nil;	
}

//TODO: move this into BXGamebox?
+ (NSString *) validGameboxNameFromName: (NSString *)name
{
	//Remove all leading dots, to prevent gameboxes from being hidden
	NSString *strippedLeadingDot = [name stringByReplacingOccurrencesOfRegex: @"^\\.+" withString: @""];
	
	//Replace /, \ and : with dashes
	NSString *sanitisedSlashes = [strippedLeadingDot stringByReplacingOccurrencesOfRegex: @"[/\\\\:]" withString: @"-"];
	
	return sanitisedSlashes;
}

+ (NSString *) validDOSNameFromName: (NSString *)name
{
	NSString *asciiName = [name.lowercaseString stringByReplacingOccurrencesOfRegex: @"[^a-z0-9\\.]" withString: @""];
	NSString *baseName	= asciiName.stringByDeletingPathExtension;
	NSString *extension = asciiName.pathExtension;
	
	NSString *shortBaseName		= (baseName.length > 8) ? [baseName substringToIndex: 8] : baseName;
	NSString *shortExtension	= (extension.length > 3) ? [extension substringToIndex: 3] : extension;
	
	NSString *shortName = (shortExtension.length) ? [shortBaseName stringByAppendingPathExtension: shortExtension] : shortBaseName;
	
	return shortName;
}

NSInteger filenameLengthSort(NSString *path1, NSString *path2, void *context)
{
    NSUInteger length1 = path1.lastPathComponent.length;
    NSUInteger length2 = path2.lastPathComponent.length;
    
    if (length1 < length2)
        return NSOrderedAscending;
    else if (length1 > length2)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}

+ (NSString *) preferredConfigurationFileFromPaths: (NSArray *)paths
{
    //Compare configuration filenames by length to determine the shortest
    //(which we deem most likely to be the 'default')
    if (paths.count)
    {
        NSArray *sortedPaths = [paths sortedArrayUsingFunction: filenameLengthSort
                                                       context: NULL];
        
        return [sortedPaths objectAtIndex: 0];
    }
    else return nil;
}

+ (NSString *) preferredConfigurationFileInPath: (NSString *)path
                                          error: (NSError **)error
{
    //Compare configuration filenames by length to determine the shortest
    //(which we deem most likely to be the 'default')
    BXPathEnumerator *enumerator = [BXPathEnumerator enumeratorAtPath: path];
    enumerator.fileTypes = [NSSet setWithObject: @"gnu.org.configuration-file"];
    
    return [self preferredConfigurationFileFromPaths: enumerator.allObjects];
}

+ (BOOL) isConfigurationFileAtPath: (NSString *)path
{
    return [[NSWorkspace sharedWorkspace] file: path
                                  matchesTypes: [NSSet setWithObject: @"gnu.org.configuration-file"]];
}

+ (BXEmulatorConfiguration *) sanitizedVersionOfConfiguration: (BXEmulatorConfiguration *)configuration
{
    BXEmulatorConfiguration *sanitizedConfiguration = [BXEmulatorConfiguration configuration];
    
    //A dictionary of property names indexed by section, that we deem relevant to copy across
    NSDictionary *relevantSettings = [NSDictionary dictionaryWithObjectsAndKeys:
      [NSSet setWithObjects: @"machine", @"memsize", nil],                      @"dosbox",
      [NSSet setWithObjects: @"ems", @"xms", @"umb", nil],                      @"dos",
      [NSSet setWithObjects: @"core", @"cputype", @"cycles", nil],              @"cpu",
      [NSSet setWithObjects: @"mpu401", nil],                                   @"midi",
      [NSSet setWithObjects: @"sbtype", @"sbbase", @"irq", @"dma", @"hdma", @"oplmode", @"oplemu", @"sbmixer", nil],  @"sblaster",
      [NSSet setWithObjects: @"gus", @"gusbase", @"gusirq", @"gusdma", nil],    @"gus",
      [NSSet setWithObjects: @"pcspeaker", @"tandy", @"disney", nil],           @"speaker",
      //NOTE: we don't import joystick settings for now, because GOG games ship with
      //mostly incorrect joystick settings and we already have auto-configurations
      //for a lot of the problem games they sell.
      //[NSSet setWithObjects: @"joysticktype", @"timed", nil],                   @"joystick",
      nil];
    
    for (NSString *section in relevantSettings.keyEnumerator)
    {
        for (NSString *setting in [relevantSettings objectForKey: section])
        {
            NSString *value = [configuration valueForKey: setting inSection: section];
            if (value != nil) [sanitizedConfiguration setValue: value forKey: setting inSection: section];
        }
    }
    return sanitizedConfiguration;
}

+ (BOOL) _startupCommand: (NSString *)command matchesPatterns: (NSSet *)patterns
{
    for (NSString *pattern in patterns)
    {
        if ([command isMatchedByRegex: pattern
                              options: RKLCaseless
                              inRange: NSMakeRange(0, command.length)
                                error: nil])
        {
            return YES;
        }
    }
    return NO;
}

+ (NSArray *) launchCommandsFromConfiguration: (BXEmulatorConfiguration *)configuration
{
    NSSet *patternsToIgnore = [NSSet setWithObjects:
                               @"^[@\\s]*echo off",
                               @"^[@\\s]*rem ",
                               @"^[@\\s]*mount ",
                               @"^[@\\s]*imgmount ",
                               @"^[@\\s]*exit",
                               nil];
    
    NSMutableArray *matches = [[NSMutableArray alloc] initWithCapacity: 10];
    
    for (NSString *command in configuration.startupCommands)
    {
        if (![self _startupCommand: command matchesPatterns: patternsToIgnore])
            [matches addObject: command];
    }
    return [matches autorelease];
}

+ (NSArray *) mountCommandsFromConfiguration: (BXEmulatorConfiguration *)configuration
{
    NSSet *patternsToMatch = [NSSet setWithObjects:
                              @"^[@\\s]*mount ",
                              @"^[@\\s]*imgmount ",
                              nil];
    
    NSMutableArray *matches = [[NSMutableArray alloc] initWithCapacity: 10];
    for (NSString *command in configuration.startupCommands)
    {
        if ([self _startupCommand: command matchesPatterns: patternsToMatch])
            [matches addObject: command];
    }
    return [matches autorelease];
}

@end

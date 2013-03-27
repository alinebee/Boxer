/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDriveBundleImport.h"
#import "BXSimpleDriveImport.h"
#import "ADBBinCueImage.h"
#import "BXDrive.h"
#import "RegexKitLite.h"
#import "NSURL+ADBFilesystemHelpers.h"
#import "NSFileManager+ADBUniqueFilenames.h"

NSString * const BXDriveBundleErrorDomain = @"BXDriveBundleErrorDomain";



@implementation BXDriveBundleImport
@synthesize drive = _drive;
@synthesize destinationFolderURL = _destinationFolderURL;
@synthesize destinationURL = _destinationURL;


#pragma mark -
#pragma mark Helper class methods

+ (BOOL) driveUnavailableDuringImport
{
    return NO;
}

+ (NSString *) nameForDrive: (BXDrive *)drive
{
	NSString *baseName = [BXDriveImport baseNameForDrive: drive];
	NSString *importedName = [baseName stringByAppendingPathExtension: @"cdmedia"];
	
	return importedName;
}

+ (BOOL) isSuitableForDrive: (BXDrive *)drive
{
    if ([drive.sourceURL conformsToFileType: @"com.goldenhawk.cdrwin-cuesheet"])
        return YES;
    
    //If the file can be parsed as a CUE, treat it as a match too (catches renamed GOG images.)
    if ([ADBBinCueImage isCueAtURL: drive.sourceURL error: NULL])
        return YES;

	return NO;
}

#pragma mark -
#pragma mark Initialization and deallocation

- (id <BXDriveImport>) initForDrive: (BXDrive *)drive
               destinationFolderURL: (NSURL *)destinationFolderURL
						  copyFiles: (BOOL)copy;
{
	if ((self = [super init]))
	{
        self.drive = drive;
        self.destinationFolderURL = destinationFolderURL;
        self.copyFiles = copy;
	}
	return self;
}

- (void) dealloc
{
    self.drive = nil;
    self.destinationFolderURL = nil;
    self.destinationURL = nil;
    
	[super dealloc];
}

- (NSURL *) preferredDestinationURL
{
    if (!self.drive || !self.destinationFolderURL) return nil;
    
	NSString *driveName			= [self.class nameForDrive: self.drive];
    NSURL *destinationURL       = [self.destinationFolderURL URLByAppendingPathComponent: driveName];
    
    //Check that there isn't already a file with the same name at the location.
    //If there is, auto-increment the name until we land on one that's unique.
    NSURL *uniqueDestinationURL = [[NSFileManager defaultManager] uniqueURLForURL: destinationURL
                                                                   filenameFormat: BXUniqueDriveNameFormat];
    
    return uniqueDestinationURL;
}

#pragma mark -
#pragma mark The actual operation, finally

- (void) main
{
    NSAssert(self.drive != nil, @"No drive provided for drive import operation.");
    NSAssert(self.destinationURL != nil || self.destinationFolderURL != nil, @"No destination folder provided for drive import operation.");
    
    if (!self.destinationURL)
        self.destinationURL = self.preferredDestinationURL;
    
	NSURL *sourceURL		= self.drive.mountPointURL;
	NSURL *destinationURL	= self.destinationURL;
	
	NSError *readError = nil;
	NSString *cueContents = [[[NSString alloc] initWithContentsOfURL: sourceURL
                                                        usedEncoding: NULL
                                                               error: &readError] autorelease];
    
	if (!cueContents)
	{
		self.error = readError;
		return;
	}
	
	NSArray *relatedPaths		= [ADBBinCueImage rawPathsInCueContents: cueContents];
	NSUInteger numRelatedPaths	= relatedPaths.count;
	
    
    //Bail out if we aren't able to parse the source files from this cue.
    if (!numRelatedPaths)
    {
        NSError *cueParseError = [BXDriveBundleCueParseError errorWithDrive: self.drive];
        [self setError: cueParseError];
        return;
    }
    
	if (self.isCancelled) return;
    
    //Work out what to do with the related file paths we've parsed from the cue file
    NSURL *baseURL = sourceURL.URLByDeletingLastPathComponent;
    NSMutableDictionary *revisedPaths = [NSMutableDictionary dictionaryWithCapacity: numRelatedPaths];
    
    for (NSString *fromPath in relatedPaths)
    {
        //Rewrite Windows-style paths
        NSString *sanitisedFromPath = [fromPath stringByReplacingOccurrencesOfString: @"\\" withString: @"/"];
        
        NSURL *fromURL      = [baseURL URLByAppendingPathComponent: sanitisedFromPath];
        NSString *fromName	= fromURL.lastPathComponent;
        NSURL *toURL        = [destinationURL URLByAppendingPathComponent: fromName];
        
        [self addTransferFromPath: fromURL.path toPath: toURL.path];
        
        //Make a note of the path if it needs to be changed when we rewrite the CUE file
        //(e.g. if it's in a subdirectory that will no longer exist when the files are imported)
        if (![fromPath isEqualToString: fromName])
            [revisedPaths setObject: fromName forKey: fromPath];
    }
    
    if (self.isCancelled) return;
    
    //Perform the standard file import from here on in.
    _hasWrittenFiles = NO;
    [super main];
    _hasWrittenFiles = YES;
    
    if (!self.error)
    {
        //Once the transfer's finished, generate a revised cue file and write it to the new bundle
        NSMutableString *revisedCue = [cueContents mutableCopy];
        for (NSString *oldPath in revisedPaths.keyEnumerator)
        {
            NSString *newPath = [revisedPaths objectForKey: oldPath];
            //FIXME: this could break the CUE file if an old filename is exactly
            //the same as a standard CUE keyword. Which is never going to happen,
            //but we really should track the ranges of each path as well.
            [revisedCue replaceOccurrencesOfString: oldPath
                                        withString: newPath
                                           options: NSLiteralSearch
                                             range: NSMakeRange(0, revisedCue.length)];
        }
        
        NSURL *finalCueURL = [destinationURL URLByAppendingPathComponent: @"tracks.cue"];
        
        NSError *cueError = nil;
        BOOL cueWritten = [revisedCue writeToURL: finalCueURL
                                      atomically: YES
                                        encoding: NSUTF8StringEncoding
                                           error: &cueError];
        [revisedCue release];
        
        if (!cueWritten)
        {
            self.error = cueError;
        }
        else if (!self.copyFiles)
        {
            //If we were moving rather than copying, then delete the original
            //cue file once we've written the new one
            [[NSFileManager defaultManager] removeItemAtURL: sourceURL error: NULL];
        }
    }
    
    //If the import failed for any reason (including cancellation),
    //then clean up the partial files.
    if (self.error)
        [self undoTransfer];
}


- (BOOL) undoTransfer
{
	BOOL undid = [super undoTransfer];
	if (self.copyFiles && self.destinationURL && _hasWrittenFiles)
	{
		undid = [[NSFileManager defaultManager] removeItemAtURL: self.destinationURL error: NULL];
	}
	return undid;
}
@end


@implementation BXDriveBundleCueParseError

+ (id) errorWithDrive: (BXDrive *)drive
{
	NSString *displayName = drive.title;
	NSString *descriptionFormat = NSLocalizedString(@"The image “%1$@” could not be imported because Boxer was unable to determine its source files.",
													@"Error shown when drive bundle importing fails because the CUE file could not be parsed. %1$@ is the display title of the drive.");
	
	NSString *description	= [NSString stringWithFormat: descriptionFormat, displayName];
	NSString *suggestion	= NSLocalizedString(@"This image may be in a format that Boxer does not support.", @"Explanatory message shown when drive bundle importing fails because the CUE file could not be parsed.");
	
	NSDictionary *userInfo	= [NSDictionary dictionaryWithObjectsAndKeys:
							   description,		NSLocalizedDescriptionKey,
							   suggestion,		NSLocalizedRecoverySuggestionErrorKey,
							   drive.sourceURL, NSURLErrorKey,
							   nil];
	
	return [NSError errorWithDomain: BXDriveBundleErrorDomain
                               code: BXDriveBundleCouldNotParseCue
                           userInfo: userInfo];
}
@end

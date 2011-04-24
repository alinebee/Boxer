/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXHelperAppCheck.h"
#import "BXPathEnumerator.h"

@implementation BXHelperAppCheck
@synthesize targetPath, appPath, addIfMissing;

- (id) initWithTargetPath: (NSString *)pathToCheck forAppAtPath: (NSString *)pathToApp
{
	if ((self = [super init]))
	{
		[self setTargetPath: pathToCheck];
		[self setAppPath: pathToApp];
		manager = [[NSFileManager alloc] init];
	}
	return self;
}

- (void) dealloc
{
	[self setTargetPath: nil], [targetPath release];
	[self setAppPath: nil], [appPath release];
	[manager release], manager = nil;
	
	[super dealloc];
}

- (void) main
{
	NSAssert(targetPath != nil, @"BXHelperAppCheck started without target path.");
	NSAssert(appPath != nil, @"BXHelperAppCheck started without helper application path.");
	
	//Bail out early if already cancelled
	if ([self isCancelled]) return;
	
	//Get the properties of the app for comparison
	NSBundle *app		= [NSBundle bundleWithPath: appPath];
	NSString *appName	= [[app objectForInfoDictionaryKey: @"CFBundleDisplayName"]
						   stringByAppendingPathExtension: @"app"];
	
	NSString *appVersion	= [app objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
	NSString *appIdentifier = [app bundleIdentifier];
	
	BXPathEnumerator *enumerator = [BXPathEnumerator enumeratorAtPath: targetPath];
	[enumerator setSkipSubdirectories: YES];
	[enumerator setSkipPackageContents: YES];
	[enumerator setFileTypes: [NSSet setWithObject: @"com.apple.application"]];
	
	//Trawl through the games folder looking for apps with the same identifier
	for (NSString *filePath in enumerator)
	{
		//Bail out if we're cancelled
		if ([self isCancelled]) return;
		
		NSBundle *checkedApp = [NSBundle bundleWithPath: filePath];
		if ([[checkedApp bundleIdentifier] isEqualToString: appIdentifier])
		{
			//Check if the app is up-to-date: if not, replace it with our own app
			NSString *checkedAppVersion = [checkedApp objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
			if (NSOrderedAscending == [checkedAppVersion compare: appVersion options: NSNumericSearch])
			{
				BOOL deleted = [manager removeItemAtPath: filePath error: nil];
				if (deleted)
				{
					NSString *newPath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent: appName];
					[manager copyItemAtPath: appPath toPath: newPath error: nil];
				}
			}
			//Bail out once we've found a matching app
			return;
		}
	}
	
	//If we got this far, then we didn't find any droplet:
	//copy a new one into the target folder if desired
	if (addIfMissing)
	{
		NSString *newPath = [targetPath stringByAppendingPathComponent: appName];
		[manager copyItemAtPath: appPath toPath: newPath error: nil];
	}
}
@end

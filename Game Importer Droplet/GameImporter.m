/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "GameImporter.h"
#import "Boxer.h"

@implementation GameImporter

- (void) warnAboutMissingBoxer
{
	//Display an alert to the user asking them to download Boxer.
	NSAlert *alert = [[NSAlert alloc] init];
	[alert setMessageText: NSLocalizedString(@"Boxer is required to import DOS games.",
											 @"Bold alert message shown when game importer cannot find a version of Boxer.")];
	[alert setInformativeText: NSLocalizedString(@"Boxer is a free MS-DOS emulator for Mac OS X v10.5 and above.",
												 @"Alert explanation shown when game importer cannot find a version of Boxer.")];
	
	[alert addButtonWithTitle: NSLocalizedString(@"Download Boxer", @"Default button in alert shown when game importer cannot find a version of Boxer. Clicking this button will open the Boxer website.")];
	[[alert addButtonWithTitle: NSLocalizedString(@"Close", @"Cancel button in alert shown when game importer cannot find a version of Boxer. Clicking this button will close the importer.")] setKeyEquivalent: @"\e"];
	
	//Run the alert and catch which button the user pressed
	NSInteger buttonPressed = [alert runModal];
	
	if (buttonPressed == NSAlertFirstButtonReturn)
	{
		NSString *URLString = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"WebsiteURL"];
		if ([URLString length]) [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: URLString]];
	}
	[alert release];
}

- (void) import: (NSURL *)fileURL
{
	BoxerApplication *boxer = [SBApplication applicationWithBundleIdentifier: @"net.washboardabs.boxer"];
	if (boxer)
	{
		[boxer import: fileURL];
		[boxer activate];
	}
	else
	{
		[self warnAboutMissingBoxer];
	}
}
- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
	[self import: nil];
	[NSApp terminate: self];
}

- (BOOL) application: (NSApplication *)application openFile: (NSString *)filePath
{
	
	[self import: [NSURL fileURLWithPath: filePath]];
	[NSApp terminate: self];
	
	return YES;
}

@end

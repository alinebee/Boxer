/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXAboutController.h"
#import "BXAppController.h"


@implementation BXAboutController
@synthesize websiteLink, version;

+ (id) controller
{
	static id singleton = nil;

	if (!singleton) singleton = [[self alloc] initWithWindowNibName: @"About"];
	return singleton;
}

//Set up all the appearance properties we couldn't in Interface Builder
- (void) awakeFromNib
{
	NSWindow *theWindow	= [self window];
	
	//Apply our custom background image to the window
	NSImage *theBackground	= [NSImage imageNamed: @"AboutBackground"];
	[theWindow setBackgroundColor: [NSColor colorWithPatternImage: theBackground]];
	
	//Lets the window be moved by clicking anywhere inside it
	[theWindow setMovableByWindowBackground: YES];
	
	//Set the version's number and appearance
	NSString *versionFormat	= NSLocalizedString(@"v%@ %@", @"Version string for display in About panel. First @ is human-readable version (e.g. 1.0beta), second @ is build number (e.g. 20090323-1.)");
	NSString *versionName	= [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
	NSString *buildNumber	= [[NSBundle mainBundle] objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
	NSString *versionString	= [NSString stringWithFormat: versionFormat, versionName, buildNumber, nil];
	[version setStringValue: versionString];
	
	//Make the button background appear all the time
	[websiteLink setShowsBorderOnlyWhileMouseInside: NO];
}

- (IBAction) showAcknowledgements: (id)sender
{
	[[NSApp delegate] showHelpAnchor: @"acknowledgements"];
}

@end

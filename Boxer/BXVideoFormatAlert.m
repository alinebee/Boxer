/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXVideoFormatAlert.h"
#import "BXAppController.h"

@implementation BXVideoFormatAlert
- (id) init
{
	if ((self = [super init]))
	{
		[self setMessageText:
		 NSLocalizedString(	@"You will need to install the Perian plugin to play your video in QuickTime Player.",
						   @"Title for sheet warning that user does not have ZMBV codec support - displayed after the user has recorded their first video.")];
		
		[self setInformativeText:
		 NSLocalizedString(	@"Perian is a free QuickTime plugin which adds support for many video formats.",
						   @"Explanation text for video codec warning sheet.")];
		
		[self addButtonWithTitle:
		 NSLocalizedString(@"Visit the Perian Website…", @"Button to download additional video codec library from codec warning sheet.")];
		NSButton *cancelButton = [self addButtonWithTitle:
								  NSLocalizedString(@"Cancel", @"Button to dismiss video codec warning sheet.")];
		[cancelButton setKeyEquivalent: @"\e"];
		
		[self setShowsSuppressionButton: YES];
		[[self suppressionButton] setState: NSOnState];
	}
	return self;
}

+ (void) alertDidEnd: (BXAlert *)alert returnCode: (int)returnCode contextInfo: (void *)contextInfo
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([[alert suppressionButton] state] == NSOnState) [defaults setBool: YES forKey: @"suppressCodecRequiredAlert"];
	if (returnCode == NSAlertFirstButtonReturn)
	{
		[[NSApp delegate] showPerianDownloadPage: self];
	}
	
	[alert release];
}
@end
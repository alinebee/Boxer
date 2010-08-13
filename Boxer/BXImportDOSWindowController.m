/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImportDOSWindowController.h"
#import "BXInputView.h"

@implementation BXImportDOSWindowController

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	//Set the appearance of the window background according to what kind of session we're running
	[[self inputView] setAppearance: BXInputViewBlueprintAppearance];
}

- (NSString *) windowTitleForDocumentDisplayName: (NSString *)displayName
{
	NSString *format = NSLocalizedString(@"Importing %@",
										 @"Title for game import window. %@ is the name of the gamebox/source path being imported.");
	return [NSString stringWithFormat: format, displayName, nil];
}

@end
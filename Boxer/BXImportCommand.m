/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImportCommand.h"
#import "BXAppController.h"

@implementation BXImportCommand

- (id) performDefaultImplementation
{
	NSError *importError = nil;
	NSURL *fileURL = [self directParameter];
	
	if (fileURL)
	{
		[[NSApp delegate] openImportSessionWithContentsOfURL: fileURL display: YES error: &importError];
	}
	else
	{
		[[NSApp delegate] orderFrontImportGamePanel: self];		
	}

	
	if (importError)
	{
		[self setScriptErrorNumber: [importError code]];
		[self setScriptErrorString: [importError localizedDescription]];
	}
	return nil;
}
@end

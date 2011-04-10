/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXImportFinalizingPanelController.h"
#import "BXImportWindowController.h"
#import "BXDriveImport.h"
#import "BXImportSession.h"
#import "BXAppController.h"

@implementation BXImportFinalizingPanelController
@synthesize controller;

- (BOOL) isIndeterminate
{
	return ([[controller document] stageProgressIndeterminate]);
}

- (BXOperationProgress) progress
{
	BXOperationProgress progress = [[controller document] stageProgress];

	//Massage the progress with an ease-out curve to make it appear quicker at the start of the transfer
	//Easing disabled for now because it's obvious on a large progress bar that it’s wrong - this needs
	//tweaking to be more subtle.
	//BXOperationProgress easedProgress = -progress * (progress - 2);
	BXOperationProgress easedProgress = progress;
	
	return easedProgress;
}

- (NSString *) progressDescription
{
	BXImportStage stage = [[controller document] importStage];
	BXOperation *transfer;
	
	switch (stage)
	{
		case BXImportSessionCopyingSourceFiles:
			transfer = [[controller document] sourceFileImportOperation];
			
			//IMPLEMENTATION NOTE: because the transfer can technically be any kind of operation,
			//we make sure it can actually report its transfer size
			if (transfer && ![transfer isIndeterminate] &&
				[transfer respondsToSelector:@selector(numBytes)] &&
				[transfer respondsToSelector:@selector(bytesTransferred)])
			{	
				float sizeInMB		= [(id)transfer numBytes] / 1000000.0f;
				float transferredMB	= [(id)transfer bytesTransferred] / 1000000.0f;
				
				NSString *format = NSLocalizedString(@"Importing game files… (%1$.01f MB of %2$.01f MB)",
													 @"Import progress description for copying source files stage. %1 is the number of MB transferred so far as a float, %2 is the total number of MB to be transferred as a float.");
				
				return [NSString stringWithFormat: format, transferredMB, sizeInMB, nil];
			}
			else
			{
				return NSLocalizedString(@"Importing game files…",
										 @"Import progress description for copying source files stage, before size of file transfer is known.");
			}
			
		case BXImportSessionCleaningGamebox:
			return NSLocalizedString(@"Removing unnecessary files…",
									 @"Import progress description for gamebox cleanup stage.");
			
		default:
			return @"";
	}
}

+ (NSSet *) keyPathsForValuesAffectingValueForKey: (NSString *)key
{
	NSSet *progressKeys = [NSSet setWithObjects: @"progressDescription", @"progress", @"indeterminate", nil];
	
	if ([progressKeys containsObject: key])
	{
		return [NSSet setWithObjects:
				@"controller.document.importStage",
				@"controller.document.stageProgress",
				@"controller.document.stageProgressIndeterminate",
				nil];
	}
	else
	{
		return [super keyPathsForValuesAffectingValueForKey: key];
	}
}

- (IBAction) showImportFinalizingHelp: (id)sender
{
	[[NSApp delegate] showHelpAnchor: @"import-finalizing"];
}

@end

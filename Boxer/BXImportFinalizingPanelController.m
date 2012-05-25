/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXImportFinalizingPanelController.h"
#import "BXImportWindowController.h"
#import "BXDriveImport.h"
#import "BXImportSession.h"
#import "BXAppController.h"
#import "NSAlert+BXAlert.h"

#pragma mark -
#pragma mark Private method declarations

@interface BXImportFinalizingPanelController ()

//Callback for confirmation alert shown by skipSourceFileImport:
- (void) _skipAlertDidEnd: (NSAlert *)alert
			   returnCode: (int)returnCode
			  contextInfo: (void *)contextInfo;

@end

#pragma mark -
#pragma mark Implementation

@implementation BXImportFinalizingPanelController
@synthesize controller = _controller;

#pragma mark -
#pragma mark Cancel button behaviour

+ (NSString *) cancelButtonLabelForImportType: (BXSourceFileImportType)importType
{	
	switch (importType)
	{
		case BXImportFromCDVolume:
		case BXImportFromCDImage:
		case BXImportFromFolderToCD:
			return NSLocalizedString(@"Skip CD import",
									 @"Button label to skip importing source files as a fake CD-ROM or CD image.");
		
		case BXImportFromFloppyVolume:
		case BXImportFromFloppyImage:
		case BXImportFromFolderToFloppy:
			return NSLocalizedString(@"Skip disk import",
									 @"Button label to skip importing source files as a fake floppy disk.");
			
		case BXImportFromHardDiskImage:
		case BXImportFromFolderToHardDisk:
			return NSLocalizedString(@"Skip disk import",
									 @"Button label to skip importing source files as a hard disk.");
			
		default:
			//This should never be used, as the above cases should cover all situations where the label can be used.
			return NSLocalizedString(@"Skip this step",
									 @"Button label to skip importing source files when the import type is not known.");
	}
}

//TODO: refactor all these properties into a single observation method to centralise the skip button's behaviour.

- (NSString *) cancelButtonLabel
{
	BXImportSession *session = self.controller.document;
	NSString *label;
    
	if (session.sourceFileImportRequired)
	{
		//If the import is necessary, then the cancel button represents cancelling the entire game import.
		label = NSLocalizedString(@"Stop importing", @"Button label to cancel the entire game import.");
	}
	else
	{
		BXSourceFileImportType importType = session.sourceFileImportType;
		label = [self.class cancelButtonLabelForImportType: importType];
	}
    //Tweak: since we'll confirm the user's cancellation, append ellipses
    //to indicate to the user that the action will not take effect immediately.
    //(We can't just bake these into cancelButtonLabelForImportType: as that
    //is also used for the confirmation sheet, which does take effect immediately.)
    NSString *cancelButtonFormat = NSLocalizedString(@"%@…", @"Format for the label of the initial cancel button when finalizing import, which should indicate that the action will not take effect immediately. %@ is the original button label.");
    label = [NSString stringWithFormat: cancelButtonFormat, label, nil];
    return label;
}

+ (NSSet *) keyPathsForValuesAffectingCancelButtonLabel
{
	return [NSSet setWithObjects: @"controller.document.sourceFileImportType",  @"controller.document.sourceFileImportRequired", nil];
}

- (BOOL) cancelButtonEnabled
{
	BXImportSession *session = self.controller.document;
	BXImportStage stage = session.importStage;
	
	//Disable the button when finalizing or skipping.
	if (stage == BXImportSessionCancellingSourceFileImport || stage == BXImportSessionCleaningGamebox) return NO;
	
	return YES;
}

- (BOOL) showAdditionalCDTips
{
    BXSourceFileImportType importType = self.controller.document.sourceFileImportType;
    
    return (importType == BXImportFromCDImage || importType == BXImportFromCDVolume);
}

+ (NSSet *) keyPathsForValuesAffectingCancelButtonEnabled
{
	return [NSSet setWithObject: @"controller.document.sourceFileImportType"];
}


+ (NSSet *) keyPathsForValuesAffectingShowAdditionalCDTips
{
	return [NSSet setWithObject: @"controller.document.sourceFileImportOperation"];
}

#pragma mark -
#pragma mark Progress description

+ (NSString *) stageDescriptionForImportType: (BXSourceFileImportType)importType
{
	switch (importType)
	{
		case BXImportFromCDVolume:
		case BXImportFromCDImage:
			return NSLocalizedString(@"Importing game CD…",
									 @"Progress description when importing source files from floppy disk.");
		
		case BXImportFromFloppyVolume:
		case BXImportFromFloppyImage:
			return NSLocalizedString(@"Importing game disk…",
									 @"Progress description when importing source files from floppy disk.");
		
		case BXImportFromFolderToCD:
			return NSLocalizedString(@"Importing source files as a CD…",
									 @"Progress description when importing source files from a folder into a fake CD.");
		
		case BXImportFromFolderToFloppy:
			return NSLocalizedString(@"Importing source files as a floppy disk…",
									 @"Progress description when importing source files from a folder into a fake floppy disk.");
		
		case BXImportFromHardDiskImage:
		case BXImportFromFolderToHardDisk:
			return NSLocalizedString(@"Importing source files as a hard disk…",
									 @"Progress description when importing source files from a folder or disk image into a secondary hard disk.");

		case BXImportFromPreInstalledGame:
		default:
			return NSLocalizedString(@"Importing game files…",
									 @"Generic progress description for importing source files stage.");
	}
}

- (NSString *) progressDescription
{
	BXImportSession *session = self.controller.document;
	BXImportStage stage = session.importStage;
	
	if (stage == BXImportSessionImportingSourceFiles)
	{
		BXOperation *transfer				= session.sourceFileImportOperation;
		BXSourceFileImportType importType	= session.sourceFileImportType;
		NSString *stageDescription			= [self.class stageDescriptionForImportType: importType];
		
		//Append the current file transfer progress to the base description, if available
		if (transfer && !transfer.isIndeterminate &&
			[transfer respondsToSelector: @selector(numBytes)] &&
			[transfer respondsToSelector: @selector(bytesTransferred)])
		{	
			float sizeInMB		= (float)([(id)transfer numBytes] / 1000000.0);
			float transferredMB	= (float)([(id)transfer bytesTransferred] / 1000000.0);
			
			NSString *format = NSLocalizedString(@"%1$@ (%2$.01f MB of %3$.01f MB)",
												 @"Import progress description for importing source files stage. %1 is the basic description of the stage as a string (followed by ellipses), %2is the number of MB transferred so far as a float, %3 is the total number of MB to be transferred as a float.");
			
			return [NSString stringWithFormat: format, stageDescription, transferredMB, sizeInMB, nil];
		}
		else return stageDescription;
	}
	else if (stage == BXImportSessionCleaningGamebox || stage == BXImportSessionCancellingSourceFileImport)
	{
		return NSLocalizedString(@"Cleaning up after ourselves…",
								 @"Import progress description for gamebox cleanup stage.");
			
	}
	else return @"";
}

+ (NSSet *) keyPathsForValuesAffectingProgressDescription
{
	return [NSSet setWithObjects:
			@"controller.document.importStage",
			@"controller.document.sourceFileImportType",
			@"controller.document.stageProgress",
			@"controller.document.stageProgressIndeterminate",
			nil];
}


#pragma mark -
#pragma mark UI actions

+ (NSAlert *) skipAlertForSourcePath: (NSString *)sourcePath
								type: (BXSourceFileImportType)importType
{
	NSString *message;
	NSString *informativeText;
	
	switch (importType)
	{
		case BXImportFromCDImage:
		case BXImportFromCDVolume:
			message = NSLocalizedString(@"Boxer is importing the game’s CD so that you can play without it.",
										@"Bold message in skip confirmation alert when importing from a CD or CD image.");
			informativeText = NSLocalizedString(@"If you skip this step now, you can import the CD later from the Drives Inspector panel while playing.",
												@"Explanatory text in skip confirmation alert when importing from a CD or CD image.");
			break;
			
		case BXImportFromFloppyImage:
		case BXImportFromFloppyVolume:
			message = NSLocalizedString(@"Boxer is importing the game’s floppy disk so that the game can find files on it later.",
										@"Bold message in skip confirmation alert when importing from a floppy disk or floppy image while playing.");
			informativeText = NSLocalizedString(@"If you skip this step now, you can import the disk later from the Drives Inspector panel.",
												@"Explanatory text in skip confirmation alert when importing from a floppy disk or floppy image.");
			break;
		
		case BXImportFromFolderToCD:
		case BXImportFromFolderToFloppy:
		case BXImportFromFolderToHardDisk:
		case BXImportFromHardDiskImage:
		default:
			message = NSLocalizedString(@"Boxer is importing the game’s source files so that the game can find them later.",
										@"Bold message in skip confirmation alert when importing from a folder or other source with no more specific message.");
			informativeText = NSLocalizedString(@"Skipping this step may prevent the game from working if it needs those source files.",
										@"Explanatory text in skip confirmation alert when importing from a folder or other source with no more specific message.");
			break;
	}
	
	NSString *skipLabel		= [self cancelButtonLabelForImportType: importType];
	NSString *cancelLabel	= NSLocalizedString(@"Cancel", @"Cancel the current action and return to what the user was doing");		
	
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = message;
	alert.informativeText = informativeText;
	
	[alert addButtonWithTitle: skipLabel];
	[[alert addButtonWithTitle: cancelLabel] setKeyEquivalent: @"\e"];	//Ensure the cancel button always uses Escape
	
	return [alert autorelease];
}

- (IBAction) cancelSourceFileImport: (id)sender
{
	BXImportSession *session = self.controller.document;
	//If the import is required and cannot be skipped, then treat this action as a request
	//to stop the entire game import process - pass this up to the as a close window attempt
	//(which will use the standard session machinery for confirming the close.)
	if (session.sourceFileImportRequired)
	{
		[self.controller.window performClose: sender];
	}
	//Otherwise, show a custom are-you-sure-you-want-to-skip-this alert sheet.
	else
	{
		NSAlert *skipAlert = [self.class skipAlertForSourcePath: session.sourcePath
                                                           type: session.sourceFileImportType];
		
		if (skipAlert)
		{
			[skipAlert adoptIconFromWindow: self.controller.window];
			[skipAlert beginSheetModalForWindow: self.controller.window
								  modalDelegate: self
								 didEndSelector: @selector(_skipAlertDidEnd:returnCode:contextInfo:)
									contextInfo: NULL];
		}
		//If skipAlertForSourcePath:type: thought that it wasn't worth showing any confirmation
		//at all, then go right ahead and cancel.
		//TODO: move that decision downstream into BXImportSession. 
		else
		{
			[session cancelSourceFileImport];
		}
	}
}

- (void) _skipAlertDidEnd: (NSAlert *)alert
			   returnCode: (int)returnCode
			  contextInfo: (void *)contextInfo
{
	if (returnCode == NSAlertFirstButtonReturn)
	{
		[self.controller.document cancelSourceFileImport];
	}
}


- (IBAction) showImportFinalizingHelp: (id)sender
{
	[[NSApp delegate] showHelpAnchor: @"import-finalizing"];
}

@end

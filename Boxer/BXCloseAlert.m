/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXCloseAlert.h"
#import "NSAlert+BXAlert.h"
#import "BXSession.h"

@implementation BXCloseAlert

- (id) init
{
	if ((self = [super init]))
	{
		NSString *closeLabel	= NSLocalizedString(@"Close",	@"Used in confirmation sheets to close the current window");
		NSString *cancelLabel	= NSLocalizedString(@"Cancel",	@"Cancel the current action and return to what the user was doing");		
	
		[self addButtonWithTitle: closeLabel];
		[[self addButtonWithTitle: cancelLabel] setKeyEquivalent: @"\e"];	//Ensure the cancel button always uses Escape
	}
	return self;
}

+ (BXCloseAlert *) closeAlertAfterSessionExited: (BXSession *)theSession
{
	BXCloseAlert *alert = [self alert];

	NSString *sessionName	= [theSession displayName];
	NSString *messageFormat	= NSLocalizedString(@"%@ has now finished.",
												@"Title of confirmation sheet after a game exits. %@ is the display name of the current DOS session.)");

	[alert setMessageText:		[NSString stringWithFormat: messageFormat, sessionName]];
	[alert setInformativeText:	NSLocalizedString(@"If the program quit unexpectedly, you can return to DOS to examine any error messages.",
												@"Informative text of confirmation sheet after a game exits.")];

	[[[alert buttons] lastObject] setTitle: NSLocalizedString(@"Return to DOS",
															  @"Cancel button for confirmation sheet after game exits: will return user to the DOS prompt.")];
	return alert;
}

+ (BXCloseAlert *) closeAlertWhileSessionIsEmulating: (BXSession *)theSession
{	
	BXCloseAlert *alert = [self alert];
	
	NSString *sessionName	= [theSession displayName];
	NSString *messageFormat	= NSLocalizedString(@"Do you want to close %@ while it is still running?",
												@"Title of confirmation sheet when closing an active DOS session. %@ is the display name of the current DOS session.");

	[alert setMessageText:		[NSString stringWithFormat: messageFormat, sessionName]];
	[alert setInformativeText:	NSLocalizedString(	@"Any unsaved data will be lost.",
													@"Informative text of confirmation sheet when closing an active DOS session.")];

	//Disable the suppression button for now.
	//[alert setShowsSuppressionButton: YES];
	return alert;
}

+ (BXCloseAlert *) closeAlertWhileImportingDrives: (BXSession *)theSession
{	
	BXCloseAlert *alert = [self alert];
	
	NSString *sessionName	= [theSession displayName];
	NSString *messageFormat	= NSLocalizedString(@"A drive is still being imported into %@.",
												@"Title of confirmation sheet when closing a session that has active drive import operations. %@ is the display name of the current DOS session.");
	
	[alert setMessageText:		[NSString stringWithFormat: messageFormat, sessionName]];
	[alert setInformativeText:	NSLocalizedString(@"If you close now, the import will be cancelled.",
												  @"Informative text of confirmation sheet when closing a session that has active drive import operations.")];
	
	return alert;
}


+ (BXCloseAlert *) closeAlertWhileImportingGame: (BXImport *)theSession
{
	BXCloseAlert *alert = [self alert];
	
	NSString *sessionName	= [theSession displayName];
	NSString *messageFormat	= NSLocalizedString(@"%@ has not finished importing.",
												@"Title of confirmation sheet when closing a game import session. %@ is the display name of the gamebox.");
	
	[alert setMessageText:		[NSString stringWithFormat: messageFormat, sessionName]];
	[alert setInformativeText:	NSLocalizedString(@"If you stop importing, any already-imported game files will be discarded.",
												  @"Informative text of confirmation sheet when closing a game import session.")];
	
	[[[alert buttons] objectAtIndex: 0] setTitle: NSLocalizedString(@"Stop Importing",
																	@"Close button for confirmation sheet when closing a game import session.")];
	
	return alert;
}

+ (BXCloseAlert *) closeAlertAfterWindowsOnlyProgramExited: (NSString *)programPath
{	
	BXCloseAlert *alert = [self alert];
	
	NSString *programName = [programPath lastPathComponent];
	
	NSString *messageFormat	= NSLocalizedString(@"“%@” is a Microsoft Windows program, which Boxer does not support.",
												@"Title of warning sheet after running a Windows-only executable. %@ is the original filename of the executable.");
	
	[alert setMessageText: [NSString stringWithFormat: messageFormat, programName]];
	
	[alert setInformativeText:	NSLocalizedString(@"You may be able to run it in a Windows emulator instead, such as CrossOver Games.",
												  @"Informative text of warning sheet after running a Windows-only executable or importing a Windows-only game.")];
	
	[[[alert buttons] lastObject] setTitle: NSLocalizedString(@"Return to DOS",
															  @"Cancel button for warning sheet after running a Windows-only executable: will return user to the DOS prompt.")];
	
	[alert setShowsHelp: YES];
	[alert setHelpAnchor: @"windows-only-programs"];
	
	return alert;
}


//Overridden to adopt the icon of the window we're displaying ourselves in
//TODO: this should really be handled in the alert creation context
- (void) beginSheetModalForWindow: (NSWindow *)window
					modalDelegate: (id)delegate
				   didEndSelector: (SEL)didEndSelector
					  contextInfo: (void *)contextInfo
{
	[self adoptIconFromWindow: window];
	return [super beginSheetModalForWindow: window
							 modalDelegate: delegate
							didEndSelector: didEndSelector
							   contextInfo: contextInfo];
}

@end

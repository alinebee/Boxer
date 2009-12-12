/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXCloseAlert.h"
#import "BXSession.h"

@implementation BXCloseAlert

//Autoreleased constructor for general close alerts
//-------------------------------------------------
- (id) init
{
	if ((self = [super init]))
	{
		NSString *closeLabel	= NSLocalizedString(@"Close",	@"Used in confirmation sheets to close the current window");
		NSString *cancelLabel	= NSLocalizedString(@"Cancel",	@"Cancel the current action and return to what the user was doing");		
	
		[self addButtonWithTitle: closeLabel];
		[self addButtonWithTitle: cancelLabel];
		[[self cancelButton] setKeyEquivalent: @"\e"];	//Ensure the cancel button always uses Escape
	}
	return self;
}

- (NSButton *)closeButton	{ return [[self buttons] objectAtIndex: 0]; }
- (NSButton *)cancelButton	{ return [[self buttons] objectAtIndex: 1]; }


//Boxer's predefined alerts
//-------------------------

+ (BXCloseAlert *) closeAlertWhenReplacingSession: (BXSession *)theSession
{
	BXCloseAlert *alert = [self alert];

	NSString *processName	= [theSession sessionDisplayName];
	NSString *messageFormat	= NSLocalizedString(@"Boxer supports only one DOS session at a time. Do you want to close %@ to start a new session?",
												@"Title of confirmation sheet when starting a new DOS session while one is already active. %@ is the display-ready name of the current game package or running process (will usually be capitalized and without file extension.)");

	[alert setMessageText:		[NSString stringWithFormat: messageFormat, processName]];
	[alert setInformativeText:	NSLocalizedString(	@"Any unsaved data in this session will be lost.",
													@"Informative text of confirmation sheet when closing an active DOS session to open another.")];
	return alert;
}


+ (BXCloseAlert *) closeAlertAfterSessionExited: (BXSession *)theSession
{
	BXCloseAlert *alert = [self alert];

	NSString *processName	= [theSession sessionDisplayName];
	NSString *messageFormat	= NSLocalizedString(@"%@ has now finished.",
												@"Title of confirmation sheet after a game exits. %@ is the display-ready name of the current game package or running process (will usually be capitalized and without file extension.)");

	[alert setMessageText:		[NSString stringWithFormat: messageFormat, processName]];
	[alert setInformativeText:	NSLocalizedString(@"If the program quit unexpectedly, you can return to DOS to examine any error messages.",
												@"Informative text of confirmation sheet after a game exits.")];

	[[alert cancelButton] setTitle: NSLocalizedString(	@"Return to DOS",
														@"Cancel button for confirmation sheet after game exits: will return user to the DOS prompt.")];
	return alert;
}

+ (BXCloseAlert *) closeAlertWhileSessionIsActive: (BXSession *)theSession
{	
	BXCloseAlert *alert = [self alert];
	
	NSString *processName	= [theSession sessionDisplayName];
	NSString *messageFormat	= NSLocalizedString(@"Do you want to close this window while %@ is running?",
												@"Title of confirmation sheet when closing an active DOS session. %@ is the display-ready name of the current game package or running process (will usually be capitalized and without file extension.)");

	[alert setMessageText:		[NSString stringWithFormat: messageFormat, processName]];
	[alert setInformativeText:	NSLocalizedString(	@"Any unsaved data will be lost.",
													@"Informative text of confirmation sheet when closing an active DOS session.")];

	[alert setShowsSuppressionButton: YES];
	return alert;
}


//Dispatch and callback methods
//-----------------------------

- (void) beginSheetModalForWindow: (NSWindow *)window
{
	[self adoptIconFromWindow: window];
	[self retain];	//The alert will be released in the callback function below
	
	//Note: we pass window as the context info so that the alertDidEnd:returnCode:contextInfo: method
	//can close it; the method cannot otherwise determine to which window the alert sheet was attached.
	[self beginSheetModalForWindow:	window
					modalDelegate:	[self class]
					didEndSelector:	@selector(alertDidEnd:returnCode:contextInfo:)
					contextInfo:	window];
}

+ (void) alertDidEnd: (BXCloseAlert *)alert returnCode: (int)returnCode contextInfo: (NSWindow *)window
{
	if ([alert showsSuppressionButton] && [[alert suppressionButton] state] == NSOnState)
		[[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"suppressCloseAlert"];

	//First button is close, second button is cancel
	if (returnCode == NSAlertFirstButtonReturn) [window close];
	
	[alert release];
}
@end
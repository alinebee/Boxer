/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXCloseAlert.h"
#import "NSAlert+BXAlert.h"
#import "BXImportSession.h"
#import "BXBaseAppController.h"

@implementation BXCloseAlert

- (id) init
{
	if ((self = [super init]))
	{
		NSString *closeLabel	= NSLocalizedString(@"Close",	@"Used in confirmation sheets to close the current window");
		NSString *cancelLabel	= NSLocalizedString(@"Cancel",	@"Cancel the current action and return to what the user was doing");		
	
		[self addButtonWithTitle: closeLabel];
		[self addButtonWithTitle: cancelLabel].keyEquivalent = @"\e"; //Ensure the cancel button always uses Escape
	}
	return self;
}

#pragma mark -
#pragma mark Close alerts

+ (BXCloseAlert *) closeAlertWhileSessionIsEmulating: (BXSession *)theSession
{	
	BXCloseAlert *alert = [self alert];
	
    if ([[NSApp delegate] isStandaloneGameBundle])
    {
        NSString *sessionName	= theSession.displayName;
        NSString *messageFormat	= NSLocalizedString(@"Do you want to quit %@?",
                                                    @"Title of confirmation sheet when quitting a standalone game app while the game is still running. %@ is the display name of the app.");
        
        alert.messageText = [NSString stringWithFormat: messageFormat, sessionName];
        alert.informativeText = NSLocalizedString(@"Any unsaved progress will be lost.",
                                                  @"Informative text of confirmation sheet when quitting a standalone game app while the game is still running.");
        
        NSButton *closeButton = [alert.buttons objectAtIndex: 0];
        closeButton.title = NSLocalizedString(@"Quit",
                                              @"Close button for confirmation sheet when quitting a standalone game app.");
    }
    else
    {
        NSString *sessionName	= theSession.displayName;
        NSString *messageFormat	= NSLocalizedString(@"Do you want to close %@ while it is still running?",
                                                    @"Title of confirmation sheet when closing an active DOS session. %@ is the display name of the current DOS session.");

        alert.messageText = [NSString stringWithFormat: messageFormat, sessionName];
        alert.informativeText = NSLocalizedString(@"Any unsaved data will be lost.",
                                                  @"Informative text of confirmation sheet when closing an active DOS session.");
    }
    
	return alert;
}

+ (BXCloseAlert *) closeAlertWhileImportingDrives: (BXSession *)theSession
{	
	BXCloseAlert *alert = [self alert];
	
	NSString *sessionName	= theSession.displayName;
	NSString *messageFormat	= NSLocalizedString(@"A drive is still being imported into %@.",
												@"Title of confirmation sheet when closing a session that has active drive import operations. %@ is the display name of the current DOS session.");
	
	alert.messageText =	[NSString stringWithFormat: messageFormat, sessionName];
	alert.informativeText =	NSLocalizedString(@"If you close now, the import will be cancelled.",
                                              @"Informative text of confirmation sheet when closing a session that has active drive import operations.");
	
	return alert;
}

+ (BXCloseAlert *) closeAlertAfterWindowsOnlyProgramExited: (NSString *)programPath
{	
	BXCloseAlert *alert = [self alert];
	
	NSString *programName = programPath.lastPathComponent;
	
	NSString *messageFormat	= NSLocalizedString(@"“%@” is a Windows program. Boxer only supports MS-DOS programs.",
												@"Title of warning sheet after running a Windows-only executable. %@ is the original filename of the executable.");
	
	alert.messageText = [NSString stringWithFormat: messageFormat, programName];
	
	alert.informativeText =	NSLocalizedString(@"You can run this program in a Windows emulator instead. For more help, click the ? button.",
                                              @"Informative text of warning sheet after running a Windows-only executable or importing a Windows-only game.");
	
    NSButton *cancelButton = alert.buttons.lastObject;
	cancelButton.title = NSLocalizedString(@"Return to DOS",
                                           @"Cancel button for warning sheet after running a Windows-only executable: will return user to the DOS prompt.");
	
	alert.showsHelp = YES;
	alert.helpAnchor = @"windows-games";
	
	return alert;
}


#pragma mark -
#pragma mark Close-while-importing alerts

+ (BXCloseAlert *) closeAlertWhileImportingGame: (BXImportSession *)theSession
{
	BXCloseAlert *alert = [self alert];
	
	NSString *sessionName	= theSession.displayName;
	NSString *messageFormat	= NSLocalizedString(@"Boxer has not finished importing %@.",
												@"Title of confirmation sheet when closing a game import session. %@ is the display name of the gamebox.");
	
	alert.messageText = [NSString stringWithFormat: messageFormat, sessionName];
	alert.informativeText = NSLocalizedString(@"If you stop importing, any already-imported game files will be discarded.",
                                              @"Informative text of confirmation sheet when closing a game import session.");
	
	NSButton *closeButton = [alert.buttons objectAtIndex: 0];
	closeButton.title = NSLocalizedString(@"Stop Importing",
                                          @"Close button for confirmation sheet when closing a game import session.");
    
    return alert;
}

+ (BXCloseAlert *) closeAlertWhileRunningInstaller: (BXImportSession *)theSession
{
	BXCloseAlert *alert = [self alert];
	
	NSString *sessionName	= theSession.displayName;
	NSString *messageFormat	= NSLocalizedString(@"Do you want to finish importing %@ first?",
												@"Title of confirmation sheet when closing a game import session while an installer is still running. %@ is the display name of the gamebox.");
	
	alert.messageText = [NSString stringWithFormat: messageFormat, sessionName];
	alert.informativeText =	NSLocalizedString(@"If you stop importing, any already-imported game files will be discarded.",
                                              @"Informative text of confirmation sheet when closing a game import session.");
	
    
    NSButton *closeAndFinishButton = [alert.buttons objectAtIndex: 0];
	closeAndFinishButton.title = NSLocalizedString(@"Finish Importing",
                                                   @"Close button for confirmation sheet when closing a game import session while an installer is running.");
    
    //Add a third button for stopping without importing.
    [alert addButtonWithTitle: NSLocalizedString(@"Stop Importing",
                                                 @"Close button for confirmation sheet when closing a game import session.")];
    
	
	return alert;
}


#pragma mark -
#pragma mark Restart alerts

+ (BXCloseAlert *) restartAlertWhileSessionIsEmulating: (BXSession *)theSession
{	
	BXCloseAlert *alert = [self alert];
    
	if ([[NSApp delegate] isStandaloneGameBundle])
    {
        NSString *sessionName	= theSession.displayName;
        NSString *messageFormat	= NSLocalizedString(@"Do you want to restart %@?",
                                                    @"Title of confirmation sheet when restarting a standalone game app. %@ is the display name of the app.");
        
        alert.messageText = [NSString stringWithFormat: messageFormat, sessionName];
        alert.informativeText = NSLocalizedString(@"Any unsaved progress will be lost.",
                                                  @"Informative text of confirmation sheet when restarting a standalone game app.");
	}
    else
    {
        NSString *sessionName	= theSession.displayName;
        NSString *messageFormat	= NSLocalizedString(@"Do you want to restart %@ while it is still running?",
                                                    @"Title of confirmation sheet when restarting an active DOS session. %@ is the display name of the current DOS session.");
        
        alert.messageText = [NSString stringWithFormat: messageFormat, sessionName];
        alert.informativeText = NSLocalizedString(@"Any unsaved data will be lost.",
                                                  @"Informative text of confirmation sheet when closing an active DOS session.");
    }
    
    NSButton *closeButton = [alert.buttons objectAtIndex: 0];
	closeButton.title = NSLocalizedString(@"Restart",
                                          @"Close button for confirmation sheet when restarting a game session.");
    
	return alert;
}

+ (BXCloseAlert *) restartAlertWhileImportingDrives: (BXSession *)theSession
{	
	BXCloseAlert *alert = [self alert];
	
	NSString *sessionName	= theSession.displayName;
	NSString *messageFormat	= NSLocalizedString(@"A drive is still being imported into %@.",
												@"Title of confirmation sheet when closing a session that has active drive import operations. %@ is the display name of the current DOS session.");
	
	alert.messageText =	[NSString stringWithFormat: messageFormat, sessionName];
	alert.informativeText =	NSLocalizedString(@"If you restart now, the import will be cancelled.",
                                              @"Informative text of confirmation sheet when restarting a session that has active drive import operations.");
    
	NSButton *closeButton = [alert.buttons objectAtIndex: 0];
	closeButton.title = NSLocalizedString(@"Restart",
                                          @"Close button for confirmation sheet when restarting a game session.");
	
	return alert;
}


#pragma mark -
#pragma mark Helper methods

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

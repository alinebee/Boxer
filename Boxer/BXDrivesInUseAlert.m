/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDrivesInUseAlert.h"
#import "BXDrive.h"
#import "BXSession.h"
#import "BXEmulator+BXDOSFileSystem.h"

@implementation BXDrivesInUseAlert

- (id) initWithDrives: (NSArray *)drivesInUse
           forSession: (BXSession *)session
{
    self = [super init];
	if (self)
	{
		//Since this may cause dataloss, I think we're justified in using caution alerts
        self.alertStyle = NSCriticalAlertStyle;
        
        //Use the session's own icon for the alert
        NSImage *icon = [session.representedIcon copy];
        icon.size = NSMakeSize(128, 128);
        self.icon = [icon autorelease];
        
		NSString *processName = session.processDisplayName;
        if (!processName)
            processName = session.displayName;
		
		if (drivesInUse.count > 1)
		{
			NSString *messageFormat = NSLocalizedString(
				@"The selected drives are in use by %@. Are you sure you want to eject them?",
				@"Title for confirmation sheet when unmounting multiple drives that are in use. %@ is the display-ready name of the current DOS process.");
			
            self.messageText = [NSString stringWithFormat: messageFormat, processName];
		}
		else
		{
			BXDrive *drive = [drivesInUse lastObject];
			NSString *messageFormat = NSLocalizedString(
				@"Drive %1$@: is in use by %2$@. Are you sure you want to eject it?",
				@"Title for confirmation sheet when unmounting a single drive that is in use. %1$@ is the uppercase letter of the drive, %@ is the display-ready name of the current DOS process.");
            self.messageText = [NSString stringWithFormat: messageFormat, drive.letter, processName];
		}

        self.informativeText = NSLocalizedString(@"Ejecting a drive while it is in use may cause programs that depend on the drive to crash.",
                                                 @"Explanatory text for confirmation sheet when unmounting one or more drives that are in use.");
		
		
		NSString *unmountLabel	= NSLocalizedString(@"Remove",	@"Used in confirmation sheets to confirm unmounting one or more drives");
		NSString *cancelLabel	= NSLocalizedString(@"Cancel",	@"Cancel the current action and return to what the user was doing");
		
		[self addButtonWithTitle: unmountLabel];
		
		NSButton *cancelButton = [self addButtonWithTitle: cancelLabel];
        cancelButton.keyEquivalent = @"\e";
	}
	return self;
}

@end

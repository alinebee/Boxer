/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXMountPanelController.h"
#import "BXSession+BXFileManager.h"
#import "BXAppController.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulatorErrors.h"
#import "BXEmulator+BXShell.h"
#import "NSWorkspace+BXFileTypes.h"
#import "BXDrive.h"


@implementation BXMountPanelController
@synthesize driveType, driveLetter, readOnlyToggle;

+ (id) controller
{
	static BXMountPanelController *singleton = nil;
	if (!singleton) singleton = [[self alloc] initWithNibName: @"MountPanelOptions" bundle: nil];
	return singleton;
}

- (id) init
{
	if ((self = [super init]))
	{
		previousReadOnlyState = NSMixedState;
	}
	return self;
}


- (void) showMountPanelForSession: (BXSession *)theSession
{
	[self setRepresentedObject: theSession];
	
	NSOpenPanel *openPanel	= [NSOpenPanel openPanel];
	
	[openPanel setCanChooseFiles: YES];
	[openPanel setCanChooseDirectories: YES];
	[openPanel setTreatsFilePackagesAsDirectories: YES];
	[openPanel setMessage:	NSLocalizedString(@"Choose a folder, CD-ROM or disc image to add as a new DOS drive.", @"Help text shown at the top of mount-a-new-drive panel.")];
	[openPanel setPrompt:	NSLocalizedString(@"Add drive", @"Label shown on accept button in mount-a-new-drive panel.")];
	
	[openPanel setAccessoryView: [self view]];
	[openPanel setDelegate: self];
	
	[self populateDrivesFromSession: theSession];

    NSString *baseDirectory = [[theSession gamePackage] resourcePath];
    
	[openPanel beginSheetForDirectory: baseDirectory
                                 file: nil
                                types: [[BXAppController mountableTypes] allObjects]
                       modalForWindow: [theSession windowForSheet]
                        modalDelegate: self
                       didEndSelector: @selector(mountChosenItem:returnCode:contextInfo:)
                          contextInfo: nil];	
}

//(Re)initialise the possible values for drive letters
- (void) populateDrivesFromSession: (BXSession *)theSession
{	
	BXEmulator *theEmulator = [theSession emulator];
	NSArray *driveLetters	= [BXEmulator driveLetters];
	
	//First, strip any existing options after the first two (which are Auto and a divider)
	while ([driveLetter numberOfItems] > 2) [driveLetter removeItemAtIndex: 2];
	
	//Now, repopulate the menu
	for (NSString *letter in driveLetters)
	{
    	NSMenuItem *option	= [[NSMenuItem alloc] init];
		NSString *title		= [NSString stringWithFormat: @"%@:", letter];
		BXDrive *drive      = [theEmulator driveAtLetter: letter];
		
        //Mark already-occupied drive letters with the title of the drive occupying that letter.
        //Also, disable locked drive letters (and hide hidden drives altogether).
		if (drive)
		{
            //If the drive is hidden or an internal DOSBox drive,
            //skip it altogether and don't show an entry
            if ([drive isHidden] || [drive isInternal]) continue;
            
            //If the drive is locked, disable the entry - it cannot be replaced
            if ([drive isLocked]) [option setEnabled: NO];
            
            //Append the drive title to the letter to form the menu item's label
            title = [title stringByAppendingFormat: @" (%@)", [drive title], nil];
		}
		
		[option setTitle: title];
		[option setRepresentedObject: letter];
		
		[[driveLetter menu] addItem: option];
        
        [option release];
	}
	
	[driveLetter selectItemAtIndex: 0];
}

//Toggle the mount panel options depending on the selected file
- (void) syncMountOptionsForPanel: (NSOpenPanel *)openPanel
{
    BXSession *session = [self representedObject];
	NSString *path = [[openPanel URL] path];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	if (path)
	{
		//Don't allow drive type to be configured for disc images: instead,
        //force it to CD-ROM/floppy while an appropriate image is selected
		BOOL isImage = [workspace file: path matchesTypes: [BXAppController mountableImageTypes]];
		if (isImage)
		{
			[driveType setEnabled: NO];
			//Back up the current selection and then override it
			if (!previousDriveTypeSelection)
			{
				previousDriveTypeSelection = [driveType selectedItem];
			}
			
			BOOL isFloppyImage = [workspace file: path matchesTypes: [BXAppController floppyVolumeTypes]];
			NSUInteger optionIndex = [driveType indexOfItemWithTag: isFloppyImage ? BXDriveFloppyDisk : BXDriveCDROM];
			[driveType selectItemAtIndex: optionIndex];
		}
		else
		{
			[driveType setEnabled: YES];
			//Restore the previously selected type
			if (previousDriveTypeSelection)
			{
				[driveType selectItem: previousDriveTypeSelection];
				previousDriveTypeSelection = nil;
			}
		}		
		
		
		//Now determine what the automatic options will do for the selected path
		BXDriveType selectedType	= [[driveType selectedItem] tag];
		BXDriveType preferredType	= [BXDrive preferredTypeForPath: path];

		BXDrive *fakeDrive			= [BXDrive driveFromPath: path atLetter: nil withType: selectedType];
		NSString *preferredLetter	= [session preferredLetterForDrive: fakeDrive
                                                    withQueueBehaviour: BXDriveQueueIfAppropriate];
		
		NSMenuItem *autoTypeOption		= [driveType itemAtIndex: 0];
		NSMenuItem *preferredTypeOption	= [driveType itemAtIndex: [driveType indexOfItemWithTag: preferredType]];
		
		NSMenuItem *autoLetterOption		= [driveLetter itemAtIndex: 0];
		NSMenuItem *preferredLetterOption	= [driveLetter itemAtIndex: [driveLetter indexOfItemWithRepresentedObject: preferredLetter]];
		

		NSString *autoLabel = NSLocalizedString(
			@"Auto (%@)",
			@"Title format for automatic drive type/letter option. Shown in popup buttons on mount-a-new-drive sheet. %@ is the title of the real option whose value will be used if auto is chosen."
												);		
		[autoTypeOption setTitle:	[NSString stringWithFormat: autoLabel, [preferredTypeOption title], nil]];
		[autoLetterOption setTitle:	[NSString stringWithFormat: autoLabel, [preferredLetterOption title], nil]];

		[driveLetter setEnabled: YES];

		
		//Override the read-only option when the drive type is CD-ROM or Auto (CD-ROM),
		//or when the selected path is not writable
		if ((selectedType == BXDriveCDROM) || 
			(selectedType == BXDriveAutodetect && preferredType == BXDriveCDROM) ||
			(![[NSFileManager defaultManager] isWritableFileAtPath: path]))
		{
			[readOnlyToggle setEnabled: NO];
			//Back up the previous state and override it
			if (previousReadOnlyState == NSMixedState)
			{
				previousReadOnlyState = [readOnlyToggle state];
				[readOnlyToggle setState: NSOnState];
			}
		}
		else
		{
			[readOnlyToggle setEnabled: YES];
			//Restore the previous state
			if (previousReadOnlyState != NSMixedState)
			{
				[readOnlyToggle setState: NSOffState];
				previousReadOnlyState = NSMixedState;
			}
		}
	}
	else
	{
		[driveType setEnabled: NO];
		[driveLetter setEnabled: NO];
		[readOnlyToggle setEnabled: NO];
	}
}

//Fired whenever the drive type selection is changed: updates the drive letter to match the appropriate selected type
- (IBAction) updateLettersForDriveType: (NSPopUpButton *)sender
{
	[self syncMountOptionsForPanel: (NSOpenPanel *)[sender window]];
}

- (void) panel: (NSOpenPanel *)openPanel directoryDidChange: (NSString *)path
{
	[self syncMountOptionsForPanel: openPanel];
}

- (void) panelSelectionDidChange: (id)sender
{
	[self syncMountOptionsForPanel: sender];
}

- (BOOL) panel: (NSOpenPanel *)openPanel shouldShowFilename: (NSString *)path
{
	NSFileManager *manager = [NSFileManager defaultManager];
	
	if (![BXEmulator pathIsSafeToMount: path]) return NO;
	if (![manager isReadableFileAtPath: path]) return NO;
	
	return YES;
}

- (void) mountChosenItem: (NSOpenPanel *)openPanel
			  returnCode: (int)returnCode
			 contextInfo: (void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
        BXSession *session = [self representedObject];
        
		NSString *path = [[openPanel URL] path];
		
		BXDriveType preferredType	= [[driveType selectedItem] tag];
		NSString *preferredLetter	= [[driveLetter selectedItem] representedObject];
		BOOL readOnly				= [readOnlyToggle state];
		
		BXDrive *drive = [BXDrive driveFromPath: path atLetter: preferredLetter withType: preferredType];
		[drive setReadOnly: readOnly];
        
        NSError *mountError = nil;
		drive = [session mountDrive: drive
                            options: BXDefaultDriveMountOptions
                              error: &mountError];
		
		//Switch to the new mount after adding it
		if (drive)
        {
            [session openFileAtPath: [drive path]];
        }
        //Display the error to the user as a sheet in the same window we are on
        else if (mountError)
        {
            NSWindow *window = [openPanel parentWindow];
            [openPanel close];
            [session presentError: mountError
                   modalForWindow: window
                         delegate: nil
               didPresentSelector: NULL
                      contextInfo: nil];
        }
	}
	[self setRepresentedObject: nil];
}

@end

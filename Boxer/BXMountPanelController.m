/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXMountPanelController.h"
#import "BXSession+BXFileManagement.h"
#import "BXFileTypes.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulatorErrors.h"
#import "BXEmulator+BXShell.h"
#import "NSWorkspace+BXFileTypes.h"
#import "BXDrive.h"
#import "BXGamebox.h"


@implementation BXMountPanelController
@synthesize driveType = _driveType;
@synthesize driveLetter = _driveLetter;
@synthesize readOnlyToggle = _readOnlyToggle;

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
		_previousReadOnlyState = NSMixedState;
	}
	return self;
}

- (void) showMountPanelForSession: (BXSession *)theSession
{
	self.representedObject = theSession;
	
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	
    openPanel.delegate = self;
    openPanel.canChooseFiles = YES;
    openPanel.canChooseDirectories = YES;
    openPanel.treatsFilePackagesAsDirectories = YES;
    
    openPanel.message = NSLocalizedString(@"Choose a folder, CD-ROM or disc image to add as a DOS drive.",
                                          @"Help text shown at the top of mount-a-new-drive panel.");
	openPanel.prompt = NSLocalizedString(@"Add drive",
                                         @"Label shown on accept button in mount-a-new-drive panel.");
	
    openPanel.accessoryView = self.view;
    openPanel.allowedFileTypes = [BXFileTypes mountableTypes].allObjects;
    openPanel.directoryURL = theSession.gamebox.resourceURL;
	
	[self populateDrivesFromSession: theSession];
    
    [openPanel beginSheetModalForWindow: theSession.windowForSheet
                      completionHandler: ^(NSInteger result) {
                          if (result == NSFileHandlingPanelOKButton)
                          {
                              NSError *mountError = nil;
                              BOOL succeeded = [self mountChosenURL: openPanel.URL error: &mountError];
                              if (!succeeded && mountError)
                              {
                                  //Close the open panel so that it won't interfere with error messages.
                                  [openPanel orderOut: self];
                                  
                                  //Display the error to the user as a sheet in the same window
                                  //as we displayed the panel
                                  [theSession presentError: mountError
                                            modalForWindow: theSession.windowForSheet
                                                  delegate: nil
                                        didPresentSelector: NULL
                                               contextInfo: NULL];
                              }
                          }
                          self.representedObject = nil;
                      }];	
}

- (BOOL) mountChosenURL: (NSURL *)URL error: (NSError **)outError
{
    BXSession *session = self.representedObject;
    NSString *path = URL.path;
    
    BXDriveType preferredType	= self.driveType.selectedItem.tag;
    NSString *preferredLetter	= self.driveLetter.selectedItem.representedObject;
    BOOL readOnly				= self.readOnlyToggle.state;
    
    BXDrive *drive = [BXDrive driveFromPath: path atLetter: preferredLetter withType: preferredType];
    drive.readOnly = readOnly;
    
    drive = [session mountDrive: drive
                       ifExists: BXDriveReplace
                        options: BXDefaultDriveMountOptions
                          error: outError];
    
    //Switch to the new mount after adding it
    if (drive)
    {
        [session openFileAtPath: drive.path];
        return YES;
    }
    else
    {
        return NO;
    }
}

//(Re)initialise the possible values for drive letters
- (void) populateDrivesFromSession: (BXSession *)theSession
{	
	BXEmulator *theEmulator = theSession.emulator;
	NSArray *driveLetters	= [BXEmulator driveLetters];
	
	//First, strip any existing options after the first two (which are Auto and a divider)
	while (self.driveLetter.numberOfItems > 2) [self.driveLetter removeItemAtIndex: 2];
	
	//Now, repopulate the menu
	for (NSString *letter in driveLetters)
	{
    	NSMenuItem *option	= [[[NSMenuItem alloc] init] autorelease];
		NSString *title		= [NSString stringWithFormat: @"%@:", letter];
		BXDrive *drive      = [theEmulator driveAtLetter: letter];
		
        //Mark already-occupied drive letters with the title of the drive occupying that letter.
        //Also, disable locked drive letters (and hide hidden drives altogether).
		if (drive)
		{
            //If the drive is hidden or an internal DOSBox drive,
            //skip it altogether and don't show an entry
            if (drive.isHidden || drive.isInternal) continue;
            
            //If the drive is locked, disable the entry - it cannot be replaced
            if (drive.isLocked)
            {
                [option setEnabled: NO];
            }
            
            //Append the drive title to the letter to form the menu item's label
            title = [title stringByAppendingFormat: @" (%@)", drive.title, nil];
		}
		
		option.title = title;
		option.representedObject = letter;
		
		[self.driveLetter.menu addItem: option];
	}
	
	[self.driveLetter selectItemAtIndex: 0];
}

//Toggle the mount panel options depending on the selected file
- (void) syncMountOptionsForPanel: (NSOpenPanel *)openPanel
{
    BXSession *session = self.representedObject;
	NSString *path = openPanel.URL.path;
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	if (path)
	{
		//Don't allow drive type to be configured for disc images: instead,
        //force it to CD-ROM/floppy while an appropriate image is selected
		BOOL isImage = [workspace file: path matchesTypes: [BXFileTypes mountableImageTypes]];
		if (isImage)
		{
			[self.driveType setEnabled: NO];
			//Back up the current selection and then override it
			if (!_previousDriveTypeSelection)
			{
				_previousDriveTypeSelection = self.driveType.selectedItem;
			}
			
			BOOL isFloppyImage = [workspace file: path matchesTypes: [BXFileTypes floppyVolumeTypes]];
			NSUInteger optionIndex = [self.driveType indexOfItemWithTag: isFloppyImage ? BXDriveFloppyDisk : BXDriveCDROM];
			[self.driveType selectItemAtIndex: optionIndex];
		}
		else
		{
			[self.driveType setEnabled: YES];
        	//Restore the previously selected type
			if (_previousDriveTypeSelection)
			{
				[self.driveType selectItem: _previousDriveTypeSelection];
				_previousDriveTypeSelection = nil;
			}
		}		
		
		
		//Now determine what the automatic options will do for the selected path
		BXDriveType selectedType	= self.driveType.selectedItem.tag;
		BXDriveType preferredType	= [BXDrive preferredTypeForPath: path];

		BXDrive *fakeDrive			= [BXDrive driveFromPath: path atLetter: nil withType: selectedType];
		NSString *preferredLetter	= [session preferredLetterForDrive: fakeDrive options: BXDriveKeepWithSameType];
		
		NSMenuItem *autoTypeOption		= [self.driveType itemAtIndex: 0];
		NSMenuItem *preferredTypeOption	= [self.driveType itemAtIndex: [self.driveType indexOfItemWithTag: preferredType]];
		
		NSMenuItem *autoLetterOption		= [self.driveLetter itemAtIndex: 0];
		NSMenuItem *preferredLetterOption	= [self.driveLetter itemAtIndex: [self.driveLetter indexOfItemWithRepresentedObject: preferredLetter]];
		

		NSString *autoLabel = NSLocalizedString(
			@"Auto (%@)",
			@"Title format for automatic drive type/letter option. Shown in popup buttons on mount-a-new-drive sheet. %@ is the title of the real option whose value will be used if auto is chosen."
												);		
		autoTypeOption.title    = [NSString stringWithFormat: autoLabel, preferredTypeOption.title];
		autoLetterOption.title  = [NSString stringWithFormat: autoLabel, preferredLetterOption.title];

		[self.driveLetter setEnabled: YES];

		
		//Override the read-only option when the drive type is CD-ROM or Auto (CD-ROM),
		//or when the selected path is not writable
		if ((selectedType == BXDriveCDROM) || 
			(selectedType == BXDriveAutodetect && preferredType == BXDriveCDROM) ||
			(![[NSFileManager defaultManager] isWritableFileAtPath: path]))
		{
			[self.readOnlyToggle setEnabled: NO];
			//Back up the previous state and override it
			if (_previousReadOnlyState == NSMixedState)
			{
				_previousReadOnlyState = self.readOnlyToggle.state;
				self.readOnlyToggle.state = NSOnState;
			}
		}
		else
		{
			[self.readOnlyToggle setEnabled: YES];
        	//Restore the previous state
			if (_previousReadOnlyState != NSMixedState)
			{
				self.readOnlyToggle.state = NSOffState;
            	_previousReadOnlyState = NSMixedState;
			}
		}
	}
	else
	{
        self.driveType.enabled = NO;
        self.driveLetter.enabled = NO;
        self.readOnlyToggle.enabled = NO;
    }
}

//Fired whenever the drive type selection is changed: updates the drive letter to match the appropriate selected type
- (IBAction) updateLettersForDriveType: (NSPopUpButton *)sender
{
	[self syncMountOptionsForPanel: (NSOpenPanel *)sender.window];
}

- (void) panel: (id)sender didChangeToDirectoryURL: (NSURL *)url
{
	[self syncMountOptionsForPanel: sender];
}

- (void) panelSelectionDidChange: (id)sender
{
	[self syncMountOptionsForPanel: sender];
}

- (BOOL) panel: (id)sender shouldEnableURL: (NSURL *)URL
{
    NSString *path = URL.path;

	return [self.representedObject validateDrivePath: &path error: nil];
}

@end

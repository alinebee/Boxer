/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXMountPanelController.h"
#import "BXSession+BXFileManager.h"
#import "BXAppController.h"
#import "BXEmulator+BXDOSFileSystem.h"
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

	[openPanel	beginSheetForDirectory: nil
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
	
	NSFileManager *manager	= [NSFileManager defaultManager];
	NSArray *driveLetters	= [BXEmulator driveLetters];
	
	//The maximum number of components to show in file paths
	NSUInteger maxComponents=2;
	
	//First, strip any existing options after the first two (which are Auto and a divider)
	while ([driveLetter numberOfItems] > 2) [driveLetter removeItemAtIndex: 2];
	
	
	//Now, repopulate the menu again
	
	for (NSString *letter in driveLetters)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		NSMenuItem *option	= [[NSMenuItem new] autorelease];
		NSString *title		= [NSString stringWithFormat: @"%@:", letter];
		BXDrive *drive		= [theEmulator driveAtLetter: letter];
		
		//The drive letter is already taken - mark it as unselectable and list a human-readable path
		if (drive)
		{
			[option setEnabled: NO];
			if (![drive isInternal])
			{
				NSArray *displayComponents	= [manager componentsToDisplayForPath: [drive path]];
				NSUInteger numComponents	= [displayComponents count];
				
				if (numComponents > maxComponents)
					displayComponents = [displayComponents subarrayWithRange: NSMakeRange(numComponents - maxComponents, maxComponents)];

				NSString *displayPath = [displayComponents componentsJoinedByString: @" ▸ "];
				
				title = [title stringByAppendingFormat: @"  %@", displayPath, nil];
			}
		}
		
		[option setTitle: title];
		[option setRepresentedObject: letter];
		
		[[driveLetter menu] addItem: option];
		
		[pool release];
	}
	
	[driveLetter selectItemAtIndex: 0];
}

//Toggle the mount panel options depending on the selected file
- (void) syncMountOptionsForPanel: (NSOpenPanel *)openPanel
{
	BXEmulator *theEmulator = [[self representedObject] emulator];
	NSString *path = [[openPanel URL] path];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	if (path)
	{
		//Don't allow drive type to be configured for disc images: instead, force it to CD-ROM while an image is selected
		BOOL isImage = [workspace file: path matchesTypes: [BXAppController mountableImageTypes]];
		if (isImage)
		{
			[driveType setEnabled: NO];
			//Back up the current selection and then override it
			if (!previousDriveTypeSelection)
			{
				previousDriveTypeSelection = [driveType selectedItem];
				BOOL isFloppyImage = [workspace file: path matchesTypes: [BXAppController floppyVolumeTypes]];
				NSUInteger optionIndex = [driveType indexOfItemWithTag: isFloppyImage ? BXDriveFloppyDisk : BXDriveCDROM];
				[driveType selectItemAtIndex: optionIndex];
			}
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
		NSString *preferredLetter	= [theEmulator preferredLetterForDrive: fakeDrive];
		
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

- (void) panel: (NSOpenPanel *)openPanel directoryDidChange:(NSString *)path
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
		NSString *path = [[openPanel URL] path];
		
		BXDriveType preferredType	= [[driveType selectedItem] tag];
		NSString *preferredLetter	= [[driveLetter selectedItem] representedObject];
		BOOL readOnly				= [readOnlyToggle state];
		
		BXDrive *drive = [BXDrive driveFromPath: path atLetter: preferredLetter withType: preferredType];
		[drive setReadOnly: readOnly];
		drive = [[self representedObject] mountDrive: drive];
		
		//If we're not in the middle of something, switch to the new mount
		if (drive != nil) [[self representedObject] openFileAtPath: [drive path]];
	}
	[self setRepresentedObject: nil];
}

@end

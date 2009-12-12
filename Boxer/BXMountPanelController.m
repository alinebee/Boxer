/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXMountPanelController.h"
#import "BXSession.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "NSWorkspace+BXFileTypes.h"
#import "BXDrive.h"


@implementation BXMountPanelController
@synthesize driveType, driveLetter;

+ (BXMountPanelController *) controller
{
	static BXMountPanelController *singleton = nil;
	if (!singleton) singleton = [[self alloc] initWithNibName: @"MountPanelOptions" bundle: nil];
	return singleton;
}

- (void) showMountPanelForSession: (BXSession *)theSession
{
	[self setRepresentedObject: theSession];
	
	NSOpenPanel *openPanel	= [NSOpenPanel openPanel];
	
	[openPanel setCanChooseFiles: YES];
	[openPanel setCanChooseDirectories: YES];
	[openPanel setTreatsFilePackagesAsDirectories: YES];
	[openPanel setMessage:	NSLocalizedString(@"Choose a folder, CD-ROM or disc image to mount as a new DOS drive.", @"Help text shown at the top of mount-a-new-drive panel.")];
	[openPanel setPrompt:	NSLocalizedString(@"Add drive", @"Label shown on accept button in mount-a-new-drive panel.")];
	
	[openPanel setAccessoryView: [self view]];
	[openPanel setDelegate: self];
	
	[self populateDrivesFromSession: theSession];

	[openPanel	beginSheetForDirectory: nil
				file: nil
				types: [BXEmulator mountableTypes]
				modalForWindow: [theSession windowForSheet]
				modalDelegate: self
				didEndSelector: @selector(mountChosenFolder:returnCode:contextInfo:)
				contextInfo: nil];	
}

//(Re)initialise the possible values for drive letters
- (void) populateDrivesFromSession: (BXSession *)theSession
{	
	BXEmulator *theEmulator = [theSession emulator];
	
	NSFileManager *manager	= [NSFileManager defaultManager];
	NSArray *driveLetters	= [BXEmulator driveLetters];
	
	//The maximum number of components to show in file paths
	NSUInteger numComponents, maxComponents=2;
	
	//First, strip any existing options after the first two (which are Auto and a divider)
	while ([driveLetter numberOfItems] > 2) [driveLetter removeItemAtIndex: 2];
	
	
	//Now, repopulate the menu again
	NSMenuItem *option;
	NSString *title, *displayPath;
	BXDrive *drive;
	NSArray *displayComponents;
	
	for (NSString *letter in driveLetters)
	{
		option	= [[NSMenuItem new] autorelease];
		title	= [NSString stringWithFormat: @"%@:", letter];
		drive	= [theEmulator driveAtLetter: letter];
		
		//The drive letter is already taken - mark it as unselectable and list a human-readable path
		if (drive)
		{
			[option setEnabled: NO];
			if (![drive isInternal])
			{
				displayComponents	= [manager componentsToDisplayForPath: [drive path]];
				numComponents		= [displayComponents count];
				
				if (numComponents > maxComponents)
					displayComponents = [displayComponents subarrayWithRange: NSMakeRange(numComponents - maxComponents, maxComponents)];

				displayPath	= [displayComponents componentsJoinedByString: @" ▸ "];
				title		= [title stringByAppendingFormat: @"  %@", displayPath, nil];
			}
		}
		
		[option setTitle: title];
		[option setRepresentedObject: letter];
		
		[[driveLetter menu] addItem: option];
	}
	[driveLetter selectItemAtIndex: 0];
}

//Toggle the mount panel options depending on the selected file
- (void) syncMountOptionsForPanel: (NSOpenPanel *)openPanel
{
	BXEmulator *theEmulator = [[self representedObject] emulator];
	NSString *path = [[openPanel URL] path];
	
	if (path)
	{	
		NSString *autoLabel = NSLocalizedString(
			@"Auto (%@)",
			@"Title format for automatic drive type/letter option. Shown in popup buttons on mount-a-new-drive sheet. %@ is the title of the real option whose value will be used if auto is chosen."
		);
		
		BXDriveType selectedType	= [[driveType selectedItem] tag];
		BXDrive *fakeDrive			= [BXDrive driveFromPath: path atLetter: nil withType: selectedType];

		NSString *preferredLetter		= [theEmulator preferredLetterForDrive: fakeDrive];
		BXDriveType preferredType		= [fakeDrive type];
		
		NSMenuItem *autoTypeOption		= [driveType itemAtIndex: 0];
		NSMenuItem *preferredTypeOption	= [driveType itemAtIndex: [driveType indexOfItemWithTag: preferredType]];
		
		NSMenuItem *autoLetterOption		= [driveLetter itemAtIndex: 0];
		NSMenuItem *preferredLetterOption	= [driveLetter itemAtIndex: [driveLetter indexOfItemWithRepresentedObject: preferredLetter]];
		
		[autoTypeOption setTitle:	[NSString stringWithFormat: autoLabel, [preferredTypeOption title], nil]];
		[autoLetterOption setTitle:	[NSString stringWithFormat: autoLabel, [preferredLetterOption title], nil]];

		//Don't allow type to be configured for disc images
		BOOL isImage = [[NSWorkspace sharedWorkspace] file: path matchesTypes: [BXEmulator mountableImageTypes]]; 
		[driveType setEnabled: !isImage];
		[driveLetter setEnabled: YES];
	}
	else
	{
		[driveType setEnabled: NO];
		[driveLetter setEnabled: NO];
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

- (void) panelSelectionDidChange: (NSOpenPanel *)openPanel
{
	[self syncMountOptionsForPanel: openPanel];
}

- (BOOL) panel: (NSOpenPanel *)openPanel shouldShowFilename: (NSString *)path
{
	NSFileManager *manager = [NSFileManager defaultManager];
	
	if (![BXEmulator pathIsSafeToMount: path]) return NO;
	if (![manager isReadableFileAtPath: path]) return NO;
	
	return YES;
}

- (void) mountChosenFolder: (NSOpenPanel *)openPanel returnCode: (int)returnCode contextInfo: (void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		BXEmulator *theEmulator = [[self representedObject] emulator];
		NSString *path = [[openPanel URL] path];
		
		BXDriveType preferredType	= [[driveType selectedItem] tag];
		NSString *preferredLetter		= [[driveLetter selectedItem] representedObject];
		
		BXDrive *drive = [BXDrive driveFromPath: path atLetter: preferredLetter withType: preferredType];
		//[theEmulator openQueue];
		drive = [theEmulator mountDrive: drive];
		
		//If we're not in the middle of something, change to the new mount
		if (drive != nil && ![theEmulator isRunningProcess]) [theEmulator changeToDriveLetter: [drive letter]];
		//[theEmulator closeQueue];
	}
	[self setRepresentedObject: nil];
}

@end

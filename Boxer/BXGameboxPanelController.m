/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXGameboxPanelController.h"
#import "BXValueTransformers.h"
#import "BXSession+BXFileManager.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "BXAppController.h"
#import "BXPackage.h"
#import "NSString+BXPaths.h"


//Used by syncMenuItems to determine where to fill the program menu with program items
enum {
	BXGameboxPanelNoProgramTag = 1,
	BXGameboxPanelEndOfProgramsTag = 2
};


#pragma mark -
#pragma mark Private method declarations
@interface BXGameboxPanelController ()

//Returns a sorted array of NSMenuItems for the available programs on each drive.
//Used internally by syncMenuItems.
- (NSArray *) _programMenuItems;

//Returns a newly-minted menu item for the specified path. Used internally by _programMenuItems.
- (NSMenuItem *) _programMenuItemForPath: (NSString *)path onDrive: (BXDrive *)drive;

//Handles the result of the choose-a-target panel.
- (void) _setChosenProgramAsDefault: (NSOpenPanel *)openPanel
						 returnCode: (int)returnCode
						contextInfo: (void *)contextInfo;

@end


#pragma mark -
#pragma mark Implementation

@implementation BXGameboxPanelController
@synthesize programSelector, sessionMediator;

- (BXSession *) session
{
	return [[self sessionMediator] content];
}

- (void) dealloc
{
	[self setSessionMediator: nil]; [sessionMediator release];
	[self setProgramSelector: nil]; [programSelector release];
	[super dealloc];
}

- (void) setSessionMediator: (NSObjectController *)mediator
{
	if (mediator != sessionMediator)
	{
		NSArray *observePaths = [NSArray arrayWithObjects:
			@"content.executables",
			@"content.gamePackage.targetPath",
		nil];
		
		for (NSString *path in observePaths)
			[sessionMediator removeObserver: self forKeyPath: path];
	
		[sessionMediator release];
		sessionMediator = [mediator retain];
	
		for (NSString *path in observePaths)
			[mediator addObserver: self forKeyPath: path options: NSKeyValueObservingOptionInitial context: nil];
	}	
}

//Whenever the session's executables or targets change, repopulate our selector with the new values
- (void)observeValueForKeyPath: (NSString *)keyPath
					  ofObject: (id)object
						change: (NSDictionary *)change
					   context: (void *)context
{
	//TODO: there is no real need to synchronize the entire menu structure whenever these change;
	//instead, we could optimize and only synchronize when the menu is displayed.
	//This could lead the popup button title to become out of date, but in that case syncSelection
	//could create a 'dummy' item just for the target path.
	if		([keyPath isEqualToString: @"content.executables"])				[self syncMenuItems];
	else if ([keyPath isEqualToString: @"content.gamePackage.targetPath"])	[self syncSelection];
}


#pragma mark -
#pragma mark UI actions

- (BOOL) validateUserInterfaceItem: (id)theItem
{
	if ([theItem action] == @selector(launchDefaultProgram:))
	{
		BXEmulator *emulator = [[self session] emulator];
		NSString *filePath = [[[self programSelector] selectedItem] representedObject];
		return filePath && [emulator isExecuting] && ![emulator isRunningProcess];
	}
	return YES;
}

- (IBAction) changeDefaultProgram: (id)sender
{
	NSString *selectedPath = [[sender selectedItem] representedObject];
	[[[self session] gamePackage] setTargetPath: selectedPath];
}

- (IBAction) launchDefaultProgram: (id)sender
{
	NSString *filePath = [[[self programSelector] selectedItem] representedObject];
	[[self session] openFileAtPath: filePath];
}

- (IBAction) revealGamebox: (id)sender
{
	[[NSApp delegate] revealPath: [[[self session] gamePackage] bundlePath]];
}

- (IBAction) searchForCoverArt: (id)sender
{
	NSString *search = [[self session] displayName];
	[[NSApp delegate] searchURLFromKey: @"CoverArtSearchURL" withSearchString: search];
}

- (IBAction) showProgramChooserPanel: (id)sender
{	
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	
	[openPanel setCanChooseFiles: YES];
	[openPanel setCanChooseDirectories: NO];
	[openPanel setTreatsFilePackagesAsDirectories: NO];
	[openPanel setMessage:	NSLocalizedString(@"Choose the target program for this gamebox:",
											  @"Help text shown at the top of choose-a-target-program panel.")];
	
	[openPanel setDelegate: self];
	[openPanel beginSheetForDirectory: [[[self session] gamePackage] gamePath]
								 file: nil
								types: [[BXAppController executableTypes] allObjects]
					   modalForWindow: [[self view] window]
						modalDelegate: self
					   didEndSelector: @selector(_setChosenProgramAsDefault:returnCode:contextInfo:)
						  contextInfo: NULL];
}

- (BOOL) panel: (id)sender shouldShowFilename: (NSString *)filename
{
	BXSession *session = [self session];
    
	//Disable files that are outside the gamebox or that aren't accessible in DOS
	if (![filename isRootedInPath: [[session gamePackage] gamePath]]) return NO;
    
    //Note: we could test if the file actually exists in DOS, but that's kinda expensive.
	if (![[session emulator] pathIsDOSAccessible: filename]) return NO;
	return YES;
}


#pragma mark -
#pragma mark Program menu syncing

- (void) syncMenuItems
{
	NSMenu *menu = [[self programSelector] menu];
	
	NSInteger startOfPrograms	= [menu indexOfItemWithTag: BXGameboxPanelNoProgramTag] + 1;
	NSInteger endOfPrograms		= [menu indexOfItemWithTag: BXGameboxPanelEndOfProgramsTag];
	NSRange programItemRange	= NSMakeRange(startOfPrograms, endOfPrograms - startOfPrograms);
	
	//Remove all the original program options...
	for (NSMenuItem *oldItem in [[menu itemArray] subarrayWithRange: programItemRange])
		[menu removeItem: oldItem];
	
	//...and then add all the new ones in their place
	NSArray *newItems = [self _programMenuItems];
	
	if ([newItems count])
	{
		NSUInteger insertionPoint = startOfPrograms;
		
		for (NSMenuItem *newItem in newItems)
		{
			[menu insertItem: newItem atIndex: insertionPoint++];
		}
	}
	
	[self syncSelection];
}

- (void) syncSelection
{
	NSMenu *menu = [[self programSelector] menu];
	NSString *targetPath = [[[self session] gamePackage] targetPath];
	NSUInteger pathIndex = (targetPath == nil) ? 0 : [menu indexOfItemWithRepresentedObject: targetPath];
	[programSelector selectItemAtIndex: pathIndex];
}


#pragma mark -
#pragma mark Private methods

- (NSArray *) _programMenuItems
{	
	NSDictionary *allPrograms	= [[self session] executables];
	NSMutableArray *items		= [NSMutableArray arrayWithCapacity: [allPrograms count]];
	
	NSArray *driveLetters = [[allPrograms allKeys] sortedArrayUsingSelector: @selector(compare:)];
	
	if ([driveLetters count])
	{
		BXEmulator *emulator = [[self session] emulator];
		for (NSString *driveLetter in driveLetters)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			BXDrive *drive = [emulator driveAtLetter: driveLetter];
			
			//Skip drives that aren't located inside the gamebox
			if (![[self session] driveIsBundled: drive]) continue;
			
			NSArray *programsInDrive = [allPrograms objectForKey: driveLetter];
			
			//Skip drives with no executables on them
			if (![programsInDrive count]) continue;
			
			//Sort the executables in order of path depth, so we can prioritise programs 'higher up' in the file heirarchy
			NSArray *sortedPrograms = [programsInDrive sortedArrayUsingSelector: @selector(pathDepthCompare:)];
			
			
			for (NSString *path in sortedPrograms)
			{
				NSMenuItem *item = [self _programMenuItemForPath: path onDrive: drive];
				[items addObject: item];
			}
			
			//Add a separator after each new drive
			[items addObject: [NSMenuItem separatorItem]];
			
			[pool release];
		}
	}
	
	return items;
}

- (void) _setChosenProgramAsDefault: (NSOpenPanel *)openPanel
						 returnCode: (int)returnCode
						contextInfo: (void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		NSString *path = [[openPanel URL] path];
		
		//Look for an existing program item with that path
		NSInteger itemIndex = [[self programSelector] indexOfItemWithRepresentedObject: path];
		if (itemIndex == -1)
		{
			//This program is not yet in the menu: add a new item for it and use its new index
			NSMenu *menu = [[self programSelector] menu];
			NSMenuItem *item = [self _programMenuItemForPath: path onDrive: nil];
			
			itemIndex = [menu indexOfItemWithTag: BXGameboxPanelEndOfProgramsTag];
			[menu insertItem: item atIndex: itemIndex];
		}
		
		[[self programSelector] selectItemAtIndex: itemIndex];
		[self changeDefaultProgram: [self programSelector]];
	}
	else if (returnCode == NSCancelButton)
	{
		//If the user cancelled, revert the menu item selection back to the default program
		[self syncSelection];
	}
}


- (NSMenuItem *) _programMenuItemForPath: (NSString *)path onDrive: (BXDrive *)drive
{
	BXDisplayPathTransformer *pathFormat = [[BXDisplayPathTransformer alloc] initWithJoiner: @" ▸ " maxComponents: 0];
	[pathFormat setUseFilesystemDisplayPath: NO];
	
	BXEmulator *emulator = [[self session] emulator];
	
	NSMenuItem *item = [[NSMenuItem alloc] init];
	
	//Use the DOS path of the executable to display it
	NSString *displayPath = nil;
	//If we know the drive already, we can look up the path directly; otherwise, get the emulator to determine the drive
	if (drive) displayPath	= [emulator DOSPathForPath: path onDrive: drive];
	else		displayPath = [emulator DOSPathForPath: path];
	
	//If the file is not accessible in DOS, use the file's OSX filesystem path
	//(This should never happen - we don't list programs that aren't on mounted drives - but just in case)
	if (!displayPath) displayPath = path; 
	
	[item setRepresentedObject: path];
	[item setTitle: [pathFormat transformedValue: displayPath]];
	
	[pathFormat release];
	
	return [item autorelease];
}

@end

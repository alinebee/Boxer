/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXGameboxPanelController.h"
#import "BXValueTransformers.h"
#import "BXSession+BXFileManagement.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "BXFileTypes.h"
#import "BXBaseAppController.h"
#import "BXGamebox.h"
#import "NSURL+ADBFilesystemHelpers.h"
#import "NSString+ADBPaths.h"


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

@end


#pragma mark -
#pragma mark Implementation

@implementation BXGameboxPanelController
@synthesize programSelector = _programSelector;
@synthesize sessionMediator = _sessionMediator;

- (BXSession *) session
{
	return self.sessionMediator.content;
}

- (void) dealloc
{
    self.sessionMediator = nil;
    self.programSelector = nil;
	[super dealloc];
}

- (void) setSessionMediator: (NSObjectController *)mediator
{
	if (mediator != self.sessionMediator)
	{
		NSArray *observePaths = [NSArray arrayWithObjects:
			@"content.executables",
			@"content.gamebox.targetPath",
		nil];
		
		for (NSString *path in observePaths)
			[_sessionMediator removeObserver: self forKeyPath: path];
	
		[_sessionMediator release];
		_sessionMediator = [mediator retain];
	
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
	if		([keyPath isEqualToString: @"content.executables"])			[self syncMenuItems];
	else if ([keyPath isEqualToString: @"content.gamebox.targetPath"])	[self syncSelection];
}


#pragma mark -
#pragma mark UI actions

- (BOOL) validateUserInterfaceItem: (id <NSValidatedUserInterfaceItem>)theItem
{
	if (theItem.action == @selector(launchDefaultProgram:))
	{
		NSString *filePath = self.programSelector.selectedItem.representedObject;
		return filePath != nil && self.session.canOpenURLs;
	}
	return YES;
}

- (IBAction) changeDefaultProgram: (NSPopUpButton *)sender
{
	NSString *selectedPath = sender.selectedItem.representedObject;
    self.session.gamebox.targetPath = selectedPath;
}

- (IBAction) launchDefaultProgram: (id)sender
{
	NSString *filePath = self.programSelector.selectedItem.representedObject;
    if (filePath)
        [self.session openURLInDOS: [NSURL fileURLWithPath: filePath] error: NULL];
}

- (IBAction) revealGamebox: (id)sender
{
	[[NSApp delegate] revealPath: self.session.gamebox.bundlePath];
}

- (IBAction) searchForCoverArt: (id)sender
{
	NSString *search = self.session.displayName;
	[[NSApp delegate] searchURLFromKey: @"CoverArtSearchURL" withSearchString: search];
}

- (IBAction) showProgramChooserPanel: (id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	
    openPanel.delegate = self;
    openPanel.canChooseFiles = YES;
    openPanel.canChooseDirectories = NO;
    openPanel.treatsFilePackagesAsDirectories = YES;
    openPanel.allowedFileTypes = [BXFileTypes executableTypes].allObjects;
    
    openPanel.message = NSLocalizedString(@"Choose the target program for this gamebox:",
                                          @"Help text shown at the top of choose-a-target-program panel.");
	
    
    //Start the panel with the current target selected.
    //If we don't have one, then start it up in the folder of the main drive (usually drive C.)
    //If we don't have one of *those*, then start it up in the root folder of the gamebox.
    NSString *currentTargetPath = self.session.gamebox.targetPath;
    
    NSURL *initialLocation;
    if (currentTargetPath)
        initialLocation = [NSURL fileURLWithPath: currentTargetPath];
    else if (self.session.principalDrive)
        initialLocation = self.session.principalDrive.mountPointURL;
    else
        initialLocation = self.session.gamebox.resourceURL;
    
    openPanel.directoryURL = initialLocation;
    
    [openPanel beginSheetModalForWindow: self.view.window
                      completionHandler: ^(NSInteger result) {
                          if (result == NSFileHandlingPanelOKButton)
                          {
                              [self chooseDefaultProgramWithURL: openPanel.URL];
                          }
                          else if (result == NSFileHandlingPanelCancelButton)
                          {
                              //If the user cancelled, revert the menu item selection back to the default program
                              [self syncSelection];
                          }
                      }];
}

- (void) chooseDefaultProgramWithURL: (NSURL *)URL
{
    NSString *path = URL.path;
    
    //Look for an existing menu item with that path
    NSInteger itemIndex = [self.programSelector indexOfItemWithRepresentedObject: path];
    if (itemIndex == -1)
    {
        //This program is not yet in the menu: add a new item for it and use its new index
        NSMenu *menu = self.programSelector.menu;
        NSMenuItem *item = [self _programMenuItemForPath: path onDrive: nil];
        
        itemIndex = [menu indexOfItemWithTag: BXGameboxPanelEndOfProgramsTag];
        [menu insertItem: item atIndex: itemIndex];
    }
    
    [self.programSelector selectItemAtIndex: itemIndex];
    [self changeDefaultProgram: self.programSelector];
}

- (BOOL) panel: (id)sender shouldEnableURL: (NSURL *)URL
{
	BXSession *session = self.session;
    
	//Disable files that are outside the gamebox or that aren't accessible in DOS.
	if (![URL isBasedInURL: session.gamebox.resourceURL]) return NO;
    
	if (![session.emulator URLIsAccessibleInDOS: URL]) return NO;
    
	return YES;
}


#pragma mark -
#pragma mark Program menu syncing

- (void) syncMenuItems
{
	NSMenu *menu = self.programSelector.menu;
	
    NSInteger startMarkerIndex  = [menu indexOfItemWithTag: BXGameboxPanelNoProgramTag];
    NSInteger endMarkerIndex    = [menu indexOfItemWithTag: BXGameboxPanelEndOfProgramsTag];
    
    NSInteger insertionPoint = startMarkerIndex + 1;
    NSInteger removalPoint = endMarkerIndex - 1;
    
	//Remove all the original program options...
    while (removalPoint >= insertionPoint)
        [menu removeItemAtIndex: removalPoint--];
	
	//...and then add all the new ones in their place
	NSArray *newItems = [self _programMenuItems];
	
	if (newItems.count)
	{
		for (NSMenuItem *newItem in newItems)
		{
			[menu insertItem: newItem atIndex: insertionPoint++];
		}
	}
	
	[self syncSelection];
}

- (void) syncSelection
{
	NSMenu *menu = self.programSelector.menu;
	NSString *targetPath = self.session.gamebox.targetPath;
	NSInteger pathIndex = (targetPath != nil) ? [menu indexOfItemWithRepresentedObject: targetPath] : 0;
    
    if (pathIndex != -1)
        [self.programSelector selectItemAtIndex: pathIndex];
}


#pragma mark -
#pragma mark Private methods

- (NSArray *) _programMenuItems
{	
	NSDictionary *allPrograms	= [self.session.executableURLs valueForKey: @"path"];
    NSString *currentTarget     = self.session.gamebox.targetPath;
	NSMutableArray *items		= [NSMutableArray arrayWithCapacity: allPrograms.count];
	
	NSArray *driveLetters = [allPrograms.allKeys sortedArrayUsingSelector: @selector(compare:)];
	
    BOOL hasItemForTarget = NO;
	if (driveLetters.count)
	{
		BXEmulator *emulator = self.session.emulator;
		for (NSString *driveLetter in driveLetters)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			BXDrive *drive = [emulator driveAtLetter: driveLetter];
			
			//Skip drives that aren't located inside the gamebox
			if ([self.session driveIsBundled: drive])
            {
                NSArray *programsInDrive = [allPrograms objectForKey: driveLetter];
                
                //Skip drives with no executables on them
                if (programsInDrive.count)
                {
                    //Sort the executables in order of path depth, so we can prioritise programs 'higher up' in the file hierarchy
                    NSArray *sortedPrograms = [programsInDrive sortedArrayUsingSelector: @selector(pathDepthCompare:)];
                    
                    for (NSString *path in sortedPrograms)
                    {
                        NSMenuItem *item = [self _programMenuItemForPath: path onDrive: drive];
                        [items addObject: item];
                        
                        if (!hasItemForTarget && [path isEqualToString: currentTarget])
                            hasItemForTarget = YES;
                    }
                    
                    //Add a separator after each new drive
                    [items addObject: [NSMenuItem separatorItem]];
                }
            }
			[pool release];
		}
	}
	
	return items;
}

- (NSMenuItem *) _programMenuItemForPath: (NSString *)path onDrive: (BXDrive *)drive
{
	BXDisplayPathTransformer *pathFormat = [[BXDisplayPathTransformer alloc] initWithJoiner: @" ▸ " maxComponents: 0];
    pathFormat.usesFilesystemDisplayPath = NO;
    
	BXEmulator *emulator = self.session.emulator;
	
	NSMenuItem *item = [[NSMenuItem alloc] init];
	
	//Use the DOS path of the executable to display it
	NSString *displayPath = nil;
	//If we know the drive already, we can look up the path directly; otherwise, get the emulator to determine the drive
	if (drive) displayPath	= [emulator DOSPathForPath: path onDrive: drive];
	else		displayPath = [emulator DOSPathForPath: path];
	
	//If the file is not accessible in DOS, use the file's OSX filesystem path
	//(This should never happen - we don't list programs that aren't on mounted drives - but just in case)
	if (!displayPath) displayPath = path; 
	
	item.representedObject = path;
	item.title = [pathFormat transformedValue: displayPath];
	
	[pathFormat release];
	
	return [item autorelease];
}

@end

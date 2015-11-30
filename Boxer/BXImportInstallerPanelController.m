/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImportInstallerPanelController.h"
#import "BXImportWindowController.h"
#import "BXImportSession.h"
#import "BXFileTypes.h"
#import "BXAppController.h"
#import "BXValueTransformers.h"
#import "NSString+ADBPaths.h"
#import "NSURL+ADBFilesystemHelpers.h"


//The tag of the divider at the end of the installer options in the installer selector menu.
#define BXInstallerMenuDividerTag 1


#pragma mark -
#pragma mark Private method declarations

@interface BXImportInstallerPanelController ()

//(Re)populate the installer selector with menu items for each detected installer.
//Called whenever the import process's detected installers change.
- (void) _syncInstallerSelectorItems;

//Returns an installer menu item suitable for the specified path.
//Used by _syncInstallerSelectorItems and _addChosenInstaller:returnCode:contextInfo:
- (NSMenuItem *) _installerSelectorItemForURL: (NSURL *)URL;

@end


@implementation BXImportInstallerPanelController
@synthesize installerSelector = _installerSelector;
@synthesize controller = _controller;

#pragma mark -
#pragma mark Initialization and deallocation

+ (void) initialize
{
    if (self == [BXImportInstallerPanelController class])
    {
        BXDisplayPathTransformer *nameTransformer = [[BXDisplayPathTransformer alloc] initWithJoiner: @" ▸ " maxComponents: 0];
        
        [NSValueTransformer setValueTransformer: nameTransformer forName: @"BXImportInstallerMenuTitle"];
        [nameTransformer release];
    }
}

- (void) awakeFromNib
{
	[self.controller addObserver: self forKeyPath: @"document.installerURLs" options: 0 context: nil];
}

- (void) dealloc
{
	[self.controller removeObserver: self forKeyPath: @"document.installerURLs"];

    self.installerSelector = nil;
	
	[super dealloc];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{
	if ([keyPath isEqualToString: @"document.installerURLs"])
	{
		[self _syncInstallerSelectorItems];
	}
}

- (void) _syncInstallerSelectorItems
{
	NSMenu *menu = self.installerSelector.menu;
    
    NSInteger dividerIndex = [menu indexOfItemWithTag: BXInstallerMenuDividerTag];
    NSAssert(dividerIndex > -1, @"Installer menu divider not found.");
	
	NSInteger insertionPoint = 0;
    NSInteger removalPoint = dividerIndex - 1;
    
	//Remove all the original installer options...
    while (removalPoint >= insertionPoint)
    {
        [menu removeItemAtIndex: removalPoint--];
    }
	
	//...and then add all the new ones in their place
	NSArray *installerURLs = self.controller.document.installerURLs;
	
	if (installerURLs)
	{		
		for (NSURL *installerURL in installerURLs)
		@autoreleasepool {
			NSMenuItem *item = [self _installerSelectorItemForURL: installerURL];
			
            [menu insertItem: item atIndex: insertionPoint++];
		}
		
		//Always select the first installer in the list, as this is the preferred installer
		[self.installerSelector selectItemAtIndex: 0];
	}
	
	//Ensure the popup button is in sync after we've messed around with its menu.
	[self.installerSelector synchronizeTitleAndSelectedItem];
}

- (NSMenuItem *) _installerSelectorItemForURL: (NSURL *)URL
{
	NSURL *baseURL = self.controller.document.sourceURL;
	
	//Remove the base source path to make shorter relative paths for display
	NSString *shortenedPath = URL.path;
	if ([URL isBasedInURL: baseURL])
	{
		shortenedPath = [URL pathRelativeToURL: baseURL];
    }
	
	//Prettify the shortened path by using display names and converting slashes to arrows
	NSValueTransformer *nameTransformer = [NSValueTransformer valueTransformerForName: @"BXImportInstallerMenuTitle"];
	
	NSString *title = [nameTransformer transformedValue: shortenedPath];
	
	NSMenuItem *item = [[NSMenuItem alloc] init];
	item.representedObject = URL;
    item.title = title;
	
	return [item autorelease];
}


#pragma mark -
#pragma mark UI actions

- (BOOL) validateMenuItem: (NSMenuItem *)menuItem
{
    //Disable the "Choose Installer..." menu item if we don't actually have a folder to browse
    //(e.g. if we're importing from a disk image.)
    if (menuItem.action == @selector(showInstallerPicker:))
    {
        return self.canBrowseInstallers;
    }
    else
    {
        return YES;
    }
}

+ (NSSet *) keyPathsForValuesAffectingCanBrowseInstallers
{
    return [NSSet setWithObject: @"controller.document.sourceURL"];
}

- (BOOL) canBrowseInstallers
{
    NSNumber *isDirFlag;
    BOOL checkedDir = [self.controller.document.sourceURL getResourceValue: &isDirFlag forKey: NSURLIsDirectoryKey error: NULL];
    if (checkedDir && isDirFlag.boolValue)
        return YES;
    else
        return NO;
}

- (IBAction) launchSelectedInstaller: (id)sender
{
	NSURL *installerURL = self.installerSelector.selectedItem.representedObject;
	[self.controller.document launchInstallerAtURL: installerURL];
}

- (IBAction) cancelInstallerChoice: (id)sender
{
	[self.controller.document cancelSourceSelection];
}

- (IBAction) skipInstaller: (id)sender
{
	[self.controller.document skipInstaller];
}

- (IBAction) showInstallerPicker: (id)sender
{
	NSOpenPanel *openPanel	= [NSOpenPanel openPanel];
	
    openPanel.delegate = self;
    
    openPanel.canChooseFiles = YES;
    openPanel.allowsMultipleSelection = NO;
    openPanel.canChooseDirectories = NO;
    openPanel.treatsFilePackagesAsDirectories = NO;
    openPanel.message = NSLocalizedString(@"Choose the DOS installer program for this game:",
                                          @"Help text shown at the top of choose-an-installer panel.");
	
    openPanel.allowedFileTypes = [BXFileTypes executableTypes].allObjects;
    openPanel.directoryURL = self.controller.document.sourceURL;
    
    [openPanel beginSheetModalForWindow: self.view.window completionHandler: ^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton)
        {
            [self addInstallerFromURL: openPanel.URL];
        }
        else if (result == NSFileHandlingPanelCancelButton)
        {
            //Revert to the first menu item if the user cancelled,
            //to avoid leaving the option that opened the picker selected.
            [self.installerSelector selectItemAtIndex: 0];
        }
    }];	
}

- (BOOL) panel: (id)sender shouldEnableURL: (NSURL *)URL
{
	//Disable files outside the source URL of the import process, for sanity's sake
	return [URL isBasedInURL: self.controller.document.sourceURL];
}
     
- (void) addInstallerFromURL: (NSURL *)URL
{
    NSInteger itemIndex = [self.installerSelector indexOfItemWithRepresentedObject: URL];
    if (itemIndex != -1)
    {
        //This path already exists in the menu, select it
        [self.installerSelector selectItemAtIndex: itemIndex];
    }
    else
    {
        //This installer is not yet in the menu - add a new entry for it and select it
        NSMenuItem *item = [self _installerSelectorItemForURL: URL];
        [self.installerSelector.menu insertItem: item atIndex: 0];
        [self.installerSelector selectItemAtIndex: 0];
    }
}

- (IBAction) showImportInstallerHelp: (id)sender
{
	[(BXBaseAppController *)[NSApp delegate] showHelpAnchor: @"import-choose-installer"];
}

@end

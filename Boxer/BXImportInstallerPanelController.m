/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImportInstallerPanelController.h"
#import "BXImportWindowController.h"
#import "BXImport.h"
#import "BXAppController.h"
#import "BXValueTransformers.h"
#import "NSString+BXPaths.h"

#pragma mark -
#pragma mark Private method declarations

@interface BXImportInstallerPanelController ()

//(Re)populate the installer selector with menu items for each detected installer.
//Called whenever the import process's detected installers change.
- (void) _syncInstallerSelectorItems;

//Returns an installer menu item suitable for the specified path.
//Used by _syncInstallerSelectorItems and _addChosenInstaller:returnCode:contextInfo:
- (NSMenuItem *) _installerSelectorItemForPath: (NSString *)path;

//Handles the response from the choose-an-installer panel.
//Will add the chosen installer to the list of possible installers and select it.
- (void) _addChosenInstaller: (NSOpenPanel *)openPanel
				  returnCode: (int)returnCode
				 contextInfo: (void *)contextInfo;
@end


@implementation BXImportInstallerPanelController
@synthesize installerSelector, controller;

#pragma mark -
#pragma mark Initialization and deallocation

+ (void) initialize
{
	BXDisplayPathTransformer *nameTransformer = [[BXDisplayPathTransformer alloc] initWithJoiner: @" ▸ " maxComponents: 0];
	
	[NSValueTransformer setValueTransformer: nameTransformer forName: @"BXImportInstallerMenuTitle"];
	[nameTransformer release];
}

- (void) awakeFromNib
{
	[[self controller] addObserver: self forKeyPath: @"document.installerPaths" options: 0 context: nil];
}

- (void) dealloc
{
	[[self controller] removeObserver: self forKeyPath: @"document.installerPaths"];

	[self setInstallerSelector: nil], [installerSelector release];
	
	[super dealloc];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{
	if ([keyPath isEqualToString: @"document.installerPaths"])
	{
		[self _syncInstallerSelectorItems];
	}
}

- (void) _syncInstallerSelectorItems
{
	NSMenu *menu = [[self installerSelector] menu];
	NSRange installerRange = NSMakeRange(0, [menu indexOfItemWithTag: 1]);
	
	//Remove all the original installer options
	for (NSMenuItem *oldItem in [[menu itemArray] subarrayWithRange: installerRange])
		[menu removeItem: oldItem];
	
	
	//...and then add all the new ones in their place
	NSUInteger insertionPoint = 0;
	
	NSArray *installerPaths				= [[[self controller] document] installerPaths];
	NSString *preferredInstallerPath	= [[[self controller] document] preferredInstallerPath];
	
	if (installerPaths)
	{		
		for (NSString *installerPath in installerPaths)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSMenuItem *item = [self _installerSelectorItemForPath: installerPath];
			
			//Bump the preferred installer to the top of the list
			if ([installerPath isEqualToString: preferredInstallerPath])
				[menu insertItem: item atIndex: 0];
			else
				[menu insertItem: item atIndex: insertionPoint];
				  
			
			insertionPoint++;
			
			[pool release];
		}
		
		//Always select the first installer in the list
		[[self installerSelector] selectItemAtIndex: 0];
	}
	
	//Ensure the popup button is in sync after we've messed around with its menu.
	[[self installerSelector] synchronizeTitleAndSelectedItem];
}

- (NSMenuItem *) _installerSelectorItemForPath: (NSString *)path
{
	NSString *basePath = [[[self controller] document] sourcePath];
	NSUInteger baseLength = [basePath length];
	
	//Remove the base source path to make shorter relative paths for display
	NSString *shortenedPath = path;
	if ([path isRootedInPath: basePath])
	{
		shortenedPath = [path substringFromIndex: baseLength + 1];
	}
	
	//Prettify the shortened path by using display names and converting slashes to arrows
	NSValueTransformer *nameTransformer = [NSValueTransformer valueTransformerForName: @"BXImportInstallerMenuTitle"];
	
	NSString *title = [nameTransformer transformedValue: shortenedPath];
	
	NSMenuItem *item = [[NSMenuItem alloc] init];
	[item setRepresentedObject: path];
	[item setTitle: title];
	
	return [item autorelease];
}


#pragma mark -
#pragma mark UI actions

- (IBAction) launchSelectedInstaller: (id)sender
{
	NSString *installerPath = [[[self installerSelector] selectedItem] representedObject];
	[[[self controller] document] launchInstaller: installerPath];
}

- (IBAction) cancelInstallerChoice: (id)sender
{
	[[[self controller] document] cancelSourcePath];
}

- (IBAction) skipInstaller: (id)sender
{
	[[[self controller] document] skipInstaller];
}

- (IBAction) showInstallerPicker: (id)sender
{
	NSOpenPanel *openPanel	= [NSOpenPanel openPanel];
	
	[openPanel setCanChooseFiles: YES];
	[openPanel setCanChooseDirectories: NO];
	[openPanel setTreatsFilePackagesAsDirectories: NO];
	[openPanel setMessage:	NSLocalizedString(@"Choose the DOS installer program for this game:",
											  @"Help text shown at the top of choose-an-installer panel.")];
	
	[openPanel setDelegate: self];
	[openPanel beginSheetForDirectory: [[[self controller] document] sourcePath]
								 file: nil
								types: [[BXAppController executableTypes] allObjects]
					   modalForWindow: [[self view] window]
						modalDelegate: self
					   didEndSelector: @selector(_addChosenInstaller:returnCode:contextInfo:)
						  contextInfo: nil];	
}

- (BOOL) panel: (id)sender shouldShowFilename: (NSString *)filename
{
	//Disable files outside the source path of the import process, for sanity's sake
	return [filename isRootedInPath: [[[self controller] document] sourcePath]];
}

- (void) _addChosenInstaller: (NSOpenPanel *)openPanel
				  returnCode: (int)returnCode
				 contextInfo: (void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		NSString *path = [[openPanel URL] path];
		
		NSInteger itemIndex = [[self installerSelector] indexOfItemWithRepresentedObject: path];
		if (itemIndex != -1)
		{
			//This path already exists in the menu, select it
			[[self installerSelector] selectItemAtIndex: itemIndex];
		}
		else
		{
			//This installer is not yet in the menu - add a new entry for it and select it
			NSMenuItem *item = [self _installerSelectorItemForPath: path];
			[[[self installerSelector] menu] insertItem: item atIndex: 0];
			[[self installerSelector] selectItemAtIndex: 0];
		}
	}
	else if (returnCode == NSCancelButton)
	{
		//Revert to the first menu item if the user cancelled
		[[self installerSelector] selectItemAtIndex: 0];
	}
}

- (IBAction) showImportInstallerHelp: (id)sender
{
	[[NSApp delegate] showHelpAnchor: @"import-choose-installer"];
}

@end
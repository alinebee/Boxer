/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXPreferencesController.h"
#import "BXSession.h"
#import "BXValueTransformers.h"
#import "BXGamesFolderPanelController.h"
#import "BXAppController+BXGamesFolder.h"
#import "BXAppController+BXSupportFiles.h"
#import "BXMT32ROMDropzone.h"
#import "BXEmulatedMT32.h"

#pragma mark -
#pragma mark Implementation

@implementation BXPreferencesController
@synthesize filterGallery, gamesFolderSelector, currentGamesFolderItem;
@synthesize MT32ROMDropzone, MT32ROMMissingHelpText, MT32ROMUsageHelpText;

#pragma mark -
#pragma mark Initialization and deallocation

+ (BXPreferencesController *) controller
{
	static BXPreferencesController *singleton = nil;
	
	if (!singleton) singleton = [[self alloc] initWithWindowNibName: @"Preferences"];
	return singleton;
}

- (void) awakeFromNib
{
	//Bind to the filter preference so that we can synchronise our filter selection controls when it changes
	[[NSUserDefaults standardUserDefaults] addObserver: self
											forKeyPath: @"filterType"
											   options: NSKeyValueObservingOptionInitial
											   context: nil];
	
	
	//Bind the attributed title so that it will prettify the current games folder path
	NSDictionary *bindingOptions = [NSDictionary dictionaryWithObjectsAndKeys:
									@"BXIconifiedGamesFolderPath", NSValueTransformerNameBindingOption,
									nil];
	
	[currentGamesFolderItem bind: @"attributedTitle"
						toObject: [NSApp delegate]
					 withKeyPath: @"gamesFolderPath"
						 options: bindingOptions];
	
    
    //Listen for changes to the ROMs so that we can set the correct device in the ROM dropzone.
    [[NSApp delegate] addObserver: self
                       forKeyPath: @"pathToMT32ControlROM"
                          options: NSKeyValueObservingOptionInitial
                          context: nil];
    
    [[NSApp delegate] addObserver: self
                       forKeyPath: @"pathToMT32PCMROM"
                          options: NSKeyValueObservingOptionInitial
                          context: nil];
    
    //Rerun the MT-32 ROM syncing each time Boxer regains the application focus,
    //to cover the user manually adding them in Finder.
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(syncMT32ROMState)
                                                 name: NSApplicationDidBecomeActiveNotification
                                               object: NSApp];
    
    
    //Set up the audio preferences panel as a drag target for file drops.
    NSView *audioPrefsView = [[[self tabView] tabViewItemAtIndex: BXAudioPreferencesPanel] view];
	[audioPrefsView registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];
	
    
	//Select the tab that the user had open last time.
    NSInteger selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey: @"initialPreferencesPanelIndex"];
	
	if (selectedIndex >= 0 && selectedIndex < [[self tabView] numberOfTabViewItems])
	{
		[[self tabView] selectTabViewItemAtIndex: selectedIndex];
	}
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [[NSApp delegate] removeObserver: self forKeyPath: @"pathToMT32ControlROM"];
    [[NSApp delegate] removeObserver: self forKeyPath: @"pathToMT32PCMROM"];
    
	[currentGamesFolderItem unbind: @"attributedTitle"];
	
    [self setMT32ROMMissingHelpText: nil],      [MT32ROMMissingHelpText release];
    [self setMT32ROMUsageHelpText: nil],        [MT32ROMUsageHelpText release];
    [self setMT32ROMDropzone: nil],             [MT32ROMDropzone release];
	[self setFilterGallery: nil],				[filterGallery release];
	[self setGamesFolderSelector: nil],			[gamesFolderSelector release];
	[self setCurrentGamesFolderItem: nil],		[currentGamesFolderItem release];
	[super dealloc];
}


- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{
	//Whenever the key path changes, synchronise our filter selection controls
	if ([keyPath isEqualToString: @"filterType"])
	{
		[self syncFilterControls];
	}
    else if ([keyPath isEqualToString: @"pathToMT32ControlROM"] || [keyPath isEqualToString: @"pathToMT32PCMROM"])
    {
        [self syncMT32ROMState];
    }
}

#pragma mark -
#pragma mark Managing and persisting tab state


- (void) tabView: (NSTabView *)tabView didSelectTabViewItem: (NSTabViewItem *)tabViewItem
{
	[super tabView: tabView didSelectTabViewItem: tabViewItem];
	
	//Record the user's choice of tab, and synchronize the selected segment
	NSInteger selectedIndex = [tabView indexOfTabViewItem: tabViewItem];
	
	if (selectedIndex != NSNotFound)
	{
		[[NSUserDefaults standardUserDefaults] setInteger: selectedIndex
												   forKey: @"initialPreferencesPanelIndex"];
	}
}

- (BOOL) shouldSyncWindowTitleToTabLabel: (NSString *)label
{
    return YES;
}


#pragma mark -
#pragma mark Managing MT-32 ROMs

- (void) syncMT32ROMState
{
    NSString *controlPath   = [[NSApp delegate] pathToMT32ControlROM];
    NSString *PCMPath       = [[NSApp delegate] pathToMT32PCMROM];
    
    NSError *error = nil;
    BXMT32ROMType type = [BXEmulatedMT32 typeofROMPairWithControlROMPath: controlPath
                                                              PCMROMPath: PCMPath
                                                                   error: &error];
    
    NSString *title;
    
    //If ROMs are installed correctly, show the user what kind they have.
    if (type == BXMT32ROMTypeMT32)
    {
        title = NSLocalizedString(@"Roland MT-32 emulation is now active.",
                                  @"Title shown in MT-32 ROM dropzone when MT-32 ROMs are installed.");
    }
    else if (type == BXMT32ROMTypeCM32L)
    {
        title = NSLocalizedString(@"Roland CM-32L emulation is now active.",
                                  @"Title shown in MT-32 ROM dropzone when CM-32L ROMs are installed.");
    }
    
    //Otherwise, work out what went wrong.
    else if ([[error domain] isEqualToString: BXEmulatedMT32ErrorDomain])
    {
        switch ([error code])
        {
            //One or both ROMs are not installed yet.
            case BXEmulatedMT32MissingROM:
            {
                //If neither ROM is present, show the standard prompt.
                if (!PCMPath && !controlPath)
                {
                    title = NSLocalizedString(@"Drop MT-32 ROMs here to enable MT-32 emulation.",
                                              @"Title shown in MT-32 ROM dropzone when no ROMs are present.");
                }
                //If one or the other ROM is missing, tell the user which kind they still need.
                else
                {
                    NSString *titleFormat, *expectedROMName;
                    if (!PCMPath)
                    {
                        BXMT32ROMType controlType = [BXEmulatedMT32 typeOfControlROMAtPath: controlPath error: nil];
                        expectedROMName = (controlType == BXMT32ROMTypeCM32L) ? @"CM32L_PCM.ROM" : @"MT32_PCM.ROM";
                        titleFormat = NSLocalizedString(@"Now drop in the matching PCM ROM\n(e.g. “%1$@”.)",
                                                        @"Title shown in MT-32 ROM dropzone when a control ROM is present without a PCM ROM. %1$@ is the expected name of the matching ROM.");
                    }
                    else
                    {
                        BXMT32ROMType PCMType = [BXEmulatedMT32 typeOfPCMROMAtPath: PCMPath error: nil];
                        expectedROMName = (PCMType == BXMT32ROMTypeCM32L) ? @"CM32L_CONTROL.ROM" : @"MT32_CONTROL.ROM";
                        titleFormat = NSLocalizedString(@"Now drop in the matching control ROM\n(e.g. “%1$@”.)",
                                                        @"Title shown in MT-32 ROM dropzone when a PCM ROM is present without a control ROM. %1$@ is the expected name of the matching ROM.");
                    }
                    
                    title = [NSString stringWithFormat: titleFormat, expectedROMName];
                }
                break;
            }
                
            //ROMs were invalid or could not be read.
            default:
                title = NSLocalizedString(@"The current MT-32 ROMs are invalid.\nPlease drop in new ROMs to replace them.",
                                          @"Title shown in MT-32 ROM dropzone when user has manually added invalid or unreadable ROMs."); 
        }
    }
    
    [[self MT32ROMDropzone] setROMType: type];
    [[self MT32ROMDropzone] setTitle: title];
    
    //Toggle the help text depending on whether we have valid ROMs or not.
    [[self MT32ROMMissingHelpText] setHidden: (type != BXMT32ROMTypeUnknown)];
    [[self MT32ROMUsageHelpText] setHidden: (type == BXMT32ROMTypeUnknown)];
}

- (BOOL) handleROMImportFromPaths: (NSArray *)paths
{
    NSError *error = nil;
    BOOL succeeded = [[NSApp delegate] importMT32ROMsFromPaths: paths error: &error];
    
    if (error)
    {
        [self presentError: error
            modalForWindow: [self window]
                  delegate: nil
        didPresentSelector: NULL
               contextInfo: NULL];
    }
    return succeeded;
}

- (IBAction) showMT32ROMsInFinder: (id)sender
{
    NSString *basePath = [[NSApp delegate] MT32ROMPathCreatingIfMissing: YES];
    if (basePath) [[NSApp delegate] revealPath: basePath];
}

- (IBAction) showMT32ROMFileChooser: (id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	
	[openPanel setCanCreateDirectories: NO];
	[openPanel setCanChooseDirectories: YES];
	[openPanel setCanChooseFiles: YES];
	[openPanel setTreatsFilePackagesAsDirectories: NO];
	[openPanel setAllowsMultipleSelection: YES];
	[openPanel setDelegate: self];
	
	[openPanel setPrompt: NSLocalizedString(@"Import", @"Label for confirm button shown in MT-32 ROM file chooser panel.")];
	[openPanel setMessage: NSLocalizedString(@"Select the MT-32 control ROM and PCM ROM to use.",
											 @"Help text shown at the top of MT-32 ROM file chooser panel.")];
	
    //Note: we use straight file extension comparisons instead
    //of UTI codes because the ".rom" extension is owned by a
    //dozen-and-one console emulators and any UTI definition
    //of our own would just fight with them.
    NSArray *fileExtensions = [NSArray arrayWithObject: @"rom"];
    
    [openPanel beginSheetForDirectory: nil
                                 file: nil
                                types: fileExtensions
                       modalForWindow: [self window]
                        modalDelegate: self
                       didEndSelector: @selector(MT32ROMFileChooserDidEnd:returnCode:contextInfo:)
                          contextInfo: NULL];
}

- (void) MT32ROMFileChooserDidEnd: (NSOpenPanel *)openPanel
                       returnCode: (int)returnCode
                      contextInfo: (void *)contextInfo
{
    if (returnCode == NSOKButton)
	{
        NSArray *paths = [[openPanel URLs] valueForKey: @"path"];
        
        //Close the panel before attempting to import, so that
        //any error message from the panel won't screw up.
        [openPanel close];
        
        [self handleROMImportFromPaths: paths];
    }
}


//Display help for the Display Preferences panel.
- (IBAction) showAudioPreferencesHelp: (id)sender
{
	[[NSApp delegate] showHelpAnchor: @"audio"];
}


//Customise the menu item titles in the MT-32 shelf's right-click menu,
//depending on whether ROMs are present yet or not.
- (BOOL) validateMenuItem: (NSMenuItem *)menuItem
{
    if ([menuItem action] == @selector(showMT32ROMFileChooser:))
    {
        NSString *title;
        //If we already have a valid ROM, then replace it
        if ([[self MT32ROMDropzone] ROMType] != BXMT32ROMTypeUnknown)
            title = NSLocalizedString(@"Replace MT-32 ROMs…", @"Title of menu item for choosing MT-32 ROMs to replace the existing set.");
        
        else
            title = NSLocalizedString(@"Add MT-32 ROMs…", @"Title of menu item for choosing MT-32 ROMs to add when no ROMs are already present.");
        
        [menuItem setTitle: title];
    }
    else if ([menuItem action] == @selector(showMT32ROMsInFinder:))
    {
        NSString *title;
        //If we already have a valid ROM, then replace it
        if ([[self MT32ROMDropzone] ROMType] != BXMT32ROMTypeUnknown)
            title = NSLocalizedString(@"Show ROMs in Finder", @"Title of menu item for revealing the MT-32 ROM folder in Finder, when ROMs are already present.");
        
        else
            title = NSLocalizedString(@"Show ROM folder in Finder", @"Title of menu item for revealing the MT-32 ROM folder in Finder, when no ROMs are present.");
        
        [menuItem setTitle: title];
    }
    return YES;    
}


#pragma mark -
#pragma mark Managing filter gallery state

- (IBAction) toggleShelfAppearance: (NSButton *)sender
{
	BOOL flag = [sender state] == NSOnState;
	
	//This will already have been set by the button's own binding,
	//but it doesn't hurt to do it explicitly here
	[[NSApp delegate] setAppliesShelfAppearanceToGamesFolder: flag];
	
	NSString *path = [[NSApp delegate] gamesFolderPath];
	if (path && [[NSFileManager defaultManager] fileExistsAtPath: path])
	{
		if (flag)
		{
			[[NSApp delegate] applyShelfAppearanceToPath: path andSubFolders: YES switchToShelfMode: YES];
		}
		else
		{
			//Restore the folder to its unshelfed state
			[[NSApp delegate] removeShelfAppearanceFromPath: path andSubFolders: YES];
		}		
	}
}

- (IBAction) toggleDefaultFilterType: (id)sender
{
	NSInteger filterType = [sender tag];
	[[NSUserDefaults standardUserDefaults] setInteger: filterType forKey: @"filterType"];
}

- (void) syncFilterControls
{
	NSInteger defaultFilter = [[NSUserDefaults standardUserDefaults] integerForKey: @"filterType"];

	for (id view in [filterGallery subviews])
	{
		if ([view isKindOfClass: [NSButton class]])
		{
			[view setState: ([view tag] == defaultFilter)];
		}
	}
}

- (IBAction) showGamesFolderChooser: (id)sender
{
	BXGamesFolderPanelController *chooser = [BXGamesFolderPanelController controller];
	[chooser showGamesFolderPanelForWindow: [self window]];
	[[self gamesFolderSelector] selectItemAtIndex: 0];
}

//Display help for the Display Preferences panel.
- (IBAction) showDisplayPreferencesHelp: (id)sender
{
	[[NSApp delegate] showHelpAnchor: @"display"];
}


#pragma mark -
#pragma mark Drag-drop events for MT-32 ROM adding

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = [sender draggingPasteboard];
	if ([[pboard types] containsObject: NSFilenamesPboardType])
	{
        //Highlight the shelf when the drag operation is over it,
        //if the pasteboard contents are acceptable
        [[self MT32ROMDropzone] setHighlighted: YES];
        
        //Don't bother validating the ROMs here,
        //just change the cursor to show we'll accept them.
        return NSDragOperationCopy;
	}
	else return NSDragOperationNone;
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender
{	
    //Unhighlight the shelf when the drag operation is done
    [[self MT32ROMDropzone] setHighlighted: NO];
    
	NSPasteboard *pboard = [sender draggingPasteboard];
	if ([[pboard types] containsObject: NSFilenamesPboardType])
	{
		NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
        
        //This will validate the ROMs and reject them if they could not be imported.
        return [self handleROMImportFromPaths: filePaths];
	}
	return NO;
}

- (void) draggingExited: (id<NSDraggingInfo>)sender
{
    //Unhighlight the shelf when the drag operation leaves it
    [[self MT32ROMDropzone] setHighlighted: NO];
}

@end

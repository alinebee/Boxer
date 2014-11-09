/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXPreferencesController.h"
#import "BXSession.h"
#import "BXValueTransformers.h"
#import "BXGamesFolderPanelController.h"
#import "BXAppController+BXGamesFolder.h"
#import "BXBaseAppController+BXHotKeys.h"
#import "BXBaseAppController+BXSupportFiles.h"

#import "BXMT32ROMDropzone.h"
#import "BXEmulatedMT32.h"
#import "BXMIDIDeviceMonitor.h"
#import "BXFilterGallery.h"
#import "BXFrameRenderingView.h"

#pragma mark -
#pragma mark Implementation

//Constants for preferences panel tab indexes
enum {
	BXGeneralPreferencesPanelIndex,
	BXDisplayPreferencesPanelIndex,
	BXAudioPreferencesPanelIndex
};

#pragma mark - Private API declarations
@interface BXPreferencesController ()

/// Called when drag-dropping ROMs onto the MT-32 ROM dropzone or choosing them from the file picker.
/// Does the work of importing ROMs from the specified file URLs.  Will display an error sheet in the
/// Preferences window if importing failed.
- (BOOL) handleROMImportFromURLs: (NSArray *)URLs;

/// Synchronises the MT-32 ROM dropzone to display the currently-installed ROM and to update instructions
/// whenever is plugged in.
/// This is called whenever ROMs are imported or a real MT-32 is plugged in, and also whenever Boxer becomes
/// the active application: in case the user has manually added or removed ROMs in Finder.
- (void) syncMT32ROMState;

/// Synchonises the filter gallery to highlight the current rendering style.
/// This is called through KVO whenever the rendering style preference changes.
- (void) syncFilterControls;

/// Synchronises the visibility and content of the Keyboard hotkey help instructions.
/// This is called at window creation time, and whenever Boxer becomes the active application
/// (in case the user has changed OS X's application accessibility controls.
- (void) syncKeyboardInstructions;

@end


#pragma mark - Implementation

@implementation BXPreferencesController

@synthesize gamesFolderSelector = _gamesFolderSelector;
@synthesize currentGamesFolderItem = _currentGamesFolderItem;

@synthesize filterGallery = _filterGallery;

@synthesize MT32ROMDropzone = _MT32ROMDropzone;
@synthesize missingMT32ROMHelp = _missingMT32ROMHelp;
@synthesize realMT32Help = _realMT32Help;
@synthesize MT32ROMOptions = _MT32ROMOptions;

@synthesize hotkeyCaptureToggle = _hotkeyCaptureToggle;
@synthesize hotkeyCaptureDescription = _hotkeyCaptureDescription;
@synthesize hotkeyCaptureExtraHelp = _hotkeyCaptureExtraHelp;
@synthesize hotkeyCapturePermissionsButton = _hotkeyCapturePermissionsButton;


#pragma mark - Initialization and deallocation

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
											forKeyPath: @"renderingStyle"
											   options: NSKeyValueObservingOptionInitial
											   context: nil];
	
	
	//Bind the attributed title such that it will prettify the current games folder path
	[self.currentGamesFolderItem bind: @"attributedTitle"
                             toObject: [NSApp delegate]
                          withKeyPath: @"gamesFolderURL.path"
                              options: @{NSValueTransformerNameBindingOption : @"BXIconifiedGamesFolderPath"}];
	
    BXBaseAppController *appController = (BXBaseAppController *)[NSApp delegate];
    //Listen for changes to the ROMs so that we can set the correct device in the ROM dropzone.
    [appController addObserver: self
                    forKeyPath: @"MT32ControlROMURL"
                       options: 0
                       context: nil];
    
    [appController addObserver: self
                    forKeyPath: @"MT32PCMROMURL"
                       options: 0
                       context: nil];
    
    //Also listen for MT-32 device connections.
    [appController addObserver: self
                    forKeyPath: @"MIDIDeviceMonitor.discoveredMT32s"
                       options: 0
                       context: nil];
    
    [appController addObserver: self
                    forKeyPath: @"canCaptureKeyEvents"
                       options: 0
                       context: nil];
    
    [appController addObserver: self
                    forKeyPath: @"needsRestartForHotkeyCapture"
                       options: 0
                       context: nil];
    
    //Resync the MT-32 ROM panel whenever Boxer regains the application focus,
    //to cover the user manually adding them in Finder.
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(syncMT32ROMState)
                                                 name: NSApplicationDidBecomeActiveNotification
                                               object: NSApp];
    
    
    //Set up the audio preferences panel as a drag target for file drops.
    NSView *audioPrefsView = [self.tabView tabViewItemAtIndex: BXAudioPreferencesPanelIndex].view;
	[audioPrefsView registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];
	
    
	//Select the tab that the user had open last time.
    NSInteger selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey: @"initialPreferencesPanelIndex"];
	
	if (selectedIndex >= 0 && selectedIndex < self.tabView.numberOfTabViewItems)
	{
		[self.tabView selectTabViewItemAtIndex: selectedIndex];
	}
    
    //Update the MT-32 dropzone state.
    [self syncMT32ROMState];
    
    //Update the keyboard panel instructions.
    [self syncKeyboardInstructions];
}

- (void) dealloc
{
	[[NSUserDefaults standardUserDefaults] removeObserver: self
                                               forKeyPath: @"renderingStyle"];
    
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    
    BXBaseAppController *appController = (BXBaseAppController *)[NSApp delegate];
    [appController removeObserver: self forKeyPath: @"MIDIDeviceMonitor.discoveredMT32s"];
    [appController removeObserver: self forKeyPath: @"MT32ControlROMURL"];
    [appController removeObserver: self forKeyPath: @"MT32PCMROMURL"];
    [appController removeObserver: self forKeyPath: @"canCaptureKeyEvents"];
    [appController removeObserver: self forKeyPath: @"needsRestartForHotkeyCapture"];
    
	[self.currentGamesFolderItem unbind: @"attributedTitle"];
	
    self.gamesFolderSelector = nil;
    self.currentGamesFolderItem = nil;
    
    self.missingMT32ROMHelp = nil;
    self.realMT32Help = nil;
    self.MT32ROMOptions = nil;
    self.MT32ROMDropzone = nil;
    
    self.filterGallery = nil;
    
    self.hotkeyCaptureToggle = nil;
    self.hotkeyCaptureDescription = nil;
    self.hotkeyCaptureExtraHelp = nil;
    self.hotkeyCapturePermissionsButton = nil;
    
	[super dealloc];
}


- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{
	//Whenever the key path changes, synchronise our filter selection controls
	if ([keyPath isEqualToString: @"renderingStyle"])
	{
		[self syncFilterControls];
	}
    else if ([keyPath isEqualToString: @"canCaptureKeyEvents"] || [keyPath isEqualToString: @"needsRestartForHotkeyCapture"])
    {
        [self syncKeyboardInstructions];
    }
    else if ([keyPath isEqualToString: @"MT32ControlROMURL"] || [keyPath isEqualToString: @"MT32PCMROMURL"] || [keyPath isEqualToString: @"MIDIDeviceMonitor.discoveredMT32s"])
    {
        //Ensure the syncing is done on the main thread: notifications from BXMIDIMonitor
        //will come from the monitor's own thread.
        [self performSelectorOnMainThread: @selector(syncMT32ROMState) withObject: nil waitUntilDone: NO];
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


#pragma mark - Managing MT-32 ROMs

- (void) syncMT32ROMState
{
    NSString *title = nil;
    BXMT32ROMType type = BXMT32ROMTypeUnknown;
    BOOL showROMHelp;
    BOOL showROMOptions;
    BOOL showRealMT32Help;
    
    //First, check if any real MT-32s are plugged in.
    BOOL realMT32Connected = ([(BXBaseAppController *)[NSApp delegate] MIDIDeviceMonitor].discoveredMT32s.count > 0);
    
    //If so, display a custom message
    if (realMT32Connected)
    {
        title = NSLocalizedString(@"Your real Roland MT-32 is connected.",
                                  @"Title shown in MT-32 ROM dropzone when user has a real MT-32 connected to their Mac.");
        
        //Assume the device is an MT-32 rather than a CM-32L.
        type = BXMT32ROMIsMT32;
        
        showROMHelp         = NO;
        showROMOptions      = NO;
        showRealMT32Help    = YES;
    }
    //Failing that, check what type of MT-32 ROMs we have installed.
    else
    {
        NSURL *controlURL   = [(BXBaseAppController *)[NSApp delegate] MT32ControlROMURL];
        NSURL *PCMURL       = [(BXBaseAppController *)[NSApp delegate] MT32PCMROMURL];
        
        NSError *error = nil;
        type = [BXEmulatedMT32 typeOfROMPairWithControlROMURL: controlURL
                                                    PCMROMURL: PCMURL
                                                        error: &error];
        
        
        //If ROMs are installed correctly, show the user what kind they have.
        if (type & BXMT32ROMIsMT32)
        {
            title = NSLocalizedString(@"Roland MT-32 emulation is installed.",
                                      @"Title shown in MT-32 ROM dropzone when MT-32 ROMs are installed.");
        }
        else if (type & BXMT32ROMIsCM32L)
        {
            title = NSLocalizedString(@"Roland CM-32L emulation is installed.",
                                      @"Title shown in MT-32 ROM dropzone when CM-32L ROMs are installed.");
        }
        
        //Otherwise, work out what went wrong.
        else if ([error.domain isEqualToString: BXEmulatedMT32ErrorDomain])
        {
            switch (error.code)
            {
                //One or both ROMs are not installed yet.
                case BXEmulatedMT32MissingROM:
                {
                    //If neither ROM is present, show the standard prompt.
                    if (!PCMURL && !controlURL)
                    {
                        title = NSLocalizedString(@"Drop MT-32 ROMs here to enable MT-32 emulation.",
                                                  @"Title shown in MT-32 ROM dropzone when no ROMs are present.");
                    }
                    //If one or the other ROM is missing, tell the user which kind they still need.
                    else
                    {
                        NSString *titleFormat, *expectedROMName;
                        if (!PCMURL)
                        {
                            BXMT32ROMType controlType = [BXEmulatedMT32 typeOfROMAtURL: controlURL error: NULL];
                            expectedROMName = (controlType & BXMT32ROMIsCM32L) ? @"CM32L_PCM.ROM" : @"MT32_PCM.ROM";
                            titleFormat = NSLocalizedString(@"Now drop in the matching PCM ROM\n(e.g. “%1$@”.)",
                                                            @"Title shown in MT-32 ROM dropzone when a control ROM is present without a PCM ROM. %1$@ is the expected name of the matching ROM.");
                        }
                        else
                        {
                            BXMT32ROMType PCMType = [BXEmulatedMT32 typeOfROMAtURL: PCMURL error: nil];
                            expectedROMName = (PCMType == BXMT32ROMIsCM32L) ? @"CM32L_CONTROL.ROM" : @"MT32_CONTROL.ROM";
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
        
        showROMHelp         = (type == BXMT32ROMTypeUnknown);
        showROMOptions      = (type != BXMT32ROMTypeUnknown);
        showRealMT32Help    = NO;
    }
    
    self.MT32ROMDropzone.ROMType = type;
    self.MT32ROMDropzone.title = title;
    
    //Toggle the help text depending on whether we have valid ROMs or not.
    self.missingMT32ROMHelp.hidden = !showROMHelp;
    self.realMT32Help.hidden = !showRealMT32Help;
    self.MT32ROMOptions.hidden = !showROMOptions;
}

- (BOOL) handleROMImportFromURLs: (NSArray *)URLs
{
    NSError *error;
    BOOL succeeded = [(BXBaseAppController *)[NSApp delegate] importMT32ROMsFromURLs: URLs error: &error];
    
    if (!succeeded)
    {
        [self.window.attachedSheet orderOut: self];
        
        [self presentError: error
            modalForWindow: self.window
                  delegate: nil
        didPresentSelector: NULL
               contextInfo: NULL];
    }
    return succeeded;
}

- (IBAction) showMT32ROMsInFinder: (id)sender
{
    NSMutableArray *URLsToReveal = [NSMutableArray arrayWithCapacity: 2];
    NSURL *controlROMURL = [(BXBaseAppController *)[NSApp delegate] MT32ControlROMURL];
    if (controlROMURL)
        [URLsToReveal addObject: controlROMURL];
    
    NSURL *pcmROMURL = [(BXBaseAppController *)[NSApp delegate] MT32PCMROMURL];
    if (pcmROMURL)
        [URLsToReveal addObject: pcmROMURL];
    
    //If the user has not yet added any ROMs, then create the empty directory and display that instead.
    if (!URLsToReveal.count)
    {
        NSURL *baseROMURL = [(BXBaseAppController *)[NSApp delegate] MT32ROMURLCreatingIfMissing: YES error: NULL];
        if (baseROMURL)
            [URLsToReveal addObject: baseROMURL];
    }
    
    if (URLsToReveal.count)
        [(BXBaseAppController *)[NSApp delegate] revealURLsInFinder: URLsToReveal];

}

- (IBAction) showMT32ROMFileChooser: (id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	
    openPanel.delegate = self;
    
    openPanel.canCreateDirectories = NO;
    openPanel.canChooseDirectories = YES;
    openPanel.canChooseFiles = YES;
    openPanel.treatsFilePackagesAsDirectories = NO;
    openPanel.allowsMultipleSelection = YES;
    
    openPanel.prompt = NSLocalizedString(@"Import", @"Label for confirm button shown in MT-32 ROM file chooser panel.");
	openPanel.message = NSLocalizedString(@"Select the MT-32 control ROM and PCM ROM to use.",
                                          @"Help text shown at the top of MT-32 ROM file chooser panel.");
	
    //Note: we use straight file extension comparisons instead
    //of UTI codes because the ".rom" extension is owned by a
    //dozen-and-one console emulators and any UTI definition
    //of our own would just fight with them.
    openPanel.allowedFileTypes = @[@"rom"];
    
    [openPanel beginSheetModalForWindow: self.window
                      completionHandler: ^(NSInteger result) {
                          if (result == NSFileHandlingPanelOKButton)
                          {
                              [self handleROMImportFromURLs: openPanel.URLs];
                          }
                      }];
}


//Customise the menu item titles in the MT-32 shelf's right-click menu,
//depending on whether ROMs are present yet or not.
- (BOOL) validateMenuItem: (NSMenuItem *)menuItem
{
    BOOL hasROMs = (self.MT32ROMDropzone.ROMType != BXMT32ROMTypeUnknown);
    if (menuItem.action == @selector(showMT32ROMFileChooser:))
    {
        //If we already have a valid ROM, then replace it
        if (hasROMs)
        {
            menuItem.title = NSLocalizedString(@"Replace MT-32 ROMs…",
                                               @"Title of menu item for choosing MT-32 ROMs to replace the existing set.");
        }
        else
        {
            menuItem.title = NSLocalizedString(@"Add MT-32 ROMs…",
                                               @"Title of menu item for choosing MT-32 ROMs to add when no ROMs are already present.");
        }
    }
    else if (menuItem.action == @selector(showMT32ROMsInFinder:))
    {
        if (hasROMs)
        {
            menuItem.title = NSLocalizedString(@"Show ROMs in Finder",
                                               @"Title of menu item for revealing the MT-32 ROM folder in Finder, when ROMs are already present.");
        }
        else
        {
            menuItem.title = NSLocalizedString(@"Show ROM folder in Finder",
                                               @"Title of menu item for revealing the MT-32 ROM folder in Finder, when no ROMs are present.");
        }
    }
    return YES;    
}


#pragma mark - Managing filter gallery state

- (IBAction) toggleShelfAppearance: (NSButton *)sender
{
	BOOL flag = (sender.state == NSOnState);
	
	//This will already have been set by the button's own binding,
	//but it doesn't hurt to do it explicitly here
	[(BXAppController *)[NSApp delegate] setAppliesShelfAppearanceToGamesFolder: flag];
	
	NSURL *URL = [(BXAppController *)[NSApp delegate] gamesFolderURL];
	if ([URL checkResourceIsReachableAndReturnError: NULL])
	{
		if (flag)
		{
			[(BXAppController *)[NSApp delegate] applyShelfAppearanceToURL: URL
                                                             andSubFolders: YES
                                                         switchToShelfMode: YES];
		}
		else
		{
			//Restore the folder to its unshelfed state
			[(BXAppController *)[NSApp delegate] removeShelfAppearanceFromURL: URL
                                                                andSubFolders: YES];
		}		
	}
}

- (IBAction) toggleDefaultRenderingStyle: (id <NSValidatedUserInterfaceItem>)sender
{
	BXRenderingStyle style = (BXRenderingStyle)sender.tag;
	[[NSUserDefaults standardUserDefaults] setInteger: style forKey: @"renderingStyle"];
}

- (void) syncFilterControls
{
	NSInteger activeFilter = [[NSUserDefaults standardUserDefaults] integerForKey: @"renderingStyle"];

	for (NSButton *button in self.filterGallery.subviews)
	{
		if ([button isKindOfClass: [NSButton class]])
		{
            button.state = (button.tag == activeFilter);
		}
	}
}

- (IBAction) showGamesFolderChooser: (id)sender
{
	BXGamesFolderPanelController *chooser = [BXGamesFolderPanelController controller];
	[chooser showGamesFolderPanelForWindow: self.window];
	[self.gamesFolderSelector selectItemAtIndex: 0];
}


#pragma mark - Managing hotkey instructions

- (void) syncKeyboardInstructions
{
    CGFloat extraHelpSize = [NSFont systemFontSizeForControlSize: NSSmallControlSize];
    if ([(BXBaseAppController *)[NSApp delegate] needsRestartForHotkeyCapture])
    {
        self.hotkeyCaptureToggle.enabled = NO;
        self.hotkeyCaptureDescription.textColor = [NSColor disabledControlTextColor];
        self.hotkeyCapturePermissionsButton.hidden = NO;
        
        self.hotkeyCaptureExtraHelp.font = [NSFont boldSystemFontOfSize: extraHelpSize];
        self.hotkeyCaptureExtraHelp.stringValue = NSLocalizedString(@"Your changes to accessibility permissions will take effect next time Boxer is launched.", @"Help message shown on Keyboard Preferences panel when Boxer has been given extra accessibility permission but must restart for it to take effect.");
        
        self.hotkeyCapturePermissionsButton.title = NSLocalizedString(@"Relaunch Boxer Now", @"Label of button displayed in Keyboard Preferences when Boxer needs to restart in order for extra accessibility permissions to take effect.");
        self.hotkeyCapturePermissionsButton.target = [NSApp delegate];
        self.hotkeyCapturePermissionsButton.action = @selector(relaunch:);
    }
    else if ([(BXBaseAppController *)[NSApp delegate] canCaptureHotkeys])
    {
        self.hotkeyCaptureToggle.enabled = YES;
        self.hotkeyCaptureDescription.textColor = [NSColor controlTextColor];
        self.hotkeyCapturePermissionsButton.hidden = YES;
        
        self.hotkeyCaptureExtraHelp.font = [NSFont systemFontOfSize: extraHelpSize];
        self.hotkeyCaptureExtraHelp.stringValue = NSLocalizedString(@"(If an F1, F2 etc. key still behaves as an OS X hotkey, then hold down Fn while pressing the key.)", @"Additional help displayed below hotkey capture toggle on Keyboard Preferences pane.");
    }
    else
    {
        self.hotkeyCaptureToggle.enabled = NO;
        self.hotkeyCaptureDescription.textColor = [NSColor disabledControlTextColor];
        
        self.hotkeyCapturePermissionsButton.hidden = NO;
        self.hotkeyCapturePermissionsButton.target = [NSApp delegate];
        self.hotkeyCapturePermissionsButton.action = @selector(showSystemAccessibilityControls:);
        
        //Rephrase the hotkey capture help based on what version of OS X we're running on,
        //as the global accessibility controls changed to per-app controls in 10.9.
        NSString *accessibilityPrefsName = [BXAppController localizedSystemAccessibilityPreferencesName];
        NSString *hotkeyButtonLabelFormat = NSLocalizedString(@"Open %1$@ Preferences", @"Title of button in Keyboard Preferences pane to open OS X's accessibility controls. %1$@ is the localized name of the appropriate System Preferences pane.");
        
        NSString *helpFormat;
        if ([BXAppController hasPerAppAccessibilityControls])
        {
            helpFormat = NSLocalizedString(@"This feature requires Boxer to be given accessibility control in %1$@ Preferences.", @"Explanatory message shown in Keyboard Preferences if Boxer is not able to install its hotkey capture event tap on OS X 10.9 and up. %1$@ is the localized name of the Security & Privacy preferences pane.");
        }
        else
        {
            helpFormat = NSLocalizedString(@"“Enable access for assistive devices” must also\n be enabled in OS X’s %1$@ preferences.", @"Explanatory message shown in Keyboard Preferences if Boxer is not able to install its hotkey capture event tap on OS X 10.8 and below. %1$@ is the localized name of the Accessibility preferences pane.");
        }
        
        self.hotkeyCaptureExtraHelp.font = [NSFont boldSystemFontOfSize: extraHelpSize];
        self.hotkeyCaptureExtraHelp.stringValue = [NSString stringWithFormat: helpFormat, accessibilityPrefsName];
        
        self.hotkeyCapturePermissionsButton.title = [NSString stringWithFormat: hotkeyButtonLabelFormat, accessibilityPrefsName];
    }
}


#pragma mark - Help

- (IBAction) showDisplayPreferencesHelp: (id)sender
{
	[(BXBaseAppController *)[NSApp delegate] showHelpAnchor: @"display"];
}


- (IBAction) showKeyboardPreferencesHelp: (id)sender
{
    //Was @"keyboard", but that was too general for the contents of the keyboard panel.
	[(BXBaseAppController *)[NSApp delegate] showHelpAnchor: @"spaces-shortcuts"];
}

- (IBAction) showAudioPreferencesHelp: (id)sender
{
	[(BXBaseAppController *)[NSApp delegate] showHelpAnchor: @"mt32-music"];
}


#pragma mark - Drag-drop events for MT-32 ROM dropzone

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = sender.draggingPasteboard;
    
    BOOL hasURLs = [pboard canReadObjectForClasses: @[[NSURL class]]
                                           options: @{ NSPasteboardURLReadingFileURLsOnlyKey : @(YES) }];
    
    if (hasURLs)
    {
        //Highlight the shelf when files are dragged over it.
        self.MT32ROMDropzone.highlighted = YES;
        
        //Don't bother validating the ROMs here, just change the cursor to show we'll accept them.
        return NSDragOperationCopy;
    }
	else return NSDragOperationNone;
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender
{	
    //Unhighlight the shelf when the drag operation is done.
    self.MT32ROMDropzone.highlighted = NO;
    
	NSPasteboard *pboard = sender.draggingPasteboard;
    
    NSArray *droppedURLs = [pboard readObjectsForClasses: @[[NSURL class]]
                                                 options: @{ NSPasteboardURLReadingFileURLsOnlyKey : @(YES) }];
    
    if (droppedURLs.count)
    {
        return [self handleROMImportFromURLs: droppedURLs];
    }
    else
    {
        return NO;
    }
}

- (void) draggingExited: (id<NSDraggingInfo>)sender
{
    //Unhighlight the shelf when the drag operation leaves it.
    self.MT32ROMDropzone.highlighted = NO;
}

@end

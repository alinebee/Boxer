/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXGamesFolderPanelController.h"
#import "BXAppController+BXGamesFolder.h"

@interface BXGamesFolderPanelController ()

//Called when the user chooses a folder. Returns YES if the folder has been successfully
//assigned as the default games folder, or NO and populates outError if this could not
//be accomplished.
- (BOOL) chooseGamesFolderURL: (NSURL *)url error: (NSError **)outError;

@end

@implementation BXGamesFolderPanelController
@synthesize sampleGamesToggle = _sampleGamesToggle;
@synthesize useShelfAppearanceToggle = _useShelfAppearanceToggle;

+ (id) controller
{
	static BXGamesFolderPanelController *singleton = nil;
	if (!singleton) singleton = [[self alloc] initWithNibName: @"GamesFolderPanelOptions" bundle: nil];
	return singleton;
}

- (void) dealloc
{
    self.sampleGamesToggle = nil;
    self.useShelfAppearanceToggle = nil;
	[super dealloc];
}

- (void) showGamesFolderPanelForWindow: (NSWindow *)window
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	
	NSString *currentFolderPath = [[NSApp delegate] gamesFolderPath];
	NSString *parentFolderPath;
	if (currentFolderPath)
	{
		parentFolderPath = [currentFolderPath stringByDeletingLastPathComponent];
	}
	else
	{
		//If no folder yet exists, default to the home directory
		parentFolderPath = NSHomeDirectory();
	}
	
    openPanel.delegate = self;
    openPanel.canCreateDirectories = YES;
    openPanel.canChooseDirectories = YES;
    openPanel.canChooseFiles = NO;
    openPanel.treatsFilePackagesAsDirectories = NO;
    openPanel.allowsMultipleSelection = NO;
    
    openPanel.accessoryView = self.view;
    openPanel.directoryURL = [NSURL fileURLWithPath: parentFolderPath];
    //NOTE: NSOpenPanel has deprecated the ability to specify an initial selection,
    //otherwise we'd select the current folder initially.
    
    openPanel.prompt = NSLocalizedString(@"Select", @"Button label for Open panels when selecting a folder.");
    openPanel.message = NSLocalizedString(@"Select a folder in which to keep your DOS games:",
                                          @"Help text shown at the top of choose-a-games-folder panel.");
	
	//Set the initial state of the shelf-appearance toggle to match the current preference setting
	self.useShelfAppearanceToggle.state = [[NSApp delegate] appliesShelfAppearanceToGamesFolder];
	
    void (^completionHandler)(NSInteger result) = ^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton)
        {
            NSError *folderError = nil;
            BOOL assigned = [self chooseGamesFolderURL: openPanel.URL error: &folderError];
            
            if (!assigned && folderError)
            {
                if (window)
                {
                    //Close the open panel to avoid interfering with any error message
                    [openPanel orderOut: self];
                    
                    [self presentError: folderError
                        modalForWindow: window
                              delegate: nil
                    didPresentSelector: NULL
                           contextInfo: NULL];
                }
                else
                {
                    [self presentError: folderError];
                }
            }
        }
    };
    
	if (window)
	{
        [openPanel beginSheetModalForWindow: window
                          completionHandler: completionHandler];
	}
	else
	{
        NSInteger returnCode = [openPanel runModal];
        completionHandler(returnCode);
	}
}

- (void) panelSelectionDidChange: (NSOpenPanel *)openPanel
{
	NSString *selection = openPanel.URL.path;
	NSFileManager *manager = [NSFileManager defaultManager];
	BOOL hasFiles = ([manager enumeratorAtPath: selection].nextObject != nil);
	
	//If the selected folder is empty, turn on the copy-sample-games checkbox; otherwise, clear it. 
	self.sampleGamesToggle.state = !hasFiles;
}

- (void) panel: (NSOpenPanel *)openPanel didChangeToDirectoryURL: (NSURL *)url
{
    [self panelSelectionDidChange: openPanel];
}

//Delegate validation method for 10.6 and above.
- (BOOL) panel: (id)openPanel validateURL: (NSURL *)url error: (NSError **)outError
{
	NSString *path = [url path];
	return [[NSApp delegate] validateGamesFolderPath: &path error: outError];
}

- (BOOL) chooseGamesFolderURL: (NSURL *)URL error: (NSError **)outError
{
    BXAppController *controller = [NSApp delegate];
    BOOL addSampleGames		= self.sampleGamesToggle.state;
    BOOL useShelfAppearance	= self.useShelfAppearanceToggle.state;
    
    return [controller assignGamesFolderPath: URL.path
                             withSampleGames: addSampleGames
                             shelfAppearance: useShelfAppearance
                             createIfMissing: NO
                                       error: outError];
    
}

@end
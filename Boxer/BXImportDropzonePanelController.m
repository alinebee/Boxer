/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImportDropzonePanelController.h"
#import "BXImportWindowController.h"
#import "BXImportDropzone.h"
#import "BXImportSession.h"
#import "BXBlueprintPanel.h"
#import "BXAppController.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXImportDropzonePanelController ()

@end


@implementation BXImportDropzonePanelController
@synthesize dropzone = _dropzone;
@synthesize controller = _controller;
@synthesize spinner = _spinner;

#pragma mark -
#pragma mark Initialization and deallocation

- (void) awakeFromNib
{
	//Set up the dropzone panel to support drag-drop operations
	[self.view registerForDraggedTypes: @[NSFilenamesPboardType]];
	
    self.spinner.usesThreadedAnimation = YES;
	//Since the spinner is on a separate view that's only added to the window
	//when it's spinnin' time, we can safely start it animating now
	[self.spinner startAnimation: self];
}

- (void) dealloc
{
    self.dropzone = nil;
    self.spinner = nil;
	
	[super dealloc];
}


#pragma mark -
#pragma mark UI actions

- (IBAction) showImportPathPicker: (id)sender
{
	NSOpenPanel *openPanel	= [NSOpenPanel openPanel];
	
    openPanel.delegate = self;
    openPanel.canChooseFiles = YES;
    openPanel.canChooseDirectories = YES;
    openPanel.treatsFilePackagesAsDirectories = NO;
    openPanel.message = NSLocalizedString(@"Choose a DOS game folder, CD-ROM or disc image to import:",
                                          @"Help text shown at the top of choose-a-folder-to-import panel.");
    
    openPanel.prompt = NSLocalizedString(@"Import",
                                         @"Label shown on accept button in choose-a-folder-to-import panel.");
	
    openPanel.allowedFileTypes = [BXImportSession acceptedSourceTypes].allObjects;
    
    [openPanel beginSheetModalForWindow: self.view.window
                      completionHandler: ^(NSInteger result) {
                          if (result == NSFileHandlingPanelOKButton)
                          {
                              //Ensure the open panel is closed before we continue,
                              //in case importFromSourcePath: decides to display errors.
                              [openPanel orderOut: self];
                              
                              [self.controller.document importFromSourceURL: openPanel.URL];
                          }
                      }];
}

- (IBAction) showImportDropzoneHelp: (id)sender
{
	[[NSApp delegate] showHelpAnchor: @"import-drop-game"];
}


#pragma mark -
#pragma mark Drag-drop handlers

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = sender.draggingPasteboard;
    NSArray *dragClasses = @[[NSURL class]];
    NSDictionary *dragOptions = @{ NSPasteboardURLReadingFileURLsOnlyKey : @(YES) };
	if ([pboard canReadObjectForClasses: dragClasses options: dragOptions])
	{
		NSArray *droppedURLs = [pboard readObjectsForClasses: dragClasses
                                                     options: dragOptions];
        
        BXImportSession *importer = self.controller.document;
        
		for (NSURL *URL in droppedURLs)
		{
			//If any of the dropped files cannot be imported, reject the drop
			if (![importer.class canImportFromSourceURL: URL])
                return NSDragOperationNone;
		}
		
        self.dropzone.highlighted = YES;
        
		return NSDragOperationCopy;
	}
	else return NSDragOperationNone;
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = sender.draggingPasteboard;
	
    NSArray *droppedURLs = [pboard readObjectsForClasses: @[[NSURL class]]
                                                 options: @{ NSPasteboardURLReadingFileURLsOnlyKey : @(YES) }];
    
    BXImportSession *importer = self.controller.document;
    for (NSURL *URL in droppedURLs)
    {
        if ([importer.class canImportFromSourceURL: URL])
        {
            //Defer import to give the drag operation and animations time to clean up
            [importer performSelector: @selector(importFromSourceURL:) withObject: URL afterDelay: 0.5];
            return YES;
        }
    }
    
	return NO;
}

- (void)draggingExited: (id <NSDraggingInfo>)sender
{
    self.dropzone.highlighted = NO;
}

@end
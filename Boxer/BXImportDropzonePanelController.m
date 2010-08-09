/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImportDropzonePanelController.h"
#import "BXImportWindowController.h"
#import "BXImportDropzone.h"
#import "BXImport.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXImportDropzonePanelController ()

//Handles the response from the choose-a-folder-to-import panel.
//Will set our BXImport's source path to the chosen file.
- (void) _importChosenPath: (NSOpenPanel *)openPanel
				returnCode: (int)returnCode
			   contextInfo: (void *)contextInfo;

@end


@implementation BXImportDropzonePanelController
@synthesize dropzone, controller;

#pragma mark -
#pragma mark Initialization and deallocation

- (void) awakeFromNib
{
	//Set up the dropzone panel to support drag-drop operations
	[[self view] registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, nil]];
}

- (void) dealloc
{
	[self setDropzone: nil], [dropzone release];
	
	[super dealloc];
}


#pragma mark -
#pragma mark UI actions

- (IBAction) showImportPathPicker: (id)sender
{
	NSOpenPanel *openPanel	= [NSOpenPanel openPanel];
	
	[openPanel setCanChooseFiles: YES];
	[openPanel setCanChooseDirectories: YES];
	[openPanel setTreatsFilePackagesAsDirectories: NO];
	[openPanel setMessage:	NSLocalizedString(@"Choose a DOS game folder, CD-ROM or disc image to import:",
											  @"Help text shown at the top of choose-a-folder-to-import panel.")];
	[openPanel setPrompt:	NSLocalizedString(@"Import",
											  @"Label shown on accept button in choose-a-folder-to-import panel.")];
	
	[openPanel setDelegate: self];
	
	[openPanel beginSheetForDirectory: nil
								 file: nil
								types: [[BXImport acceptedSourceTypes] allObjects]
					   modalForWindow: [[self view] window]
						modalDelegate: self
					   didEndSelector: @selector(_importChosenPath:returnCode:contextInfo:)
						  contextInfo: nil];
}

- (void) _importChosenPath: (NSOpenPanel *)openPanel
				returnCode: (int)returnCode
			   contextInfo: (void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		NSString *path = [[openPanel URL] path];
		
		//Because an error sheet may be displayed from importFromSourcePath, we close the panel first
		[openPanel close];
		[[[self controller] document] importFromSourcePath: path];
	}
}


#pragma mark -
#pragma mark Drag-drop handlers

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = [sender draggingPasteboard];	
	if ([[pboard types] containsObject: NSFilenamesPboardType])
	{
		NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		for (NSString *path in filePaths)
		{
			//If any of the dropped files cannot be imported, reject the drop
			if (![[[self controller] document] canImportFromSourcePath: path]) return NSDragOperationNone;
		}
		
		[[self dropzone] setHighlighted: YES];
		return NSDragOperationCopy;
	}
	else return NSDragOperationNone;
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender
{
	[[self dropzone] setHighlighted: NO];
	
	NSPasteboard *pboard = [sender draggingPasteboard];
	
    if ([[pboard types] containsObject: NSFilenamesPboardType])
	{
        NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		for (NSString *path in filePaths)
		{
			if ([[[self controller] document] canImportFromSourcePath: path])
			{
				[[[self controller] document] importFromSourcePath: path];
				return YES;
			}
		}
	}
	return NO;
}

- (void)draggingExited: (id <NSDraggingInfo>)sender
{
	[[self dropzone] setHighlighted: NO];
}

@end
/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImportWindowController.h"
#import "BXImportDropzone.h"
#import "BXImport.h"

//The height of the bottom window border.
//TODO: determine this from NIB content.
#define BXImportWindowBorderThickness 40


#pragma mark -
#pragma mark Private method declarations

@interface BXImportWindowController ()

//Handles the response from the choose-a-folder-to-import panel.
//Will set our BXImport's source path to the chosen file.
- (void) _importChosenItem: (NSOpenPanel *)openPanel
				returnCode: (int)returnCode
			   contextInfo: (void *)contextInfo;

@end



@implementation BXImportWindowController
@synthesize dropzonePanel, dropzone;

- (BXImport *) document { return (BXImport *)[super document]; }

#pragma mark -
#pragma mark Initialization and deallocation

- (void) dealloc
{
	[self setDropzonePanel: nil], [dropzonePanel release];
	[self setDropzone: nil], [dropzone release];
	
	[super dealloc];
}


- (void) windowDidLoad
{
	[[self window] setContentBorderThickness: BXImportWindowBorderThickness forEdge: NSMinYEdge];
	
	//Default to the dropzone panel when we initially load
	[self setCurrentPanel: [self dropzonePanel]];
	
	//Set up the dropzone panel to support drag-drop operations
	[[self window] registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, nil]];
}

- (NSString *) windowTitleForDocumentDisplayName:(NSString *)displayName
{
	return NSLocalizedString(@"Import a Game", @"Title for game import window.");
}


#pragma mark -
#pragma mark View management

- (NSView *) currentPanel
{
	return [[[[self window] contentView] subviews] lastObject];
}

- (void) setCurrentPanel: (NSView *)panel
{
	NSView *oldPanel = [self currentPanel];
	
	NSRect newFrame, oldFrame = [[self window] frame];
	
	NSSize newSize	= [panel frame].size;
	NSSize oldSize	= [[[self window] contentView] frame].size;
	
	NSSize difference = NSMakeSize(
								   newSize.width - oldSize.width,
								   newSize.height - oldSize.height
								   );
	
	//Generate a new window frame that can contain the new panel,
	//Ensuring that the top left corner stays put
	newFrame.origin = NSMakePoint(
								  oldFrame.origin.x,
								  oldFrame.origin.y - difference.height
								  );
	newFrame.size	= NSMakeSize(
								 oldFrame.size.width + difference.width,
								 oldFrame.size.height + difference.height
								 );
	
	if (oldPanel != panel)
	{
		[panel setFrameOrigin: NSZeroPoint];
		 
		//Animate the transition from one panel to the next
		if (oldPanel)
		{
			[[[self window] contentView] addSubview: panel
										 positioned: NSWindowBelow
										 relativeTo: oldPanel];
			
			NSViewAnimation *animation;
			NSDictionary *resize, *fadeOut;
			
			resize = [NSDictionary dictionaryWithObjectsAndKeys:
					  [self window], NSViewAnimationTargetKey,
					  [NSValue valueWithRect: newFrame], NSViewAnimationEndFrameKey,
					  nil];
			
			fadeOut = [NSDictionary dictionaryWithObjectsAndKeys:
					  oldPanel, NSViewAnimationTargetKey,
					  NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey,
					  nil];
			
			animation = [[NSViewAnimation alloc] initWithViewAnimations: [NSArray arrayWithObjects: resize, fadeOut, nil]];
			
			[animation setAnimationBlockingMode: NSAnimationBlocking];
			[animation setDuration: 0.2];
			[animation startAnimation];
			[animation release];
			
			[oldPanel removeFromSuperview];
			[oldPanel setHidden: NO];
		}
		
		//If we're setting up the panel for the first time, don't bother with this step
		else
		{
			[[[self window] contentView] addSubview: panel];
			[[self window] setFrame: newFrame display: YES];
		}
	}
}


#pragma mark -
#pragma mark UI actions

- (IBAction) showOpenPanel: (id)sender
{
	NSOpenPanel *openPanel	= [NSOpenPanel openPanel];
	
	[openPanel setCanChooseFiles: YES];
	[openPanel setCanChooseDirectories: YES];
	[openPanel setTreatsFilePackagesAsDirectories: NO];
	[openPanel setMessage:	NSLocalizedString(@"Choose a DOS game folder, CD-ROM or disc image to import:", @"Help text shown at the top of choose-a-folder-to-import panel.")];
	[openPanel setPrompt:	NSLocalizedString(@"Import", @"Label shown on accept button in choose-a-folder-to-import panel.")];

	[openPanel setDelegate: self];
	
	[openPanel beginSheetForDirectory: nil
								 file: nil
								types: [[BXImport acceptedSourceTypes] allObjects]
					   modalForWindow: [self window]
						modalDelegate: self
					   didEndSelector: @selector(_importChosenItem:returnCode:contextInfo:)
						  contextInfo: nil];	
}

- (void) _importChosenItem: (NSOpenPanel *)openPanel
				returnCode: (int)returnCode
			   contextInfo: (void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		NSString *path = [[openPanel URL] path];
		NSLog(@"%@", path);	
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
			if (![[self document] canImportFromSourcePath: path]) return NSDragOperationNone;
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
			if ([[self document] canImportFromSourcePath: path])
			{
				//Do import here
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

- (void)draggingEnded: (id <NSDraggingInfo>)sender
{
	[[self dropzone] setHighlighted: NO];
}

- (void) concludeDragOperation: (id <NSDraggingInfo>)sender
{
	[[self dropzone] setHighlighted: NO];
}
@end
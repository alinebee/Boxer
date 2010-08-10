/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImportWindowController.h"
#import "BXImport.h"


//The height of the bottom window border.
//TODO: determine this from NIB content.
#define BXImportWindowBorderThickness 40

@implementation BXImportWindowController
@synthesize dropzonePanel, installerPanel;

- (BXImport *) document { return (BXImport *)[super document]; }

#pragma mark -
#pragma mark Initialization and deallocation

- (void) dealloc
{
	[self setDropzonePanel: nil], [dropzonePanel release];
	[self setInstallerPanel: nil], [installerPanel release];
	
	[super dealloc];
}


- (void) windowDidLoad
{
	[[self window] setContentBorderThickness: BXImportWindowBorderThickness forEdge: NSMinYEdge];
	
	//Default to the dropzone panel when we initially load
	//TODO: this should really be under the control of BXImport instead, it controls the workflow
	[self showDropzonePanel];
}

- (NSString *) windowTitleForDocumentDisplayName: (NSString *)displayName
{
	NSString *format = NSLocalizedString(@"Importing %@",
										 @"Title for game import window. %@ is the name of the gamebox/source path being imported.");
	return [NSString stringWithFormat: format, displayName, nil];
}

- (void) synchronizeWindowTitleWithDocumentName
{
	if ([[self document] fileURL])
	{
		//If the import process has a file to represent, carry on with the default NSWindowController behaviour
		return [super synchronizeWindowTitleWithDocumentName];
	}
	else
	{
		//Otherwise, display a generic title
		[[self window] setRepresentedFilename: @""];
		[[self window] setTitle: NSLocalizedString(@"Import a Game",
												   @"The standard import window title before an import source has been chosen.")];
	}
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
		//Animate the transition from one panel to the next, if we have a previous panel and the window is actually on screen
		if (oldPanel && [[self window] isVisible])
		{
			[panel setFrame: [oldPanel frame]];
			
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
			[animation setDuration: 0.25];
			[animation startAnimation];
			[animation release];
			
			//Reset the properties of the original panel once the animation is complete
			[oldPanel removeFromSuperview];
			[oldPanel setFrameSize: oldSize];
			[oldPanel setHidden: NO];
		}
		
		//If we're setting up the panel for the first time, don't bother with this step
		else
		{
			[oldPanel removeFromSuperview];
			[panel setFrameOrigin: NSZeroPoint];
			[[[self window] contentView] addSubview: panel];
			[[self window] setFrame: newFrame display: YES];
		}
	}
}

//This curious process is as follows:
//1. we invoke window to ensure that all our resources are fully loaded from the nib file
//2. we swap the panels around.
//3. we reveal the window after all swapping has been performed, so we don't have to redraw in front of the user.
- (void) showDropzonePanel	{ [self window]; [self setCurrentPanel: [self dropzonePanel]]; [self showWindow: self]; }
- (void) showInstallerPanel	{ [self window]; [self setCurrentPanel: [self installerPanel]]; [self showWindow: self]; }

@end
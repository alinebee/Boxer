/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImportWindowController.h"
#import "BXImport.h"
#import "BXGeometry.h"
#import "NSWindow+BXWindowSizing.h"


//The height of the bottom window border.
//TODO: determine this from NIB content.
#define BXImportWindowBorderThickness 32.0f

@implementation BXImportWindowController
@synthesize dropzonePanel, installerPanel, finalizingPanel, finishedPanel;

- (BXImport *) document { return (BXImport *)[super document]; }

#pragma mark -
#pragma mark Initialization and deallocation

- (void) dealloc
{
	[self setDropzonePanel: nil],	[dropzonePanel release];
	[self setInstallerPanel: nil],	[installerPanel release];
	[self setFinalizingPanel: nil],	[finalizingPanel release];
	[self setFinishedPanel: nil],	[finishedPanel release];
	
	[super dealloc];
}

- (void) setDocument: (NSDocument *)document
{
	[[self document] removeObserver: self forKeyPath: @"importStage"];
	
	[super setDocument: document];
	
	[[self document] addObserver: self
					  forKeyPath: @"importStage"
						 options: 0
						 context: nil];
}

- (void) windowDidLoad
{
	[[self window] setContentBorderThickness: BXImportWindowBorderThickness + 1 forEdge: NSMinYEdge];
	
	//Default to the dropzone panel when we initially load (this will be overridden later anyway)
	[self setCurrentPanel: [self dropzonePanel]];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{
	//Show the appropriate panel based on the current stage of the import process
	if ([self isWindowLoaded] && 
		[object isEqualTo: [self document]] && 
		[keyPath isEqualToString: @"importStage"])
	{
		switch ([[self document] importStage])
		{
			case BXImportWaitingForSourcePath:
				[self setCurrentPanel: [self dropzonePanel]];
				break;
				
			case BXImportWaitingForInstaller:
			case BXImportReadyToLaunchInstaller:
			case BXImportRunningInstaller:
				[self setCurrentPanel: [self installerPanel]];
				break;
				
			case BXImportReadyToFinalize:
			case BXImportFinalizing:
				[self setCurrentPanel: [self finalizingPanel]];
				break;
				
			case BXImportFinished:
				[self setCurrentPanel: [self finishedPanel]];
				break;
		}
	}
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
	
	if (panel && oldPanel != panel)
	{
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
		
		
		//Animate the transition from one panel to the next,
		//if we have a previous panel and the window is actually on screen
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
			
			//Cures infinite-redraw bug caused by animated fade
			[panel display];
		}
		
		//If we're setting up the panel for the first time, don't bother with this step
		else
		{
			[oldPanel removeFromSuperview];
			[[self window] setFrame: newFrame display: YES];
			[[[self window] contentView] addSubview: panel];
		}
		
		//Select the designated first responder for this panel
		//(Currently this is piggybacking off NSView's nextKeyView, which is kinda not good)
		[[self window] makeFirstResponder: [panel nextKeyView]];
	}
}


- (void) handOffToController: (NSWindowController *)controller
{
	NSWindow *fromWindow	= [self window];
	NSWindow *toWindow		= [controller window];
	
	NSRect fromFrame	= [fromWindow frame];
	//Resize to the size of the final window, centered on the titlebar of the initial window
	NSRect toFrame		= resizeRectFromPoint(fromFrame, [toWindow frame].size, NSMakePoint(0.5f, 1.0f));
	
	//Ensure the final frame fits within the current display
	toFrame = [toWindow fullyConstrainFrameRect: toFrame toScreen: [fromWindow screen]];
	
	
	//First, hide the destination window and reposition it to exactly the same area and size as our own window
	[toWindow orderOut: self];
	[toWindow setFrame: fromFrame display: NO];
	
	//Next, swap the two windows around
	[toWindow makeKeyAndOrderFront: self];
	[fromWindow orderOut: self];
	
	//Resize the destination window back to what it should be
	[toWindow setFrame: toFrame display: YES animate: YES];
}

//Return control to us from the specified window controller
- (void) pickUpFromController: (NSWindowController *)controller
{
	NSWindow *fromWindow	= [controller window];
	NSWindow *toWindow		= [self window];
	
	NSRect fromFrame	= [fromWindow frame];
	//Resize to the size of the final window, centered on the titlebar of the initial window
	NSRect toFrame		= resizeRectFromPoint(fromFrame, [toWindow frame].size, NSMakePoint(0.5f, 1.0f));
	
	//Ensure the final frame fits within the current display
	toFrame = [toWindow fullyConstrainFrameRect: toFrame toScreen: [fromWindow screen]];

	
	//Set ourselves to the final size behind the scenes
	[toWindow orderOut: self];
	[toWindow setFrame: toFrame display: NO];
	
	//Make the initial window scale to our final window location
	[fromWindow setFrame: toFrame display: YES animate: YES];

	//Finally, close the top window and make ourselves key
	[toWindow makeKeyAndOrderFront: self];
	[fromWindow orderOut: self];
	
	//Reset the initial window back to what it was before we messed with it
	[fromWindow setFrame: fromFrame display: NO];
}

@end
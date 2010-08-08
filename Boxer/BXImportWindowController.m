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
		//Animate the transition from one panel to the next
		if (oldPanel)
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
			[panel setFrameOrigin: NSZeroPoint];
			[[[self window] contentView] addSubview: panel];
			[[self window] setFrame: newFrame display: YES];
		}
	}
}

- (void) showDropzonePanel	{ [self showWindow: self]; [self setCurrentPanel: [self dropzonePanel]]; }
- (void) showInstallerPanel	{ [self showWindow: self]; [self setCurrentPanel: [self installerPanel]]; }

@end
/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXStatusBarController.h"
#import "BXAppController.h"
#import "BXSessionWindowController.h"
#import "BXSession+BXEmulatorController.h"
#import "BXInspectorController.h"

@implementation BXStatusBarController

- (void) awakeFromNib
{
	//Give statusbar text an indented appearance
	NSTextField *notificationText = [[self view] viewWithTag: BXStatusBarNotificationText];
	[[notificationText cell] setBackgroundStyle: NSBackgroundStyleRaised];
	
	BXSessionWindowController *windowController = (BXSessionWindowController *)[[[self view] window] windowController];
	BXAppController *appController = (BXAppController *)[NSApp delegate];
	
	//Observe changes that will affect our segmented button states
	[appController addObserver: self
					forKeyPath: @"inspectorPanelShown"
					   options: NSKeyValueObservingOptionInitial
					   context: nil];
	
	[windowController addObserver: self
					   forKeyPath: @"programPanelShown"
						  options: NSKeyValueObservingOptionInitial
						  context: nil];

	[windowController addObserver: self
					   forKeyPath: @"document.mouseLocked"
						  options: NSKeyValueObservingOptionInitial
						  context: nil];
	
}

- (IBAction) performSegmentedButtonAction: (id)sender
{
	BXSessionWindowController *controller = (BXSessionWindowController *)[[[self view] window] windowController];
	BXSession *session = [controller document];
	BOOL mouseLocked = [session mouseLocked];
	
	//Because we have no easy way of telling which segment was just toggled, just synchronise them all
	
	if ([sender isSelectedForSegment: BXStatusBarInspectorSegment] != [[NSApp delegate] inspectorPanelShown])
	{
		[[NSApp delegate] toggleInspectorPanel: sender];
	}
	
	if ([sender isSelectedForSegment: BXStatusBarProgramPanelSegment] != [controller programPanelShown])
	{
		[controller toggleProgramPanelShown: sender];
	}
	
	if ([sender isSelectedForSegment: BXStatusBarMouseLockSegment] != mouseLocked)
	{
		[session setMouseLocked: !mouseLocked];		
	}
	
	[self syncSegmentedButtonStates];
}

- (void) syncSegmentedButtonStates
{
	BXSessionWindowController *controller = (BXSessionWindowController *)[[statusBarControls window] windowController];

	[statusBarControls setSelected: [[NSApp delegate] inspectorPanelShown]	forSegment: BXStatusBarInspectorSegment];
	[statusBarControls setSelected: [controller programPanelShown]			forSegment: BXStatusBarProgramPanelSegment];
	[statusBarControls setSelected: [[controller document] mouseLocked]		forSegment: BXStatusBarMouseLockSegment];

	NSString *imageName;
	if ([statusBarControls isSelectedForSegment: BXStatusBarProgramPanelSegment])
		imageName = @"PanelCollapseTemplate.png";
	else	imageName = @"PanelExpandTemplate.png";
	[statusBarControls setImage: [NSImage imageNamed: imageName] forSegment: BXStatusBarProgramPanelSegment];
}


//Whenever the represented icon changes, force a redraw of our icon view
- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{	
	[self syncSegmentedButtonStates];
}

@end

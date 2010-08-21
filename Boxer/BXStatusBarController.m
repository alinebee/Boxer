/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXStatusBarController.h"
#import "BXAppController.h"
#import "BXDOSWindowController+BXRenderController.h"
#import "BXInspectorController.h"
#import "BXInputController.h"
#import "BXSession.h"
#import "BXEmulator.h"

@implementation BXStatusBarController

- (BXDOSWindowController *)controller
{
	return (BXDOSWindowController *)[[[self view] window] windowController];
}

- (void) awakeFromNib
{
	//Give statusbar text an indented appearance
	[[notificationMessage cell] setBackgroundStyle: NSBackgroundStyleRaised];

	[self _prepareBindings];
	[self _syncSegmentedButtonStates];
}

- (IBAction) performSegmentedButtonAction: (id)sender
{
	BOOL mouseLocked = [[[self controller] inputController] mouseLocked];
	
	//Because we have no easy way of telling which segment was just toggled, just synchronise them all
	
	if ([sender isSelectedForSegment: BXStatusBarInspectorSegment] != [[NSApp delegate] inspectorPanelShown])
	{
		[[NSApp delegate] toggleInspectorPanel: sender];
	}
	
	if ([sender isSelectedForSegment: BXStatusBarProgramPanelSegment] != [[self controller] programPanelShown])
	{
		[[self controller] toggleProgramPanelShown: sender];
	}
	
	if ([sender isSelectedForSegment: BXStatusBarMouseLockSegment] != mouseLocked)
	{
		[[[self controller] inputController] toggleMouseLocked: sender];		
	}
	
	[self _syncSegmentedButtonStates];
}


//Resync the segmented button state whenever any of the keys we're observing change
- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{
	[self _syncSegmentedButtonStates];
	
	NSArray *notificationTextModifiers = [NSArray arrayWithObjects:
										  @"inputController.mouseActive",
										  @"inputController.mouseLocked",
										  @"inputController.mouseInView",
										  nil];
	
	if ([notificationTextModifiers containsObject: keyPath])
	{
		[self willChangeValueForKey: @"notificationText"];
		[self didChangeValueForKey: @"notificationText"];
	}
}

- (NSString *) notificationText
{
	BXInputController *viewController = [[self controller] inputController];
	if ([viewController mouseActive])
	{
		if ([viewController mouseLocked])
		{
			return NSLocalizedString(@"Cmd-click to release the mouse.",
									 @"Statusbar message when mouse is locked.");
		}
		else if ([viewController mouseInView])
		{	
			if ([viewController trackMouseWhileUnlocked])
			{
				return NSLocalizedString(@"Cmd-click inside the window to lock the mouse.",
										 @"Statusbar message when mouse is unlocked and over DOS viewport.");
			}
			else
			{
				return NSLocalizedString(@"Click inside the window to lock the mouse.",
										 @"Statusbar message when mouse is unlocked and over DOS viewport and unlocked mouse-tracking is disabled.");
			}
		}
	}
	else
	{
		return @"";
	}
}

- (void) _statusBarDidResize
{
	//Hide the notification text if it overlaps the button
	[notificationMessage setHidden: NSIntersectsRect([notificationMessage frame], [statusBarControls frame])];
}

- (void) _windowWillClose
{
	[self _removeBindings];
}

- (void) _syncSegmentedButtonStates
{	
	[statusBarControls setSelected: [[NSApp delegate] inspectorPanelShown]				forSegment: BXStatusBarInspectorSegment];
	[statusBarControls setSelected: [[self controller] programPanelShown]				forSegment: BXStatusBarProgramPanelSegment];
	[statusBarControls setSelected: [[[self controller] inputController] mouseLocked]	forSegment: BXStatusBarMouseLockSegment];
	
	[statusBarControls setEnabled:	[[[self controller] document] isGamePackage]		forSegment: BXStatusBarProgramPanelSegment];
	[statusBarControls setEnabled:	[[[self controller] inputController] mouseActive]	forSegment: BXStatusBarMouseLockSegment];
	
	NSString *panelButtonImage;
	if ([statusBarControls isSelectedForSegment: BXStatusBarProgramPanelSegment])
			panelButtonImage = @"PanelCollapseTemplate";
	else	panelButtonImage = @"PanelExpandTemplate";
	[statusBarControls setImage: [NSImage imageNamed: panelButtonImage] forSegment: BXStatusBarProgramPanelSegment];
	
	NSString *lockButtonImage;
	if ([statusBarControls isSelectedForSegment: BXStatusBarMouseLockSegment])
			lockButtonImage = @"NSLockLockedTemplate";
	else	lockButtonImage = @"NSLockUnlockedTemplate";
	[statusBarControls setImage: [NSImage imageNamed: lockButtonImage] forSegment: BXStatusBarMouseLockSegment];
}

- (void) _prepareBindings
{
	//Observe changes that will affect our segmented button states
	[[self controller] addObserver: self
				 forKeyPath: @"programPanelShown"
					options: 0
					context: nil];
	
	[[self controller] addObserver: self
				 forKeyPath: @"document.isGamePackage"
					options: 0
					context: nil];
	
	[[self controller] addObserver: self
				 forKeyPath: @"inputController.mouseLocked"
					options: 0
					context: nil];
	
	[[self controller] addObserver: self
				 forKeyPath: @"inputController.mouseActive"
					options: 0
					context: nil];
	
	[[self controller] addObserver: self
				 forKeyPath: @"inputController.mouseInView"
					options: 0
					context: nil];
	
	[[self controller] addObserver: self
						forKeyPath: @"inputController.trackMouseWhileUnlocked"
						   options: 0
						   context: nil];
	
	[[NSApp delegate] addObserver: self
					   forKeyPath: @"inspectorPanelShown"
						  options: 0
						  context: nil];
	
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	
	//Listen for changes in the status bar's size, so that we can selectively hide elements to avoid overlaps.
	[center addObserver: self
			   selector: @selector(_statusBarDidResize)
				   name: @"NSViewFrameDidChangeNotification"
				 object: [self view]];
	
	//Listen for the parent window closing, so that we can tear down our bindings before our window controller
	//ceases to exist. This avoids spurious console errors.
	[center addObserver: self
			   selector: @selector(_windowWillClose)
				   name: @"NSWindowWillCloseNotification"
				 object: [[self view] window]];
	
}

- (void) _removeBindings
{
	[[self controller] removeObserver: self forKeyPath: @"inputController.mouseActive"];
	[[self controller] removeObserver: self forKeyPath: @"inputController.mouseLocked"];
	[[self controller] removeObserver: self forKeyPath: @"inputController.mouseInView"];
	[[self controller] removeObserver: self forKeyPath: @"inputController.trackMouseWhileUnlocked"];
	[[self controller] removeObserver: self forKeyPath: @"document.isGamePackage"];
	[[self controller] removeObserver: self forKeyPath: @"programPanelShown"];
	
	[[NSApp delegate] removeObserver: self forKeyPath: @"inspectorPanelShown"];
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

@end

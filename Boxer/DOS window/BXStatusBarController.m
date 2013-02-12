/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXStatusBarController.h"
#import "BXAppController.h"
#import "BXDOSWindowController.h"
#import "BXInspectorController.h"
#import "BXInputController.h"
#import "BXSession.h"
#import "BXEmulator.h"

@interface BXStatusBarController ()

//Selectively hides statusbar items when the window is too small to display them without overlaps 
- (void) _statusBarDidResize;

//Tears down our bindings when the window is about to close
- (void) _windowWillClose;

//Synchronises the selection state of segments in the segmented button
- (void) _syncSegmentedButtonStates;

//Set up/tear down the notification and KVC bindings we use to control the segmented button state
- (void) _prepareBindings;
- (void) _removeBindings;

@end

@implementation BXStatusBarController
@synthesize notificationMessage = _notificationMessage;
@synthesize statusBarControls = _statusBarControls;
@synthesize volumeControls = _volumeControls;

- (BXDOSWindowController *)controller
{
	return (BXDOSWindowController *)self.view.window.windowController;
}

- (BXInspectorController *)inspector
{
    return [NSClassFromString(@"BXInspectorController") controller];
}

- (void) awakeFromNib
{
	//Give statusbar text an indented appearance
	[self.notificationMessage.cell setBackgroundStyle: NSBackgroundStyleRaised];

	[self _prepareBindings];
	[self _syncSegmentedButtonStates];
}

- (void) dealloc
{
    self.notificationMessage = nil;
    self.statusBarControls = nil;
    self.volumeControls = nil;
    
    [super dealloc];
}

- (IBAction) performSegmentedButtonAction: (id)sender
{	
	//Because we have no easy way of telling which segment was just toggled, just synchronise them all
	
	if ([sender isSelectedForSegment: BXStatusBarInspectorSegment] != self.inspector.panelShown)
	{
		[[NSApp delegate] toggleInspectorPanel: sender];
	}
	
	if ([sender isSelectedForSegment: BXStatusBarProgramPanelSegment] != self.controller.programPanelShown)
	{
		[self.controller toggleProgramPanelShown: sender];
	}
	
	if ([sender isSelectedForSegment: BXStatusBarMouseLockSegment] != self.controller.inputController.mouseLocked)
	{
		[self.controller.inputController toggleMouseLocked: sender];		
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
	BXInputController *viewController = self.controller.inputController;
	if (viewController.mouseActive)
	{
		if (viewController.mouseLocked)
		{
			return NSLocalizedString(@"Cmd+click to release the mouse.",
									 @"Statusbar message when mouse is locked.");
		}
		else if (viewController.mouseInView)
		{	
			if (viewController.trackMouseWhileUnlocked)
			{
				return NSLocalizedString(@"Cmd+click inside the window to lock the mouse.",
										 @"Statusbar message when mouse is unlocked and over DOS viewport.");
			}
			else
			{
				return NSLocalizedString(@"Click inside the window to lock the mouse.",
										 @"Statusbar message when mouse is unlocked and over DOS viewport and unlocked mouse-tracking is disabled.");
			}
		}
	}
    
    return @"";
}

- (void) _statusBarDidResize
{
	//Hide the notification text if it overlaps the button or volume controls
    BOOL hideMessage = NSIntersectsRect(self.notificationMessage.frame, self.statusBarControls.frame) || NSIntersectsRect(self.notificationMessage.frame, self.volumeControls.frame);
	[self.notificationMessage setHidden: hideMessage];
}

- (void) _windowWillClose
{
	[self _removeBindings];
}

- (void) _syncSegmentedButtonStates
{	
	[self.statusBarControls setSelected: self.inspector.panelShown                      forSegment: BXStatusBarInspectorSegment];
	[self.statusBarControls setSelected: self.controller.programPanelShown              forSegment: BXStatusBarProgramPanelSegment];
	[self.statusBarControls setSelected: self.controller.inputController.mouseLocked    forSegment: BXStatusBarMouseLockSegment];
	
	[self.statusBarControls setEnabled:	self.controller.document.hasGamebox             forSegment: BXStatusBarProgramPanelSegment];
	[self.statusBarControls setEnabled:	self.controller.inputController.mouseActive     forSegment: BXStatusBarMouseLockSegment];
	
	NSString *panelImageName;
	if ([self.statusBarControls isSelectedForSegment: BXStatusBarProgramPanelSegment])
        panelImageName = @"PanelCollapseTemplate";
	else
        panelImageName = @"PanelExpandTemplate";
	[self.statusBarControls setImage: [NSImage imageNamed: panelImageName] forSegment: BXStatusBarProgramPanelSegment];
	
	NSString *lockImageName;
	if ([self.statusBarControls isSelectedForSegment: BXStatusBarMouseLockSegment])
        lockImageName = @"NSLockLockedTemplate";
	else
        lockImageName = @"NSLockUnlockedTemplate";
	[self.statusBarControls setImage: [NSImage imageNamed: lockImageName] forSegment: BXStatusBarMouseLockSegment];
}

- (void) _prepareBindings
{
	//Observe changes that will affect our segmented button states
	[self.controller addObserver: self
                      forKeyPath: @"programPanelShown"
                         options: 0
                         context: nil];
	
	[self.controller addObserver: self
                      forKeyPath: @"document.hasGamebox"
                         options: 0
                         context: nil];
	
	[self.controller addObserver: self
                      forKeyPath: @"inputController.mouseLocked"
                         options: 0
                         context: nil];
	
	[self.controller addObserver: self
                      forKeyPath: @"inputController.mouseActive"
                         options: 0
                         context: nil];
	
	[self.controller addObserver: self
                      forKeyPath: @"inputController.mouseInView"
                         options: 0
                         context: nil];
	
	[self.controller addObserver: self
                      forKeyPath: @"inputController.trackMouseWhileUnlocked"
                         options: 0
                         context: nil];
	
	[self.inspector addObserver: self
                     forKeyPath: @"panelShown"
                        options: 0
                        context: nil];
	
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	
	//Listen for changes in the status bar's size, so that we can selectively hide elements to avoid overlaps.
	[center addObserver: self
			   selector: @selector(_statusBarDidResize)
				   name: @"NSViewFrameDidChangeNotification"
				 object: self.view];
	
	//Listen for the parent window closing, so that we can tear down our bindings before our window controller
	//ceases to exist. This avoids spurious console errors.
	[center addObserver: self
			   selector: @selector(_windowWillClose)
				   name: @"NSWindowWillCloseNotification"
				 object: self.view.window];
}

- (void) _removeBindings
{
	[self.controller removeObserver: self forKeyPath: @"inputController.mouseActive"];
	[self.controller removeObserver: self forKeyPath: @"inputController.mouseLocked"];
	[self.controller removeObserver: self forKeyPath: @"inputController.mouseInView"];
	[self.controller removeObserver: self forKeyPath: @"inputController.trackMouseWhileUnlocked"];
	[self.controller removeObserver: self forKeyPath: @"document.hasGamebox"];
	[self.controller removeObserver: self forKeyPath: @"programPanelShown"];
	
	[self.inspector removeObserver: self forKeyPath: @"panelShown"];
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

@end

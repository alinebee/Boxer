/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXInspectorController.h"
#import "BXSession+BXUIControls.h"
#import "BXEmulator.h"
#import "BXDrive.h"
#import "BXBaseAppController.h"
#import "BXValueTransformers.h"
#import "NSWindow+ADBWindowEffects.h"

#import "BXDOSWindowController.h"
#import "BXInputController.h"


/* Internal constants */

#define BXInspectorPanelBlurRadius 2.0f
#define BXMouseSensitivityRange 2.0f

@implementation BXInspectorController

+ (void) initialize
{
    if (self == [BXInspectorController class])
    {
        //A range from 0.5 to 2.0, with 1.0 as the midpoint of the range.
        double sensitivityThresholds[3] = {
            1.0 / BXMouseSensitivityRange,
            1.0,
            1.0 * BXMouseSensitivityRange
        };
        
        BXBandedValueTransformer *mouseSensitivity = [[BXBandedValueTransformer alloc] initWithThresholds: sensitivityThresholds
                                                                                                    count: 3];
        
        [NSValueTransformer setValueTransformer: mouseSensitivity forName: @"BXMouseSensitivitySlider"];
        
        [mouseSensitivity release];
    }
}

+ (BXInspectorController *)controller
{
    static BXInspectorController *controller = nil;
    static dispatch_once_t pred;
    
    dispatch_once(&pred, ^{
        controller = [[self alloc] initWithWindowNibName: @"Inspector"];
    });
    
    return controller;
}

- (void) awakeFromNib
{
	((NSPanel *)self.window).becomesKeyOnlyIfNeeded = YES;
    self.window.movableByWindowBackground = YES;
    self.window.frameAutosaveName = @"InspectorPanel";
	
	//Set the initial panel based on the user's last chosen panel (defaulting to the CPU panel)
	NSInteger selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey: @"initialInspectorPanelIndex"];
	
	if (selectedIndex < 0 || selectedIndex > self.tabView.numberOfTabViewItems)
		selectedIndex = BXCPUInspectorPanelIndex;
	
	[self.tabView selectTabViewItemAtIndex: selectedIndex];
	
	//Listen for changes to the current session
	[[NSApp delegate] addObserver: self
					   forKeyPath: @"currentSession"
						  options: NSKeyValueObservingOptionInitial
						  context: nil];
}

//Whenever the session changes, update the availability of the gamebox panel
- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{	
	BXSession *session = [(BXBaseAppController*)[NSApp delegate] currentSession];
	if ([keyPath isEqualToString: @"currentSession"])
	{
		if (session)
		{
			//If the gamebox tab was already selected, then switch to the next tab
			if (!session.hasGamebox && [self.tabView indexOfTabViewItem: self.tabView.selectedTabViewItem] == BXGameInspectorPanelIndex)
			{
				[self.tabView selectTabViewItemAtIndex: BXCPUInspectorPanelIndex];
			}
            
            [self.toolbarForTabs validateVisibleItems];
		}
	}
}

- (void) showWindow: (id)sender
{
	//If there’s no session active, don’t allow the window to be shown
	if (![(BXBaseAppController*)[NSApp delegate] currentSession].isEmulating) return;
	
	[self loadWindow];
	
	[self.window fadeInWithDuration: 0.2];
	//[[self window] applyGaussianBlurWithRadius: BXInspectorPanelBlurRadius];
	
	_isTemporarilyHidden = NO;
}

+ (NSSet *) keyPathsForValuesAffectingPanelShown
{
	return [NSSet setWithObject: @"window.visible"];
}

- (void) setVisible: (BOOL)show
{
	if (show)
	{
		[self showWindow: self];
		
		//Unlock the mouse from the DOS window whenever the Inspector panel is shown
		//(This will happen automatically for normal windows, but since we're an NSPanel
		//that doesnt become key automatically, the DOS window doesn't know to release
		//mouse focus)
		[NSApp sendAction: @selector(toggleMouseLocked:)
					   to: nil
					 from: @(NO)];
		
	}
	else if (self.isWindowLoaded)
	{
		[self.window fadeOutWithDuration: 0.2];
		_isTemporarilyHidden = NO;
	}
}

- (BOOL) isVisible
{
	return self.isWindowLoaded && self.window.isVisible;
}

- (BOOL) windowShouldClose: (id)sender
{
	[self.window fadeOutWithDuration: 0.2];
	_isTemporarilyHidden = NO;
	return NO;
}

- (void) windowDidUpdate: (NSNotification *)notification
{
	[self willChangeValueForKey: @"visible"];
	[self didChangeValueForKey: @"visible"];
}


- (void) hideIfVisible
{
	if (self.isVisible)
	{
        self.visible = NO;
		_isTemporarilyHidden = YES;
	}
}

- (void) revealIfHidden
{
	if (_isTemporarilyHidden)
	{
        self.visible = YES;
		_isTemporarilyHidden = NO;
	}
}

//Pass requests for a window manager on to the current session
- (NSUndoManager *) windowWillReturnUndoManager: (NSWindow *)window
{
    return [(BXBaseAppController*)[NSApp delegate] currentSession].undoManager;
}

#pragma mark -
#pragma mark Tab selection

- (IBAction) showGamePanel: (id)sender		{ self.selectedTabViewItemIndex = BXGameInspectorPanelIndex; [self showWindow: sender]; }
- (IBAction) showCPUPanel: (id)sender		{ self.selectedTabViewItemIndex = BXCPUInspectorPanelIndex; [self showWindow: sender]; }
- (IBAction) showMousePanel: (id)sender		{ self.selectedTabViewItemIndex = BXMouseInspectorPanelIndex; [self showWindow: sender]; }
- (IBAction) showDrivesPanel: (id)sender	{ self.selectedTabViewItemIndex = BXDriveInspectorPanelIndex; [self showWindow: sender]; }
- (IBAction) showJoystickPanel: (id)sender	{ self.selectedTabViewItemIndex = BXJoystickInspectorPanelIndex; [self showWindow: sender]; }

- (void) tabView: (NSTabView *)tabView didSelectTabViewItem: (NSTabViewItem *)tabViewItem
{
	[super tabView: tabView didSelectTabViewItem: tabViewItem];
	
	//Record the user's choice of tab, and synchronize the selected segment
	NSInteger selectedIndex = [tabView indexOfTabViewItem: tabViewItem];
	
	if (selectedIndex != NSNotFound)
	{
		[[NSUserDefaults standardUserDefaults] setInteger: selectedIndex
												   forKey: @"initialInspectorPanelIndex"];
	}
}

- (BOOL) tabView: (NSTabView *)tabView shouldSelectTabViewItem: (NSTabViewItem *)tabViewItem
{
	return ([tabView indexOfTabViewItem: tabViewItem] != BXGameInspectorPanelIndex ||
			[(BXBaseAppController*)[NSApp delegate] currentSession].hasGamebox);
}

- (BOOL) shouldSyncWindowTitleToTabLabel: (NSString *)label
{
    return YES;
}

- (BOOL) validateToolbarItem: (NSToolbarItem *)theItem
{
    if (theItem.tag == BXGameInspectorPanelIndex)
    {
        return ([(BXBaseAppController*)[NSApp delegate] currentSession].hasGamebox);
    }
    return YES;
}


#pragma mark -
#pragma mark Help

- (IBAction) showGamePanelHelp: (id)sender				{ [(BXBaseAppController*)[NSApp delegate] showHelpAnchor: @"game-inspector"]; }
- (IBAction) showCPUPanelHelp: (id)sender				{ [(BXBaseAppController*)[NSApp delegate] showHelpAnchor: @"adjusting-game-speed"]; }
- (IBAction) showMousePanelHelp: (id)sender				{ [(BXBaseAppController*)[NSApp delegate] showHelpAnchor: @"mouse-inspector"]; }
- (IBAction) showDrivesPanelHelp: (id)sender			{ [(BXBaseAppController*)[NSApp delegate] showHelpAnchor: @"adding-and-removing-drives"]; }

- (IBAction) showJoystickPanelHelp: (id)sender			{ [(BXBaseAppController*)[NSApp delegate] showHelpAnchor: @"joystick-emulation-options"]; }
- (IBAction) showInactiveJoystickPanelHelp: (id)sender	{ [(BXBaseAppController*)[NSApp delegate] showHelpAnchor: @"joysticks"]; }

@end

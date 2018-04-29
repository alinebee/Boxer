/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>

@class BXSession;

/// \c BXProgramPanelController manages the program picker panel inside the session window. It is
/// responsible for populating the program selection and toggling which picker interface is shown
/// (picker, default program toggle, no programs notice) based on the state of the session.
///
/// TODO: move most of the which-panel-to-show logic upstream into BXSession, which knows a lot
/// more about what to display. The current implementation is a rat's-nest of bindings and predictions.
__deprecated
@interface BXProgramPanelController : NSViewController

#pragma mark -
#pragma mark Properties

@property (strong, nonatomic) IBOutlet NSView *programChooserPanel;
@property (strong, nonatomic) IBOutlet NSView *defaultProgramPanel;
@property (strong, nonatomic) IBOutlet NSView *initialDefaultProgramPanel;
@property (strong, nonatomic) IBOutlet NSView *noProgramsPanel;
@property (strong, nonatomic) IBOutlet NSView *scanningForProgramsPanel;

@property (strong, nonatomic) IBOutlet NSProgressIndicator *scanSpinner;

@property (strong, nonatomic) IBOutlet NSCollectionView *programList;
@property (strong, nonatomic) IBOutlet NSScrollView *programScroller;

/// The currently displayed view in the program panel.
@property (weak, nonatomic) NSView *activePanel;

/// Whether the currently executing program is the default program for its gamebox.
@property (nonatomic) BOOL activeProgramIsDefault;

/// Whether the current session currently has any default program.
@property (readonly, nonatomic) BOOL hasDefaultTarget;

/// The localised display string used for the "Open this program every time" toggles.
@property (copy, readonly, nonatomic) NSString *labelForDefaultProgramToggle;
@property (copy, readonly, nonatomic) NSString *labelForInitialDefaultProgramToggle;

/// An array of {@path, @isDefault} pairs representing executables to display in the program panel.
@property (readonly, strong, nonatomic) NSArray *panelExecutables;

/// An array of descriptors for consumers to sort panelExecutables with
@property (readonly, strong, nonatomic) NSArray *executableSortDescriptors;

/// A record of the last program that was running. This is kept up-to-date whenever
/// the current program changes, but the last value remains after we have quit back to DOS.
/// (This is used to avoid showing null labels in the UI while we're quitting.)
@property (copy, nonatomic) NSString *lastActiveProgramPath;


#pragma mark -
#pragma mark Synchronising subview state

/// Synchronises the displayed view to the current state of the session.
- (void) syncActivePanel;

/// Synchronises the enabled state of the program chooser buttons.
- (void) syncProgramButtonStates;

/// Regenerates the list of displayed executables from the session's executables.
- (void) syncPanelExecutables;

/// Whether we can set the currently-active program to be the default gamebox target.
/// Will be \c NO if there's no active program, there's no gamebox, or the active program is outside the gamebox.
- (BOOL) canSetActiveProgramToDefault;


#pragma mark -
#pragma mark IB Actions

/// Used by \c initialDefaultProgramPanel for accepting the offer to make the current program the default.
- (IBAction) setCurrentProgramToDefault: (id)sender;


@end

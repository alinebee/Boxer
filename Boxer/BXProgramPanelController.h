/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXProgramPanelController manages the program picker panel inside the session window. It is
//responsible for populating the program selection and toggling which picker interface is shown
//(picker, default program toggle, no programs notice) based on the state of the session.

//TODO: move most of the which-panel-to-show logic upstream into BXSession, which knows a lot
//more about what to display. The current implementation is a rat's-nest of bindings and predictions.

#import <Cocoa/Cocoa.h>

@class BXSession;

@interface BXProgramPanelController : NSViewController
{
	IBOutlet NSView *programChooserPanel;
	IBOutlet NSView *defaultProgramPanel;
	IBOutlet NSView *initialDefaultProgramPanel;
	IBOutlet NSView *noProgramsPanel;
	IBOutlet NSCollectionView *programList;
	IBOutlet NSScrollView *programScroller;
	
	NSArray *panelExecutables;
}


#pragma mark -
#pragma mark Properties

@property (retain, nonatomic) NSView *programChooserPanel;
@property (retain, nonatomic) NSView *defaultProgramPanel;
@property (retain, nonatomic) NSView *initialDefaultProgramPanel;
@property (retain, nonatomic) NSView *noProgramsPanel;

@property (retain, nonatomic) NSCollectionView *programList;
@property (retain, nonatomic) NSScrollView *programScroller;

//The currently displayed view in the program panel.
@property (assign, nonatomic) NSView *activePanel;

//Whether the currently executing program is the default program for its gamebox.
@property (assign, nonatomic) BOOL activeProgramIsDefault;

//Whether the current session currently has any default program.
@property (readonly, nonatomic) BOOL hasDefaultTarget;

//The localised display string used for the "Open this program every time" toggles.
@property (readonly, nonatomic) NSString *labelForToggle;
@property (readonly, nonatomic) NSString *labelForInitialToggle;


//An array of {@path, @isDefault} pairs representing executables to display in the program panel.
@property (readonly, retain, nonatomic) NSArray *panelExecutables;

//An array of descriptors for consumers to sort panelExecutables with
@property (readonly, retain, nonatomic) NSArray *executableSortDescriptors;


#pragma mark -
#pragma mark Synchronising subview state

//Synchronises the displayed view to the current state of the session.
- (void) syncActivePanel;

//Synchronises the enabled state of the program chooser buttons.
- (void) syncProgramButtonStates;

//Regenerates the list of displayed executables from the session's executables.
- (void) syncPanelExecutables;

//Whether we can set the currently-active program to be the default gamebox target.
//Will be NO if there's no active program, there's no gamebox, or the active program is outside the gamebox.
- (BOOL) canSetActiveProgramToDefault;


#pragma mark -
#pragma mark IB Actions

//Used by initialDefaultProgramPanel for accepting the offer to make the current program the default.
- (IBAction) setCurrentProgramToDefault: (id)sender;


@end

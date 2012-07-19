/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXAppController is Boxer's NSApp delegate and document controller. It controls application launch
//behaviour, shared resources and user defaults, and handles non-window-specific UI functions.
//This controller is instantiated in MainMenu.xib.

#import "BXBaseAppController.h"

enum {
	BXStartUpWithNothing		= 0,
	BXStartUpWithWelcomePanel	= 1,
	BXStartUpWithGamesFolder	= 2
};


@interface BXAppController : BXBaseAppController
{
	NSString *_gamesFolderPath;
}

//Returns YES if there are other Boxer processes currently running, no otherwise.
+ (BOOL) otherBoxersActive;


#pragma mark -
#pragma mark Opening documents

//A special method for creating a new untitled import session.
//Mirrors the behaviour of openUntitledDocumentAndDisplay:error:
- (id) openImportSessionAndDisplay: (BOOL)displayDocument error: (NSError **)outError;

//Open an import session to import the specified URL.
- (id) openImportSessionWithContentsOfURL: (NSURL *)url
								  display: (BOOL)display
									error: (NSError **)outError;


#pragma mark -
#pragma mark UI actions

- (IBAction) orderFrontWelcomePanel: (id)sender;		//Display the welcome panel.
- (IBAction) orderFrontWelcomePanelWithTransition: (id)sender;
- (IBAction) orderFrontFirstRunPanel: (id)sender;		//Display the first-run panel.
- (IBAction) orderFrontFirstRunPanelWithTransition: (id)sender;

- (IBAction) hideWelcomePanel: (id)sender;				//Close the welcome panel.
- (IBAction) orderFrontImportGamePanel: (id)sender;		//Display the game import panel.

- (IBAction) orderFrontPreferencesPanel: (id)sender;	//Display Boxer's preferences panel.
- (IBAction) orderFrontInspectorPanel: (id)sender;		//Display Boxer's inspector HUD panel.
- (IBAction) toggleInspectorPanel: (id)sender;			//Display/hide Boxer's inspector HUD panel.

//Display the relevant panels of the Inspector.
- (IBAction) showGamePanel:		(id)sender;
- (IBAction) showCPUPanel:		(id)sender;
- (IBAction) showDrivesPanel:	(id)sender;
- (IBAction) showMousePanel:	(id)sender;

//Display the add-a-new-drive panel for the current session.
- (IBAction) showMountPanel: (id)sender;

//The URLs and email addresses for the following actions are configured in the Info.plist file.

- (IBAction) showWebsite:			(id)sender;	//Open the Boxer website in the default browser. 
- (IBAction) showDonationPage:		(id)sender;	//Open the Boxer donations page in the default browser.
- (IBAction) showPerianDownloadPage:(id)sender;	//Open the Perian website in the default browser.
- (IBAction) showJoypadDownloadPage:(id)sender;	//Open the Joypad website in the default browser.
- (IBAction) showBugReportPage:		(id)sender;	//Open Boxer's issue reporting page in the default browser. 
- (IBAction) sendEmail:				(id)sender;	//Open a new email to Boxer's contact email address.
- (IBAction) showUniversalAccessPrefsPane: (id)sender; //Open the Universal Access pane in OS X System Preferences.

//Reveal the path of the current session in a new Finder window.
- (IBAction) revealCurrentSessionPath: (id)sender;

@end
